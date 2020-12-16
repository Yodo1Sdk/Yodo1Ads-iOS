//
//  Yodo1Ads.m
//
//  Created by hyx on 17/7/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Yodo1Ads.h"
#import "Yodo1AdsC.h"
#import "Yodo1UnityTool.h"

#import "Yd1OnlineParameter.h"
//#import "Yodo1Analytics.h"
#import "Yodo1ReportError.h"
#import <Bugly/Bugly.h>
#import "YD1LogView.h"
#import "Yodo1Commons.h"
#import "Yodo1AdConfigHelper.h"
#import "Yodo1Tool+Commons.h"
#import "Yodo1Tool+Storage.h"

#ifdef YODO1_ADS
#import "Yodo1AdVideoManager.h"
#import "Yodo1InterstitialAdManager.h"
#import "Yodo1BannerManager.h"
#import "Yodo1BannerDelegate.h"
#import "Yodo1RewardGameViewController.h"
#import "Yodo1SplashManager.h"
#import "Yodo1SplashDelegate.h"
#endif

#ifdef YODO1_ANALYTICS
#import "Yodo1AnalyticsManager.h"
#endif


#import <Yodo1SaAnalyticsSDK/Yodo1SensorsAnalyticsSDK.h>
#import <Yodo1SaAnalyticsSDK/Yodo1SaManager.h>

#import <AppTrackingTransparency/AppTrackingTransparency.h>

///C++
static Yodo1AdsEvent_Callback s_banner_callback;

static Yodo1AdsEvent_Callback s_interstitial_callback;

static Yodo1AdsEvent_Callback s_video_callback;

static Yodo1AdsEvent_Callback s_splash_callback;

//OC
static Yodo1AdsEventCallback s_bannerCallback;

static Yodo1AdsEventCallback s_interstitialCallback;

static Yodo1AdsEventCallback s_videoCallback;

static Yodo1AdsEventCallback s_splashCallback;

//Unity3d
const char* UNITY3D_YODO1ADS_METHOD     = "Yodo1U3dSDKCallBackResult";
static NSString* kYodo1AdsGameObject    = @"Yodo1Ads";//默认

NSString* const kYodo1AdsVersion       = @"4.9.0";

typedef enum {
    Yodo1AdsTypeBanner          = 1001,//Banner
    Yodo1AdsTypeInterstitial    = 1002,//Interstitial
    Yodo1AdsTypeVideo           = 1003,//Video
    Yodo1AdsTypeSplash          = 1006,//Splash
    Yodo1AdsTypeRewardGame      = 1007,//RewardGame //与安卓一致
}Yodo1AdsType;

@interface Yodo1AdsDelegate : NSObject

+ (instancetype)instance;

+ (UIViewController*)getRootViewController;

+ (UIViewController*)topMostViewController:(UIViewController*)controller;

+ (NSString *)stringWithJSONObject:(id)obj error:(NSError**)error;

+ (id)JSONObjectWithString:(NSString*)str error:(NSError**)error;

+ (void)unitySendMessageResulTypeWithCode:(Yodo1AdsType)type code:(int)code error:(NSString*)errorMsg;

@end

@implementation Yodo1AdsDelegate

+ (instancetype)instance {
    static Yodo1AdsDelegate *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Yodo1AdsDelegate alloc] init];
    });
    
    return sharedInstance;
}

+ (UIViewController*)getRootViewController {
    UIWindow* window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray* windows = [[UIApplication sharedApplication] windows];
        for (UIWindow* _window in windows) {
            if (_window.windowLevel == UIWindowLevelNormal) {
                window = _window;
                break;
            }
        }
    }
    UIViewController* viewController = nil;
    for (UIView* subView in [window subviews]) {
        UIResponder* responder = [subView nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            viewController = [self topMostViewController:(UIViewController*)responder];
        }
    }
    if (!viewController) {
        viewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    }
    return viewController;
}

+ (UIViewController*)topMostViewController:(UIViewController*)controller {
    BOOL isPresenting = NO;
    do {
        // this path is called only on iOS 6+, so -presentedViewController is fine here.
        UIViewController* presented = [controller presentedViewController];
        isPresenting = presented != nil;
        if (presented != nil) {
            controller = presented;
        }
        
    } while (isPresenting);
    
    return controller;
}

+ (NSString*)stringWithJSONObject:(id)obj error:(NSError**)error {
    if (obj) {
        if (NSClassFromString(@"NSJSONSerialization")) {
            NSData* data = nil;
            @try {
                data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:error];
            }
            @catch (NSException* exception)
            {
                *error = [NSError errorWithDomain:[exception description] code:0 userInfo:nil];
                return nil;
            }
            @finally
            {
            }
            
            if (data) {
                return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
        }
    }
    return nil;
}

+ (id)JSONObjectWithString:(NSString*)str error:(NSError**)error {
    if (str) {
        if (NSClassFromString(@"NSJSONSerialization")) {
            return [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding]
                                                   options:NSJSONReadingAllowFragments
                                                     error:error];
        }
    }
    return nil;
}

+ (void)unitySendMessageResulTypeWithCode:(Yodo1AdsType)type code:(int)code error:(NSString*)errorMsg
{
    if (kYodo1AdsGameObject) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        [dict setObject:[NSNumber numberWithInt:type] forKey:@"resulType"];
        [dict setObject:[NSNumber numberWithInt:code] forKey:@"code"];
        NSError* parseJSONError = nil;
        NSString* msg = [Yodo1AdsDelegate stringWithJSONObject:dict error:&parseJSONError];
        NSString* jsonError = @"";
        if(parseJSONError){
            jsonError = @"Convert result to json failed!";
        }
        if (errorMsg) {
            jsonError = [NSString stringWithFormat:@"%@,errorMsg:%@",jsonError,errorMsg];
            [dict setObject:jsonError forKey:@"error"];
            msg =  [Yodo1AdsDelegate stringWithJSONObject:dict error:&parseJSONError];
        }
        UnitySendMessage([kYodo1AdsGameObject cStringUsingEncoding:NSUTF8StringEncoding],UNITY3D_YODO1ADS_METHOD,
                         [msg cStringUsingEncoding:NSUTF8StringEncoding] );
    }
}

