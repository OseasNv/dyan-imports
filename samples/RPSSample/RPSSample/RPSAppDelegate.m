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

#import "RPSAppDelegate.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

#import "RPSAppLinkedViewController.h"
#import "RPSAutoAppLinkBasicViewController.h"
#import "RPSAutoAppLinkStoryboardViewController.h"
#import "RPSCommonObjects.h"
#import "RPSRootViewController.h"
#import "RPSSample-Swift.h"

@implementation RPSAppDelegate

#pragma mark - Class methods

+ (RPSCall)callFromAppLinkURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
{
  FBSDKURL *appLinkURL = [FBSDKURL URLWithInboundURL:url sourceApplication:sourceApplication];
  NSURL *appLinkTargetURL = [appLinkURL targetURL];
  if (!appLinkTargetURL) {
    return RPSCallNone;
  }
  NSString *queryString = [appLinkTargetURL query];
  for (NSString *component in [queryString componentsSeparatedByString:@"&"]) {
    NSArray *pair = [component componentsSeparatedByString:@"="];
    NSString *param = pair[0];
    NSString *val = pair[1];
    if ([param isEqualToString:@"gesture"]) {
      if ([val isEqualToString:@"rock"]) {
        return RPSCallRock;
      } else if ([val isEqualToString:@"paper"]) {
        return RPSCallPaper;
      } else if ([val isEqualToString:@"scissors"]) {
        return RPSCallScissors;
      }
    }
  }

  return RPSCallNone;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  return [self application:application
                    openURL:url
          sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                 annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

// Still need this for iOS8
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(nullable NSString *)sourceApplication
         annotation:(nonnull id)annotation
{
  FBSDKURL *appLink = [FBSDKURL URLWithInboundURL:url sourceApplication:sourceApplication];
  if (appLink.isAutoAppLink) {
    [[[UIAlertView alloc] initWithTitle:@"Received Auto App Link:"
                                message:[NSString stringWithFormat:@"product id: %@", appLink.appLinkData[@"product_id"]]
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
  }

  BOOL result = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                               openURL:url
                                                     sourceApplication:sourceApplication
                                                            annotation:annotation];
  return result;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen.mainScreen bounds]];
  // Override point for customization after application launch.

  RPSRootViewController *rootViewController = [[RPSRootViewController alloc] init];
  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];

  [FBSDKAppLinkUtility fetchDeferredAppLink:^(NSURL *url, NSError *error) {
    if (error) {
      NSLog(@"Received error while fetching deferred app link %@", error);
    }
    if (url) {
      [UIApplication.sharedApplication openURL:url];
    }
  }];

  return YES;
}

@end
