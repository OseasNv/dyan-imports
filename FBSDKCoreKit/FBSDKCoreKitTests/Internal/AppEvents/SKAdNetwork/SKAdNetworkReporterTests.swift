// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import TestTools
import XCTest

class SKAdNetworkReporterTests: XCTestCase {

  let userDefaultsSpy = UserDefaultsSpy()
  let graphRequestFactory = TestGraphRequestFactory()
  let json = [
    "data": [
      [
        "timer_buckets": 1,
        "timer_interval": 1000,
        "cutoff_time": 1,
        "default_currency": "usd",
        "conversion_value_rules": []
      ]
    ]
  ]
  // swiftlint:disable:next force_unwrapping
  lazy var defaultConfiguration = SKAdNetworkConversionConfiguration(json: json)!
  lazy var skAdNetworkReporter = SKAdNetworkReporter(
    graphRequestFactory: graphRequestFactory,
    store: userDefaultsSpy,
    conversionValueUpdatable: TestConversionValueUpdating.self
  )

  override func setUp() {
    super.setUp()

    TestConversionValueUpdating.reset()
    skAdNetworkReporter._loadReportData()
    skAdNetworkReporter.isSKAdNetworkReportEnabled = true
  }

  func testEnable() {
    if #available(iOS 14.0, *) {
      skAdNetworkReporter.isSKAdNetworkReportEnabled = false
      skAdNetworkReporter.enable()

      XCTAssertTrue(
        skAdNetworkReporter.isSKAdNetworkReportEnabled,
        "SKAdNetwork report should be enabled"
      )
    }
  }

  func testLoadReportData() {
    let set = Set(["fb_mobile_puchase"])
    let recordedEvents = NSMutableSet(set: set)
    let recordedValues: NSMutableDictionary = ["fb_mobile_purchase": ["USD": 10]]

    let conversionValue = 10
    let timestamp = Date()

    saveEvents(events: recordedEvents, values: recordedValues, conversionValue: conversionValue, timestamp: timestamp)

    skAdNetworkReporter._loadReportData()
    XCTAssertEqual(
      recordedEvents,
      skAdNetworkReporter.recordedEvents,
      "Should load the expected recorded events"
    )
    XCTAssertEqual(
      recordedValues,
      skAdNetworkReporter.recordedValues,
      "Should load the expected recorded values"
    )
    XCTAssertEqual(
      conversionValue,
      skAdNetworkReporter.conversionValue,
      "Should load the expected conversion value"
    )
    XCTAssertEqual(
      timestamp.timeIntervalSince1970,
      skAdNetworkReporter.timestamp.timeIntervalSince1970,
      "Should load the expected timestamp"
    )
  }

  func testLoadConfigurationWithValidCache() {
    skAdNetworkReporter.serialQueue = DispatchQueue(label: self.name)
    skAdNetworkReporter.completionBlocks = []
    skAdNetworkReporter.configRefreshTimestamp = Date()
    userDefaultsSpy.set(
      SampleSKAdNetworkConversionConfiguration.configJson,
      forKey: "com.facebook.sdk:FBSDKSKAdNetworkConversionConfiguration"
    )

    var count = 0
    skAdNetworkReporter._loadConfiguration { count += 1 }

    XCTAssertEqual(
      count,
      1,
      "Should expect the execution block to be called once"
    )
    XCTAssertEqual(
      graphRequestFactory.capturedRequests.count,
      0,
      "Should not have graph request with valid cache"
    )
  }

  func testLoadConfigurationWithoutValidCacheAndWithoutNetworkError() {
    skAdNetworkReporter.config = nil
    skAdNetworkReporter.serialQueue = DispatchQueue(label: "test")
    skAdNetworkReporter.completionBlocks = NSMutableArray()

    var count = 0
    skAdNetworkReporter._loadConfiguration { count += 1 }

    let request = graphRequestFactory.capturedRequests[0]
    request.capturedCompletionHandler?(
      nil,
      SampleSKAdNetworkConversionConfiguration.configJson,
      nil
    )
    XCTAssertEqual(count, 1, "Should expect the execution block to be called once")
    XCTAssertEqual(self.graphRequestFactory.capturedRequests.count, 1, "Should have graph request without valid cache")
    XCTAssertTrue(
      graphRequestFactory.capturedGraphPath?.contains(
        "ios_skadnetwork_conversion_config"
      ) == true,
      "Should have graph request for config without valid cache"
    )
    XCTAssertNotNil(self.skAdNetworkReporter.config, "Should have expected config")
  }

  func testLoadConfigurationWithoutValidCacheAndWithNetworkError() {
    skAdNetworkReporter.config = nil
    skAdNetworkReporter.serialQueue = DispatchQueue(label: self.name)
    skAdNetworkReporter.completionBlocks = NSMutableArray()

    var count = 0
    skAdNetworkReporter._loadConfiguration { count += 1 }

    let request = self.graphRequestFactory.capturedRequests[0]
    request.capturedCompletionHandler?(
      nil,
      SampleSKAdNetworkConversionConfiguration.configJson,
      SampleError()
    )
    XCTAssertEqual(
      count,
      0,
      "Should not expect the execution block to be called"
    )
    XCTAssertEqual(
      graphRequestFactory.capturedRequests.count,
      1,
      "Should have graph request without valid cache"
    )
    XCTAssertTrue(
      graphRequestFactory.capturedGraphPath?.contains(
        "ios_skadnetwork_conversion_config"
      ) == true,
      "Should have graph request for config without valid cache"
    )
    XCTAssertNil(
      skAdNetworkReporter.config,
      "Should not have config with network error"
    )
  }

  func testShouldCutoffWithoutTimestampWithoutCutoffTime() {
    XCTAssertTrue(
      skAdNetworkReporter.shouldCutoff(),
      "Should cut off reporting when there is no install timestamp or cutoff time"
    )
  }

  func testShouldCutoffWithoutTimestampWithCutoffTime() {
    skAdNetworkReporter.setConfiguration(defaultConfiguration)
    XCTAssertFalse(
      skAdNetworkReporter.shouldCutoff(),
      "Should not cut off reporting when there is no install timestamp"
    )
  }

  func testShouldCutoffWithTimestampWithoutCutoffTime() {
    userDefaultsSpy.set(
      Date.distantPast,
      forKey: "com.facebook.sdk:FBSDKSKAdNetworkReporter"
    )
    XCTAssertTrue(
      skAdNetworkReporter.shouldCutoff(),
      "Should cut off reporting when when the timestamp is earlier than the current date and there's no cutoff date provided" // swiftlint:disable:this line_length
    )
    userDefaultsSpy.set(
      Date.distantFuture,
      forKey: "com.facebook.sdk:FBSDKSKAdNetworkReporter"
    )
    XCTAssertTrue(
      skAdNetworkReporter.shouldCutoff(),
      "Should cut off reporting when when the timestamp is earlier than the current date and there's no cutoff date provided" // swiftlint:disable:this line_length
    )
  }

  func testShouldCutoffWhenTimestampEarlierThanCutoffTime() {
    skAdNetworkReporter.setConfiguration(defaultConfiguration)
    userDefaultsSpy.set(
      Date.distantPast,
      forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp"
    )

    XCTAssertTrue(
      skAdNetworkReporter.shouldCutoff(),
      "Should cut off reporting when the install timestamp is one day before the cutoff date" // swiftlint:disable:this line_length
    )
  }

  func testShouldCutoffWhenTimestampLaterThanCutoffTime() {
    skAdNetworkReporter.setConfiguration(defaultConfiguration)
    userDefaultsSpy.set(
      Date.distantFuture,
      forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp"
    )

    XCTAssertFalse(
      skAdNetworkReporter.shouldCutoff(),
      "Should cut off reporting when the install timestamp is one day before the cutoff date" // swiftlint:disable:this line_length
    )
  }

  func testShouldCutoff() {
    skAdNetworkReporter.setConfiguration(defaultConfiguration)
    // Case 1: refresh install
    Settings.shared.recordInstall()
    XCTAssertFalse(skAdNetworkReporter.shouldCutoff())

    // Case 2: timestamp is already expired
    let calendar = Calendar(identifier: .gregorian)
    var addComponents = DateComponents()
    addComponents.day = -2

    let expiredDate = calendar.date(byAdding: addComponents, to: Date())
    userDefaultsSpy.set(
      expiredDate,
      forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp"
    )
    XCTAssertTrue(skAdNetworkReporter.shouldCutoff())

    userDefaultsSpy.removeObject(forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp")
  }

  func testCutoffWhenTimeBucketIsAvailable() {
    if #available(iOS 14.0, *) {
      skAdNetworkReporter.setConfiguration(defaultConfiguration)
      let today = Date()
      let calendar = Calendar(identifier: .gregorian)
      var addComponents = DateComponents()
      addComponents.day = -2
      let expiredDate = calendar.date(byAdding: addComponents, to: today)
      userDefaultsSpy.set(
        expiredDate,
        forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp"
      )

      XCTAssertTrue(skAdNetworkReporter.shouldCutoff())
      skAdNetworkReporter.checkAndRevokeTimer()
      XCTAssertNil(
        userDefaultsSpy.object(
          forKey: "com.facebook.sdk:FBSDKSKAdNetworkReporter"
        )
      )
      XCTAssertFalse(TestConversionValueUpdating.wasUpdateVersionValueCalled)
      userDefaultsSpy.removeObject(forKey: "com.facebook.sdk:FBSDKSettingsInstallTimestamp")
    }
  }

  func testIsReportingEventWithConfig() {
    skAdNetworkReporter.setConfiguration(
      SKAdNetworkConversionConfiguration(
        json: SampleSKAdNetworkConversionConfiguration.configJson
      )! // swiftlint:disable:this force_unwrapping
    )
    XCTAssertTrue(
      skAdNetworkReporter.isReportingEvent("fb_test"),
      "Should expect to be true for event in the config"
    )

    XCTAssertFalse(
      skAdNetworkReporter.isReportingEvent("test"),
      "Should expect to be false for event not in the config"
    )
  }

  func testUpdateConversionValue() {
    skAdNetworkReporter.setConfiguration(defaultConfiguration)
    skAdNetworkReporter._updateConversionValue(2)
    XCTAssertTrue(
      TestConversionValueUpdating.wasUpdateVersionValueCalled,
      "Should call updateConversionValue when not cutoff"
    )
  }

  func testRecord() throws {
    if #available(iOS 14.0, *) {
      let config = SKAdNetworkConversionConfiguration(json: SampleSKAdNetworkConversionConfiguration.configJson)
      skAdNetworkReporter.setConfiguration(config!) // swiftlint:disable:this force_unwrapping
      skAdNetworkReporter._recordAndUpdateEvent("fb_test", currency: nil, value: nil)
      skAdNetworkReporter._recordAndUpdateEvent("fb_mobile_purchase", currency: "USD", value: 100)
      skAdNetworkReporter._recordAndUpdateEvent("fb_mobile_purchase", currency: "USD", value: 201)
      skAdNetworkReporter._recordAndUpdateEvent("test", currency: nil, value: nil)

      let cache = try XCTUnwrap(userDefaultsSpy.object(forKey: "com.facebook.sdk:FBSDKSKAdNetworkReporter") as? Data)

      let data = try? NSKeyedUnarchiver.unarchivedObject(
        ofClasses: [NSDictionary.self, NSString.self, NSNumber.self, NSDate.self, NSSet.self],
        from: cache
      ) as? [String: Any]

      let recordedEvents = data?["recorded_events"] as? Set<String>
      let expectedEvents = Set(["fb_test", "fb_mobile_purchase"])
      XCTAssertTrue(expectedEvents == recordedEvents)
      let recordedValues = data?["recorded_values"] as? [String: [String: Int]]

      let expectedValues = ["fb_mobile_purchase": ["USD": 301]]
      XCTAssertTrue(expectedValues == recordedValues)
    }
  }

  func testInitializeWithDependencies() {
    let graphRequestFactory = GraphRequestFactory()
    let store = UserDefaultsSpy()
    let reporter = SKAdNetworkReporter(
      graphRequestFactory: graphRequestFactory,
      store: store,
      conversionValueUpdatable: TestConversionValueUpdating.self
    )

    XCTAssertEqual(
      graphRequestFactory,
      reporter.graphRequestFactory as? GraphRequestFactory,
      "Should be able to configure a reporter with a request provider"
    )
    XCTAssertEqual(
      store,
      reporter.store as? UserDefaultsSpy,
      "Should be able to configure a reporter with a request provider"
    )
    XCTAssertTrue(
      reporter.conversionValueUpdatable == TestConversionValueUpdating.self,
      "Should be able to configure a reporter with a Conversion Value Updater"
    )
  }

  func saveEvents(
    events: NSMutableSet,
    values: NSMutableDictionary,
    conversionValue: NSInteger,
    timestamp: Date
  ) {
    let reportData: NSMutableDictionary = [:]
    reportData["conversion_value"] = conversionValue
    reportData["timestamp"] = timestamp
    reportData["recorded_events"] = events
    reportData["recorded_values"] = values
    let cache = NSKeyedArchiver.archivedData(withRootObject: reportData)
    userDefaultsSpy.set(cache, forKey: "com.facebook.sdk:FBSDKSKAdNetworkReporter")
  }
}