@end

#ifdef YODO1_ADS

@interface Yodo1adsSplashDelegate : NSObject<Yodo1SplashDelegate>
+ (instancetype)instance;
@end

@implementation Yodo1adsSplashDelegate

+ (instancetype)instance {
    static Yodo1adsSplashDelegate *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Yodo1adsSplashDelegate alloc] init];
    });
    
    return sharedInstance;
}

-(void)splashDidLoad {
    if(s_splash_callback){
        s_splash_callback(Yodo1AdsCEventLoaded,nil);
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventLoaded,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventLoaded error:nil];
}

-(void)splashDidFailToLoadWithError:(NSError *)error {
    if(s_splash_callback){
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            s_splash_callback(Yodo1AdsCEventLoadFail,errorC);
        }else{
            s_splash_callback(Yodo1AdsCEventLoadFail,nil);
        }
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventLoadFail,error);
    }
    NSString* errorMsg = nil;
    if (error) {
        errorMsg = [error localizedDescription];
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventLoadFail error:errorMsg];
}

-(void)splashDidShow {
    if(s_splash_callback){
        s_splash_callback(Yodo1AdsCEventShowSuccess,nil);
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventShowSuccess,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventShowSuccess error:nil];
}

-(void)splashDidClick {
    if(s_splash_callback){
        s_splash_callback(Yodo1AdsCEventClick,nil);
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventClick,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventShowSuccess error:nil];
}

-(void)splashDidClose {
    if(s_splash_callback){
        s_splash_callback(Yodo1AdsCEventClose,nil);
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventClose,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventShowSuccess error:nil];
}

-(void)splashDidSkip {
    if(s_splash_callback){
        s_splash_callback(Yodo1AdsCEventSkip,nil);
    }
    if(s_splashCallback){
        s_splashCallback(Yodo1AdsEventSkip,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeSplash code:Yodo1AdsEventShowSuccess error:nil];
}

@end

@interface Yodo1AdsVideoDelegate : NSObject<Yodo1VideoDelegate>

+ (instancetype)instance;

@end

@implementation Yodo1AdsVideoDelegate

+ (instancetype)instance {
    static Yodo1AdsVideoDelegate *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Yodo1AdsVideoDelegate alloc] init];
    });
    
    return sharedInstance;
}

#pragma mark- Yodo1VideoDelegate

- (void)onVideoShowSuccess {
    if(s_video_callback){
        s_video_callback(Yodo1AdsCEventShowSuccess,nil);
    }
    if(s_videoCallback){
        s_videoCallback(Yodo1AdsEventShowSuccess,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeVideo code:Yodo1AdsEventShowSuccess error:nil];
}

- (void)onVideoShowFailed:(nonnull NSError *)error {
    if(s_video_callback){
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            s_video_callback(Yodo1AdsCEventLoadFail,errorC);
        }else{
            s_video_callback(Yodo1AdsCEventLoadFail,nil);
        }
    }
    if(s_videoCallback){
        s_videoCallback(Yodo1AdsEventLoadFail,error);
    }
    NSString* errorMsg = nil;
    if (error) {
        errorMsg = [error localizedDescription];
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeVideo code:Yodo1AdsEventLoadFail error:errorMsg];
}

- (void)onVideoClicked {
    if(s_video_callback){
        s_video_callback(Yodo1AdsCEventClick,nil);
    }
    if(s_videoCallback){
        s_videoCallback(Yodo1AdsEventClick,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeVideo code:Yodo1AdsEventClick error:nil];
}

- (void)onVideoClosed:(BOOL)finished {
    if(s_video_callback){
        if (finished) {
            s_video_callback(Yodo1AdsCEventFinish,nil);
        }else{
            s_video_callback(Yodo1AdsCEventClose,nil);
        }
    }
    if(s_videoCallback){
        if (finished) {
            s_videoCallback(Yodo1AdsEventFinish,nil);
        }else{
            s_videoCallback(Yodo1AdsEventClose,nil);
        }
    }
    if (finished) {
        [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeVideo code:Yodo1AdsEventFinish error:nil];
    }else{
        [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeVideo code:Yodo1AdsEventClose error:nil];
    }
}

@end

#endif

#ifdef YODO1_ADS

@interface Yodo1AdsInterstitialDelegate : NSObject<InterstitialAdDelegate>

+ (instancetype)instance;

@end

@implementation Yodo1AdsInterstitialDelegate

+ (instancetype)instance {
    static Yodo1AdsInterstitialDelegate *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Yodo1AdsInterstitialDelegate alloc] init];
    });
    
    return sharedInstance;
}

- (void)interstitialDidLoad {
    if(s_interstitial_callback){
        s_interstitial_callback(Yodo1AdsCEventLoaded,nil);
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventLoaded,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventLoaded error:nil];
}

- (void)interstitialDidFailToLoadWithError:(NSError *)error {
    if(s_interstitial_callback){
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            s_interstitial_callback(Yodo1AdsCEventLoadFail,errorC);
        }else{
            s_interstitial_callback(Yodo1AdsCEventLoadFail,nil);
        }
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventLoadFail,error);
    }
    NSString* errorMsg = nil;
    if (error) {
        errorMsg = [error localizedDescription];
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventLoadFail error:errorMsg];
}

- (void)interstitialDidShow {
    if(s_interstitial_callback){
        s_interstitial_callback(Yodo1AdsCEventShowSuccess,nil);
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventShowSuccess,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventShowSuccess error:nil];
}

