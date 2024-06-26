/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBAlertsMonitor.h"

#import "FBAlert.h"
#import "FBLogger.h"
#import "XCUIApplication+FBAlert.h"
#import "XCUIApplication+FBHelpers.h"

static const NSTimeInterval FB_MONTORING_INTERVAL = 2.0;

@interface FBAlertsMonitor()

@property (atomic) BOOL isMonitoring;

@end

@implementation FBAlertsMonitor

- (instancetype)init
{
  if ((self = [super init])) {
    _isMonitoring = NO;
    _delegate = nil;
  }
  return self;
}

- (void)scheduleNextTick
{
  if (!self.isMonitoring) {
    return;
  }

  dispatch_time_t delta = (int64_t)(FB_MONTORING_INTERVAL * NSEC_PER_SEC);

  if (nil == self.delegate) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), ^{
      [self scheduleNextTick];
    });
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSArray<XCUIApplication *> *activeApps = XCUIApplication.fb_activeApplications;
    for (XCUIApplication *activeApp in activeApps) {
      XCUIElement *alertElement = nil;
      @try {
        alertElement = activeApp.fb_alertElement;
        if (nil != alertElement) {
          [self.delegate didDetectAlert:[FBAlert alertWithElement:alertElement]];
        }
      } @catch (NSException *e) {
        [FBLogger logFmt:@"Got an unexpected exception while monitoring alerts: %@\n%@", e.reason, e.callStackSymbols];
      }
      if (nil != alertElement) {
        break;
      }
    }

    if (self.isMonitoring) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), ^{
        [self scheduleNextTick];
      });
    }
  });
}

- (void)enable
{
  if (self.isMonitoring) {
    return;
  }

  self.isMonitoring = YES;
  [self scheduleNextTick];
}

- (void)disable
{
  if (!self.isMonitoring) {
    return;
  }

  self.isMonitoring = NO;
}

@end
