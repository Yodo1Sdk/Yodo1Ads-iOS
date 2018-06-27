//
//  AnalyticsAdapterAppsFlyer.m
//
//  Created by hyx on 14-10-14.
//  Copyright (c) 2014年 yodo1. All rights reserved.
//

#import "AnalyticsAdapterAppsFlyer.h"
#import "Yodo1Registry.h"
#import <AppsFlyerLib/AppsFlyerTracker.h>
#import "Yodo1Commons.h"
#import "Yodo1KeyInfo.h"

NSString* const YODO1_ANALYTICS_APPSFLYER_DEV_KEY       = @"AppsFlyerDevKey";
NSString* const YODO1_ANALYTICS_APPSFLYER_APPLE_APPID   = @"AppleAppId";


@implementation AnalyticsAdapterAppsFlyer

+ (AnalyticsType)analyticsType {
    return AnalyticsTypeAppsFlyer;
}

+ (void)load
{
    [[Yodo1Registry sharedRegistry] registerClass:self withRegistryType:@"analyticsType"];
}

- (id)initWithAnalytics:(AnalyticsInitConfig *)initConfig {
    self = [super init];
    if (self) {
        if([[Yodo1AnalyticsManager sharedInstance]isAppsFlyerInstalled]){
            NSString* devkey = [[Yodo1KeyInfo shareInstance] configInfoForKey:YODO1_ANALYTICS_APPSFLYER_DEV_KEY];
            NSString* appleAppId = [[Yodo1KeyInfo shareInstance] configInfoForKey:YODO1_ANALYTICS_APPSFLYER_APPLE_APPID];
            NSAssert(devkey != nil||appleAppId != nil, @"AppsFlyer devKey 没有设置");
            [[NSNotificationCenter defaultCenter]addObserver:self
                                                    selector:@selector(applicationDidBecomeActive:)//前台进入后台
                                                        name:UIApplicationDidBecomeActiveNotification
                                                      object:nil];
            
            [AppsFlyerTracker sharedTracker].appsFlyerDevKey = devkey;
            [AppsFlyerTracker sharedTracker].appleAppID = appleAppId;
        }
    }
    return self;
}

- (void)applicationDidBecomeActive:(NSNotification*)notifi {
    [[AppsFlyerTracker sharedTracker] trackAppLaunch];
}

- (void)eventWithAnalyticsEventName:(NSString *)eventName
                          eventData:(NSDictionary *)eventData
{
    [[AppsFlyerTracker sharedTracker]trackEvent:eventName withValues:eventData?eventData:@{}];
}

- (void)validateAndTrackInAppPurchase:(NSString*)productIdentifier
                                price:(NSString*)price
                             currency:(NSString*)currency
                        transactionId:(NSString*)transactionId {
    if([[Yodo1AnalyticsManager sharedInstance]isAppsFlyerInstalled]){
        [[AppsFlyerTracker sharedTracker] validateAndTrackInAppPurchase:productIdentifier
                                                                  price:price
                                                               currency:currency
                                                          transactionId:transactionId
                                                   additionalParameters:@{}
                                                                success:^(NSDictionary *result){
                                                                    NSLog(@"Purcahse succeeded And verified!!! response: %@",result[@"receipt"]);
                                                                } failure:^(NSError *error, id response) {
                                                                    NSLog(@"response = %@", response);
                                                                }];
    }
}

- (void)dealloc {
     if([[Yodo1AnalyticsManager sharedInstance]isAppsFlyerInstalled]){
        [[NSNotificationCenter defaultCenter]removeObserver:self
                                                       name:UIApplicationDidBecomeActiveNotification
                                                     object:nil];
     }
}

@end