- (void)interstitialDidClose {
    if(s_interstitial_callback){
        s_interstitial_callback(Yodo1AdsCEventClose,nil);
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventClose,nil);
    }
    
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventClose error:nil];
}

- (void)didClickInterstitial {
    if(s_interstitial_callback){
        s_interstitial_callback(Yodo1AdsCEventClick,nil);
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventClick,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventClick error:nil];
}

- (void)interstitialDidFailToShowWithError:(NSError *)error {
    if(s_interstitial_callback){
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            s_interstitial_callback(Yodo1AdsCEventShowFail,errorC);
        }else{
            s_interstitial_callback(Yodo1AdsCEventShowFail,nil);
        }
        
    }
    if(s_interstitialCallback){
        s_interstitialCallback(Yodo1AdsEventShowFail,error);
    }
    NSString* errorMsg = nil;
    if (error) {
        errorMsg = [error localizedDescription];
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeInterstitial code:Yodo1AdsEventShowFail error:errorMsg];
}

@end

#endif

#ifdef YODO1_ADS

@interface Yodo1AdsBannerDelegate : NSObject<Yodo1BannerDelegate>

+ (instancetype)instance;

@end

@implementation Yodo1AdsBannerDelegate

+ (instancetype)instance {
    static Yodo1AdsBannerDelegate *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Yodo1AdsBannerDelegate alloc] init];
    });
    
    return sharedInstance;
}

#pragma mark-BannerAdDelegate

- (void)bannerDidLoad {
    if(s_banner_callback){
        s_banner_callback(Yodo1AdsCEventLoaded,nil);
    }
    
    if(s_bannerCallback){
        s_bannerCallback(Yodo1AdsEventLoaded,nil);
    }
    
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeBanner code:Yodo1AdsEventLoaded error:nil];
}

- (void)bannerDidFailToLoadWithError:(NSError *)error {
    if(s_banner_callback){
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            s_banner_callback(Yodo1AdsCEventLoadFail,errorC);
        }else{
            s_banner_callback(Yodo1AdsCEventLoadFail,nil);
        }
    }
    if(s_bannerCallback){
        s_bannerCallback(Yodo1AdsEventLoadFail,error);
    }
    NSString* errorMsg = nil;
    if (error) {
        errorMsg = [error localizedDescription];
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeBanner code:Yodo1AdsEventLoadFail error:errorMsg];
}

