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

import UIKit

@objcMembers
class ViewControllerSpy: UIViewController {

  var capturedDismissCompletion: (() -> Void)?
  var dismissWasCalled = false
  var capturedPresentViewController: UIViewController?
  var capturedPresentViewControllerAnimated = false
  var capturedPresentViewControllerCompletion: (() -> Void)?

  /// Used for providing a value to return for the readonly `transitionCoordinator` property
  var stubbedTransitionCoordinator: UIViewControllerTransitionCoordinator?

  // Overriding with no implementation to stub the property
  override var transitionCoordinator: UIViewControllerTransitionCoordinator? {
    stubbedTransitionCoordinator
  }

  private lazy var presenting = {
    ViewControllerSpy.makeDefaultSpy()
  }()

  override var presentingViewController: UIViewController? {
    presenting
  }

  override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    dismissWasCalled = true
    capturedDismissCompletion = completion
  }

  static func makeDefaultSpy() -> ViewControllerSpy {
    ViewControllerSpy()
  }

  // Overriding with no implementation to stub the method
  override func present(
    _ viewControllerToPresent: UIViewController,
    animated: Bool,
    completion: (() -> Void)? = nil
  ) {
    capturedPresentViewController = viewControllerToPresent
    capturedPresentViewControllerAnimated = animated
    capturedPresentViewControllerCompletion = completion
  }
}