- (void)bannerWillPresentScreen {
    if(s_banner_callback){
        s_banner_callback(Yodo1AdsCEventShowSuccess,nil);
    }
    if(s_bannerCallback){
        s_bannerCallback(Yodo1AdsEventShowSuccess,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeBanner code:Yodo1AdsEventShowSuccess error:nil];
}

- (void)didClickBanner {
    if(s_banner_callback){
        s_banner_callback(Yodo1AdsCEventClick,nil);
    }
    if(s_bannerCallback){
        s_bannerCallback(Yodo1AdsEventClick,nil);
    }
    [Yodo1AdsDelegate unitySendMessageResulTypeWithCode:Yodo1AdsTypeBanner code:Yodo1AdsEventClick error:nil];
}

@end

#endif


#pragma mark- ///OC实现

@interface Yodo1Ads ()

+ (NSDictionary*)config;

+ (NSString*)publishType;

+ (NSString*)publishVersion;

@end

@implementation Yodo1Ads

static BOOL bYodo1AdsInited = NO;
static NSString* yd1AppKey = @"";


+ (void)initWithAppKey:(NSString *)appKey {
    if (bYodo1AdsInited) {
        NSLog(@"[Yodo1 Ads] has already been initialized");
        return;
    }
    bYodo1AdsInited = true;
    [NSNotificationCenter.defaultCenter addObserver:[Yodo1Ads class] selector:@selector(onlineParamete:) name:kYodo1OnlineConfigFinishedNotification object:nil];
    //初始化在线参数
    [Yd1OnlineParameter.shared initWithAppKey:appKey channelId:@"AppStore"];
    yd1AppKey = appKey;
    //初始化错误上报系统
    NSString* feedback = [Yd1OnlineParameter.shared stringConfigWithKey:@"Platform_Feedback_SwitchAd" defaultValue:@"off"];
    if ([feedback isEqualToString:@"on"]) {//默认是关
        [[Yodo1ReportError instance]initWithAppKey:appKey channel:@"appstore"];
        //每次启动游戏都会上传一次
        [[Yodo1ReportError instance]uploadReportError];
    }
    
    //初始化数据统计
    //TODO 暂时停止Yodo1 统计
    //    [[Yodo1Analytics instance]releaseSDKVersion:kYodo1AdsVersion];
    //    [[Yodo1Analytics instance]initWithAppKey:appKey channelId:@"appstore"];
    
#ifdef YODO1_ADS
    //初始化Banner
    [[Yodo1BannerManager sharedInstance]initBannerSDK:[Yodo1AdsBannerDelegate instance]];
    //Interstital 初始化
    [[Yodo1InterstitialAdManager sharedInstance]initInterstitalSDK:[Yodo1AdsInterstitialDelegate instance]];
    //初始化Video
    [Yodo1AdVideoManager setDelegate:[Yodo1AdsVideoDelegate instance]];
    [[Yodo1SplashManager sharedInstance] setDelegate:[Yodo1adsSplashDelegate instance]];
    [[Yodo1AdVideoManager sharedInstance]initAdVideoSDK];
#endif
    
    if (Yd1OnlineParameter.shared.bTestDevice && Yd1OnlineParameter.shared.bFromPA) {
        [YD1LogView startLog:appKey];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(startTime) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(endTime) name:UIApplicationWillResignActiveNotification object:nil];
}


+ (void)startTime {
    if ([Yodo1AdConfigHelper.instance isSensorsSwitch]) {
        [Yodo1SensorsAnalyticsSDK.sharedInstance trackTimerStart:@"end"];
        [Yodo1SaManager track:@"startup" properties:@{}];
    }
    #ifdef YODO1_ANALYTICS
    if (Yodo1AnalyticsManager.enable) {
        [Yodo1AnalyticsManager.sharedInstance beginEvent:@"end"];
        [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"startup" eventData:@{}];
    }
    #endif
}

+ (void)endTime {
    if ([Yodo1AdConfigHelper.instance isSensorsSwitch]) {
        [Yodo1SensorsAnalyticsSDK.sharedInstance trackTimerEnd:@"end"];
    }
    #ifdef YODO1_ANALYTICS
    if (Yodo1AnalyticsManager.enable) {
        [Yodo1AnalyticsManager.sharedInstance endEvent:@"end"];
    }
    #endif
}

+ (void)onlineParamete:(NSNotification *)notif {
    NSDictionary* object = [notif object];
    BOOL isVerifyBundleidSwitch = Yodo1AdConfigHelper.instance.isVerifyBundleidSwitch;
    NSString * bid = Yodo1AdConfigHelper.instance.verifyBundleid;
    if (isVerifyBundleidSwitch && bid.length) {
        NSString * bundle_id = [Yodo1Commons appBundleId];
        if (![bid isEqualToString:bundle_id]) {
            UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"App Bundle id does not match appkey! Please check your appkey or bundle id, You can find them at the MAS Developer's website." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
                [alert dismissViewControllerAnimated:YES completion:nil];
            }]];
            [[Yodo1Commons getRootViewController] presentViewController:alert animated:YES completion:nil];
            return;
        }
    }
    
    //初始化神策数据统计
    NSDictionary * sensorsConfig = Yodo1AdConfigHelper.instance.sensorsConfig;
    NSString* sensorSwitch = sensorsConfig[kSensors_Switch];
    BOOL bSensorsSwitch = true;
    if (sensorSwitch && [sensorSwitch isEqualToString:@"off"]) {
        bSensorsSwitch = false;
    }
    [Yodo1AdConfigHelper.instance setSensorsSwitch:bSensorsSwitch];

    if (bSensorsSwitch) {
        NSString* serverURL = sensorsConfig[kSensors_ServerUrl];
        BOOL bSensorsLogEnable = [sensorsConfig[kSensors_Switch_DebugMode] isEqualToString:@"on"];
        [Yodo1SaManager initializeSdkServerURL: serverURL debug:(bSensorsLogEnable ? 2 : 0)];
        NSString* bundleId = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        [Yodo1SaManager profileSetOnce:@{@"yID":@"",@"game":bundleId,@"channel":@"appstore"}];
        [Yodo1SaManager registerSuperProperties:@{@"gameKey":yd1AppKey,
                                                  @"gameBundleId":bundleId,
                                                  @"sdkType":[Yodo1Ads publishType],
                                                  @"publishChannelCode":@"appstore",
                                                  @"sdkVersion":[Yodo1Ads publishVersion]}];
        NSDictionary * reportFields = [Yodo1AdConfigHelper instance].report_fields;
        if (reportFields) {
            [Yodo1SaManager add_track_public_properties:reportFields];
        }
        [Yodo1SaManager track:@"setCCPA"
                   properties:@{@"result":[Yodo1AdConfigHelper.instance isDoNotSell]?@"No":@"Yes"}];
        
        [Yodo1SaManager track:@"setGDPR"
                   properties:@{@"result":[Yodo1AdConfigHelper.instance isUserConsent]?@"Yes":@"No"}];
        
        [Yodo1SaManager track:@"setCOPPA"
                   properties:@{@"result":[Yodo1AdConfigHelper.instance isTagForUnderAgeOfConsent]?@"Yes":@"No"}];
    }
    if (object && bSensorsSwitch) {
        int code = [[object objectForKey:@"code"]intValue];
        NSString * result = (code == 0 || code == 10) ? @"success" : @"fail";
        [Yodo1SaManager track:@"onlineParameter" properties:@{@"result":result,@"errorCode":[NSString stringWithFormat:@"%d",code ? : 10]}];
        #ifdef YODO1_ANALYTICS
        [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"onlineParameter" eventData:@{@"result":result,@"errorCode":[NSNumber numberWithInt:code]}];
        #endif
    }
    [NSNotificationCenter.defaultCenter removeObserver:[Yodo1Ads class] name:kYodo1OnlineConfigFinishedNotification object:nil];
    ///Bugly
    NSString* buglyAppId = [Yd1OnlineParameter.shared stringConfigWithKey:@"BuglyAnalytic_AppId" defaultValue:@""];
    if (buglyAppId.length > 0 && [Yodo1Ads isUserConsent] && ![Yodo1Ads isTagForUnderAgeOfConsent]) {
        BuglyConfig* buglyConfig = [[BuglyConfig alloc]init];
#ifdef DEBUG
        buglyConfig.debugMode = YES;
#endif
        buglyConfig.channel = @"appstore";
        
        [Bugly startWithAppId:buglyAppId config:buglyConfig];
        
        NSString* sdkInfo = [NSString stringWithFormat:@"%@,%@",[Yodo1Ads publishType],[Yodo1Ads publishVersion]];
        
        [Bugly setUserIdentifier:Bugly.buglyDeviceId];
        [Bugly setUserValue:@"appstore" forKey:@"ChannelCode"];
        [Bugly setUserValue:yd1AppKey forKey:@"GameKey"];
        [Bugly setUserValue:Yodo1Tool.shared.keychainDeviceId forKey:@"DeviceID"];
        [Bugly setUserValue:sdkInfo forKey:@"SdkInfo"];
        [Bugly setUserValue:Yodo1Tool.shared.idfa forKey:@"IDFA"];
        [Bugly setUserValue:Yodo1Tool.shared.idfv forKey:@"IDFV"];
        [Bugly setUserValue:[Yodo1Commons territory] forKey:@"CountryCode"];
    }
    
    //初始化第三方统计 mas sdk 才初始化
#ifdef YODO1_ANALYTICS
    if ([Yd1OnlineParameter.shared.publishType hasPrefix:@"mas_"]) {
        [Yodo1AnalyticsManager.sharedInstance initializeAnalyticsWithConfig:nil];
    }
#endif
    
    //在线参数控制ATT是否弹出
    if (@available(iOS 14, *)) {
        if ([Yodo1AdConfigHelper.instance isATTMasterSwitch]) {
            if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusNotDetermined) {
                [Yodo1AdConfigHelper.instance setShowATTDialogEnabled:YES];
                [[Yodo1Tool.shared cached]setObject:[NSNumber numberWithBool:YES] forKey:@"ShenCeShowATTDialogEnabled"];
                [[Yodo1Tool.shared cached]setObject:[NSNumber numberWithBool:YES] forKey:@"UmengShowATTDialogEnabled"];
            }
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
            //神策
            if (bSensorsSwitch) {
                    if (![Yodo1AdConfigHelper.instance ShenCeATTDialogRunOneTimes]) {
                        NSNumber* bRunOneTimes = (NSNumber *)[[Yodo1Tool.shared cached]objectForKey:@"ShenCeShowATTDialogEnabled"];
                        if ([bRunOneTimes boolValue]) {
                    [Yodo1SaManager track:@"showATTDialog" properties:@{@"result":@"active"}];
                }
                        if (status == ATTrackingManagerAuthorizationStatusAuthorized) {
                        [Yodo1SaManager track:@"showATTDialog" properties:@{@"result":@"agree"}];
                    } else {
                        [Yodo1SaManager track:@"showATTDialog" properties:@{@"result":@"disagree"}];
                    }
                    [Yodo1AdConfigHelper.instance setShenCeATTDialogRunOneTimes:YES];
                        [[Yodo1Tool.shared cached]setObject:[NSNumber numberWithBool:NO] forKey:@"ShenCeShowATTDialogEnabled"];
                }
            }
            #ifdef YODO1_ANALYTICS
            //友盟统计
                if (![Yodo1AdConfigHelper.instance UmengATTDialogRunOneTimes]) {
                    NSNumber* bRunOneTimes = (NSNumber *)[[Yodo1Tool.shared cached]objectForKey:@"UmengShowATTDialogEnabled"];
                    if ([bRunOneTimes boolValue]) {
                [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"showATTDialog" eventData:@{@"result":@"active"}];
            }
                    if (status == ATTrackingManagerAuthorizationStatusAuthorized) {
                    [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"showATTDialog" eventData:@{@"result":@"agree"}];
                } else {
                    [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"showATTDialog" eventData:@{@"result":@"disagree"}];
                }
                [Yodo1AdConfigHelper.instance setUmengATTDialogRunOneTimes:YES];
                    [[Yodo1Tool.shared cached]setObject:[NSNumber numberWithBool:NO] forKey:@"UmengShowATTDialogEnabled"];
            }
            #endif
            }];
        }
    }
    #ifdef YODO1_ANALYTICS
    if (Yodo1AnalyticsManager.enable) {
        [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"setCOPPA"
                                                   eventData:@{@"result":[Yodo1AdConfigHelper.instance isTagForUnderAgeOfConsent]?@"Yes":@"No"}];
        [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"setGDPR"
                                                   eventData:@{@"result":[Yodo1AdConfigHelper.instance isUserConsent]?@"Yes":@"No"}];
       [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"setCCPA"
                                                  eventData:@{@"result":[Yodo1AdConfigHelper.instance isDoNotSell]?@"No":@"Yes"}];
    }
    #endif
    //启动统计
    [Yodo1Ads startTime];
}

+ (NSDictionary*)config {
    NSBundle *bundle = [[NSBundle alloc] initWithPath:[[NSBundle mainBundle]pathForResource:@"Yodo1Ads" ofType:@"bundle"]];
    if (!bundle) {return nil;}
        NSString *configPath = [bundle pathForResource:@"config" ofType:@"plist"];
    if (!configPath.length) {return nil;}
    return [NSDictionary dictionaryWithContentsOfFile:configPath];
}

+ (NSString*)publishType {
    NSDictionary* _config = [Yodo1Ads config];
    NSString* _publishType = @"";
    if (_config && [[_config allKeys]containsObject:@"PublishType"]) {
        _publishType = (NSString*)[_config objectForKey:@"PublishType"];
    }
    return _publishType;
}

+ (NSString*)publishVersion {
    NSDictionary* _config = [Yodo1Ads config];
    NSString* _publishVersion = @"";
    if (_config && [[_config allKeys]containsObject:@"PublishVersion"]) {
        _publishVersion = (NSString*)[_config objectForKey:@"PublishVersion"];
    }
    return _publishVersion;
}

+ (NSString *)sdkVersion {
    return [self publishVersion];
}

+ (void)setLogEnable:(BOOL)enable {
    // [[Yodo1Analytics instance]setDebugMode:enable];
}

#pragma mark- OCBanner
+ (void)setBannerCallback:(Yodo1AdsEventCallback)callback {
    if (callback == nil) {
        return;
    }
    if (s_bannerCallback) {
        s_bannerCallback = nil;
    }
    s_bannerCallback = callback;
}

+ (void)setBannerOffset:(CGPoint)point {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance]setBannerOffset:point];
#endif
}

+ (void)setBannerScale:(CGFloat)sx sy:(CGFloat)sy {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance]setBannerScale:sx sy:sy];
#endif
}

+ (void)setBannerAlign:(Yodo1AdsBannerAdAlign)align {
#ifdef YODO1_ADS
    [Yodo1Ads setBannerAlign:align viewcontroller:nil];
#endif
}

+ (void)setBannerAlign:(Yodo1AdsBannerAdAlign)align
        viewcontroller:(UIViewController *)viewcontroller {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance]setBannerAlign:(BannerAlign)align
                                        viewcontroller:viewcontroller?viewcontroller:[Yodo1AdsDelegate getRootViewController]];
#endif
}

+ (BOOL)bannerIsReady {
#ifdef YODO1_ADS
    return [Yodo1BannerManager.sharedInstance bannerAdReady];
#endif
    return NO;
}

+ (void)showBanner {
#ifdef YODO1_ADS
    [self showBanner:nil];
#endif
}

+ (void)showBanner:(NSString *)placement_id {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance] showBanner:placement_id];
#endif
}

+ (void)hideBanner {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance]hideBanner];
#endif
}

+ (void)removeBanner {
#ifdef YODO1_ADS
    [[Yodo1BannerManager sharedInstance]removeBanner];
#endif
}

#pragma mark- OCInterstitial

+ (void)setInterstitialCallback:(Yodo1AdsEventCallback)callback {
    if (callback == nil) {
        return;
    }
    if (s_interstitialCallback) {
        s_interstitialCallback = nil;
    }
    s_interstitialCallback = callback;
}

+ (BOOL)interstitialIsReady {
#ifdef YODO1_ADS
    return [[Yodo1InterstitialAdManager sharedInstance]interstitialAdReady];
#else
    return NO;
#endif
}

+ (void)showInterstitial {
#ifdef YODO1_ADS
    [self showInterstitialWithPlacement:nil];
#endif
}

+ (void)showInterstitialWithPlacement:(NSString *)placement_id {
#ifdef YODO1_ADS
    [self showInterstitial:nil placement:placement_id];
#endif
}

+ (void)showInterstitial:(UIViewController*)viewcontroller {
#ifdef YODO1_ADS
    [self showInterstitial:viewcontroller placement:nil];
#endif
}

+ (void)showInterstitial:(UIViewController *)viewcontroller placement:(NSString *)placement_id {
#ifdef YODO1_ADS
    [[Yodo1InterstitialAdManager sharedInstance]showAd:viewcontroller?viewcontroller:[Yodo1AdsDelegate getRootViewController] placement:placement_id];
#endif
}


#pragma mark- OCVideo

+ (void)setVideoCallback:(Yodo1AdsEventCallback)callback {
    if (callback == nil) {
        return;
    }
    if (s_videoCallback) {
        s_videoCallback = nil;
    }
    s_videoCallback = callback;
}

+ (BOOL)videoIsReady {
#ifdef YODO1_ADS
    return [[Yodo1AdVideoManager sharedInstance]hasAdVideo];
#else
    return NO;
#endif
}

+ (void)showVideo {
#ifdef YODO1_ADS
    [self showVideoWithPlacement:nil];
#endif
}

+ (void)showVideoWithPlacement:(NSString *)placement_id {
#ifdef YODO1_ADS
    [self showVideo:nil placement:placement_id];
#endif
}

+ (void)showVideo:(UIViewController*)viewcontroller {
#ifdef YODO1_ADS
    [self showVideo:viewcontroller placement:nil];
#endif
}

+ (void)showVideo:(UIViewController *)viewcontroller placement:(NSString *)placement_id {
#ifdef YODO1_ADS
    [[Yodo1AdVideoManager sharedInstance]showAdVideo:viewcontroller?viewcontroller:[Yodo1AdsDelegate getRootViewController] placement:placement_id awardBlock:^(bool finished) {
    }];
#endif
}

+ (void)setUserConsent:(BOOL)consent {
#ifdef YODO1_ADS
    [[Yodo1AdConfigHelper instance]setUserConsent:consent];
#endif
}

+ (BOOL)isUserConsent {
#ifdef YODO1_ADS
    return [Yodo1AdConfigHelper.instance isUserConsent];
#endif
    return YES;
}

+ (void)setTagForUnderAgeOfConsent:(BOOL)isBelowConsentAge {
#ifdef YODO1_ADS
    [[Yodo1AdConfigHelper instance]setTagForUnderAgeOfConsent:isBelowConsentAge];
#endif
}

+ (BOOL)isTagForUnderAgeOfConsent {
#ifdef YODO1_ADS
    return [Yodo1AdConfigHelper.instance isTagForUnderAgeOfConsent];
#endif
    return NO;
}

+ (void)setDoNotSell:(BOOL)doNotSell {
#ifdef YODO1_ADS
    [[Yodo1AdConfigHelper instance]setDoNotSell:doNotSell];
#endif
}

+ (BOOL)isDoNotSell {
#ifdef YODO1_ADS
    return [Yodo1AdConfigHelper.instance isDoNotSell];
#endif
    return NO;
}

#pragma mark- OCRewardGame

+ (BOOL)rewardGameIsEnable {
#ifdef YODO1_ADS
    return [Yodo1AdConfigHelper.instance isRewardGameEnable];
#endif
    return NO;
}

//Show Reward Game
+ (void)showRewardGame:(Yodo1RewardGameCallback)reward {
    
#ifdef YODO1_ANALYTICS
    [Yodo1AnalyticsManager.sharedInstance eventAnalytics:@"RewardGameShow" eventData:@{}];
#endif
    
#ifdef YODO1_ADS
    if (![self rewardGameIsEnable]) {
        NSError * error = [NSError errorWithDomain:@"com.yodo1.rewardgame" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"Reward game is disabled."}];
        reward(nil,error);
        return;
    }
    UIViewController * vc = [Yodo1AdsDelegate getRootViewController];
    [Yodo1RewardGameViewController presentRewardGame:vc reward:reward];
#endif
}

#pragma mark- OCSplash

+ (void)setSplashCallback:(Yodo1AdsEventCallback)callback {
    if (callback == nil) {
        return;
    }
    if (s_splashCallback) {
        s_splashCallback = nil;
    }
    s_splashCallback = callback;
}

+ (void)showSplash:(UIWindow *)window {
#ifdef YODO1_ADS
    [self showSplash:window placement:nil];
#endif
}

+ (void)showSplash:(UIWindow *)window placement:(NSString *)placement_id {
#ifdef YODO1_ADS
    [[Yodo1SplashManager sharedInstance] showSplash:window placement:placement_id];
#endif
}

@end


#pragma mark- ///Unity3d

#ifdef __cplusplus

extern "C" {

void Unity3dInitWithAppKey(const char *appKey,const char* gameObject)
{
    NSString* m_appKey = Yodo1CreateNSString(appKey);
    NSCAssert(m_appKey != nil, @"AppKey 没有设置!");
    
    NSString* m_gameObject = Yodo1CreateNSString(gameObject);
    if (m_gameObject) {
        kYodo1AdsGameObject = m_gameObject;
    }
    NSCAssert(m_gameObject != nil, @"Unity3d gameObject isn't set!");
    
    [Yodo1Ads initWithAppKey:m_appKey];
}

void Unity3dSetLogEnable(BOOL enable)
{
    [Yodo1Ads setLogEnable:enable];
}

#pragma mark - Unity3dBanner

void Unity3dSetBannerAlign(Yodo1AdsCBannerAdAlign align)
{
    [Yodo1Ads setBannerAlign:(Yodo1AdsBannerAdAlign)align];
}

void Unity3dSetBannerOffset(float x,float y)
{
    [Yodo1Ads setBannerOffset:CGPointMake(x,y)];
}

void Unity3dSetBannerScale(float sx,float sy)
{
    [Yodo1Ads setBannerScale:sx sy:sy];
}

bool Unity3dBannerIsReady()
{
    return [Yodo1Ads bannerIsReady];
}

void UnityShowBanner()
{
    [Yodo1Ads showBanner];
}

void UnityShowBannerWithPlacement(const char* placement_id) {
    [Yodo1Ads showBanner:Yodo1CreateNSString(placement_id)];
}

void Unity3dHideBanner()
{
    [Yodo1Ads hideBanner];
}

void Unity3dRemoveBanner()
{
    [Yodo1Ads removeBanner];
}

#pragma mark - Unity3dInterstitial

bool Unity3dInterstitialIsReady()
{
    return [Yodo1Ads interstitialIsReady];
    
}

void Unity3dShowInterstitial()
{
    [Yodo1Ads showInterstitial];
}

void Unity3dShowInterstitialWithPlacement(const char* placement_id)
{
    [Yodo1Ads showInterstitialWithPlacement:Yodo1CreateNSString(placement_id)];
}

#pragma mark - Unity3dVideo

bool Unity3dVideoIsReady()
{
    return [Yodo1Ads videoIsReady];
}

void Unity3dShowVideo()
{
    [Yodo1Ads showVideo];
}

void Unity3dShowVideoWithPlacement(const char* placement_id)
{
    [Yodo1Ads showVideoWithPlacement:Yodo1CreateNSString(placement_id)];
}

#pragma mark - Privacy

void Unity3dSetUserConsent(BOOL consent)
{
    [Yodo1Ads setUserConsent:consent];
}

bool Unity3dIsUserConsent()
{
    return [Yodo1Ads isUserConsent];
}

void Unity3dSetTagForUnderAgeOfConsent(BOOL isBelowConsentAge)
{
    [Yodo1Ads setTagForUnderAgeOfConsent:isBelowConsentAge];
}

bool Unity3dIsTagForUnderAgeOfConsent()
{
    return [Yodo1Ads isTagForUnderAgeOfConsent];
}

void Unity3dSetDoNotSell(BOOL doNotSell)
{
    [Yodo1Ads setDoNotSell:doNotSell];
}

bool Unity3dIsDoNotSell()
{
    return [Yodo1Ads isDoNotSell];
}

#pragma mark - Unity3dRewardGame

bool Unity3dRewardGameIsEnable()
{
    return [Yodo1Ads rewardGameIsEnable];
}

void Unity3dShowRewardGame()
{
    [Yodo1Ads showRewardGame:^(NSString *reward, NSError *error) {
        if (!kYodo1AdsGameObject) {return;}
        if (error) {
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            [dict setObject:[NSNumber numberWithInt:Yodo1AdsTypeRewardGame] forKey:@"resulType"];
            NSError* parseJSONError = nil;
            NSString* msg = [Yodo1AdsDelegate stringWithJSONObject:dict error:&parseJSONError];
            NSString* jsonError = @"";
            if(parseJSONError){
                jsonError = @"Convert result to json failed!";
            }
            NSString* des = [error localizedDescription];
            jsonError = [NSString stringWithFormat:@"%@,errorMsg:%@",jsonError,des];
            [dict setObject:jsonError forKey:@"error"];
            msg =  [Yodo1AdsDelegate stringWithJSONObject:dict error:&parseJSONError];
            UnitySendMessage([kYodo1AdsGameObject cStringUsingEncoding:NSUTF8StringEncoding],UNITY3D_YODO1ADS_METHOD,
                             [msg cStringUsingEncoding:NSUTF8StringEncoding] );
        }else{
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            dict[@"resulType"] = @(Yodo1AdsTypeRewardGame);
            dict[@"reward"] = reward;
            NSError* parseJSONError = nil;
            NSString* msg = [Yodo1AdsDelegate stringWithJSONObject:dict error:&parseJSONError];
            UnitySendMessage([kYodo1AdsGameObject cStringUsingEncoding:NSUTF8StringEncoding],UNITY3D_YODO1ADS_METHOD,
            [msg cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }];
}

#pragma mark - Unity3dSplash

void UnityShowSplashAd()
{

#ifdef YODO1_ADS
    [[Yodo1SplashManager sharedInstance] showSplash:nil placement:nil];
#endif
}

void UnityShowSplashAdWithPlacement(const char* placement_id)
{
#ifdef YODO1_ADS
    [[Yodo1SplashManager sharedInstance] showSplash:nil placement:Yodo1CreateNSString(placement_id)];
#endif
}

}
#endif


#pragma mark- ///C++实现

void Yodo1AdsC::InitWithAppKey(const char *appKey)
{
    NSString* m_appKey = Yodo1CreateNSString(appKey);
    NSCAssert(m_appKey !=nil, @"appKey is null");
    [Yodo1Ads initWithAppKey:m_appKey];
}

void Yodo1AdsC::SetLogEnable(bool enable)
{
    [Yodo1Ads setLogEnable:enable];
}

#pragma mark - C++Banner

void Yodo1AdsC::SetBannerCallback(Yodo1AdsEvent_Callback callback)
{
    if(callback == NULL){
        NSLog(@"Banner callback is null");
        return;
    }
    s_banner_callback = callback;
}

void Yodo1AdsC::SetBannerAlign(Yodo1AdsCBannerAdAlign align)
{
    [Yodo1Ads setBannerAlign:(Yodo1AdsBannerAdAlign)align];
}

void Yodo1AdsC::SetBannerOffset(float x, float y)
{
    [Yodo1Ads setBannerOffset:CGPointMake(x, y)];
}

void Yodo1AdsC::SetBannerScale(float sx,float sy)
{
    [Yodo1Ads setBannerScale:sx sy:sy];
}

bool Yodo1AdsC::BannerIsReady()
{
    return [Yodo1Ads bannerIsReady];
}

void Yodo1AdsC::ShowBanner()
{
    [Yodo1Ads showBanner];
}

void Yodo1AdsC::ShowBannerWithPlacement(const char* placement_id)
{
    [Yodo1Ads showBanner:Yodo1CreateNSString(placement_id)];
}

void Yodo1AdsC::HideBanner()
{
    [Yodo1Ads hideBanner];
}

void Yodo1AdsC::RemoveBanner()
{
    [Yodo1Ads removeBanner];
}

#pragma mark - C++Interstitial

void Yodo1AdsC::SetInterstitialCallback(Yodo1AdsEvent_Callback callback)
{
    if(callback == NULL){
        NSLog(@"interstitial callback is null");
        return;
    }
    s_interstitial_callback = callback;
}


bool Yodo1AdsC::InterstitialIsReady()
{
    return [Yodo1Ads interstitialIsReady];
}


void Yodo1AdsC:: ShowInterstitial()
{
    [Yodo1Ads showInterstitial];
}

void Yodo1AdsC:: ShowInterstitialWithPlacement(const char *placement_id)
{
    [Yodo1Ads showInterstitialWithPlacement:Yodo1CreateNSString(placement_id)];
}

#pragma mark - C++Video

void Yodo1AdsC::SetVideoCallback(Yodo1AdsEvent_Callback callback)
{
    if (callback == NULL) {
        NSLog(@"video callback is null");
    }
    s_video_callback = callback;
}

bool Yodo1AdsC::VideoIsReady()
{
    return [Yodo1Ads videoIsReady];
}

void Yodo1AdsC::ShowVideo()
{
    [Yodo1Ads showVideo];
}

void Yodo1AdsC:: ShowVideoWithPlacement(const char *placement_id)
{
    [Yodo1Ads showVideoWithPlacement:Yodo1CreateNSString(placement_id)];
}

void Yodo1AdsC::SetUserConsent(BOOL consent)
{
    [Yodo1Ads setUserConsent:consent];
}

bool Yodo1AdsC::IsUserConsent()
{
    return [Yodo1Ads isUserConsent];
}

void Yodo1AdsC::SetTagForUnderAgeOfConsent(BOOL isBelowConsentAge)
{
    [Yodo1Ads setTagForUnderAgeOfConsent:isBelowConsentAge];
}

bool Yodo1AdsC::IsTagForUnderAgeOfConsent()
{
    return [Yodo1Ads isTagForUnderAgeOfConsent];
}

void Yodo1AdsC::SetDoNotSell(BOOL doNotSell)
{
    [Yodo1Ads setDoNotSell:doNotSell];
}

bool Yodo1AdsC::IsDoNotSell()
{
    return [Yodo1Ads isDoNotSell];
}

#pragma mark - C++RewardGame

bool Yodo1AdsC::RewardGameIsEnable()
{
    return [Yodo1Ads rewardGameIsEnable];
}

void Yodo1AdsC::ShowRewardGame(Yodo1RewardGame_Callback callback)
{
    if(callback == NULL){
        NSLog(@"Reward game callback is null");
        return;
    }
    [Yodo1Ads showRewardGame:^(NSString *reward, NSError *error) {
        if (error) {
            Yodo1AdsCError* errorC = new Yodo1AdsCError();
            errorC->errorCode = (int)[error code];
            NSString* des = [error localizedDescription];
            errorC->errorDescription = des?des.UTF8String:"";
            callback(NULL,errorC);
        }else{
            callback(reward.UTF8String,NULL);
        }
    }];
}

#pragma mark - C++Splash

void Yodo1AdsC::SetSplashCallback(Yodo1AdsEvent_Callback callback)
{
    if (callback == NULL) {
        NSLog(@"splash callback is null");
    }
    s_splash_callback = callback;
}

void Yodo1AdsC::ShowSplash()
{
    [Yodo1Ads showSplash:nil];
}

void Yodo1AdsC::ShowSplashWithPlacement(const char* placement_id)
{
    [Yodo1Ads showSplash:nil placement:Yodo1CreateNSString(placement_id)];
}
