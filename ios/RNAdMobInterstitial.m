#import "RNAdMobInterstitial.h"
#import <React/RCTConvert.h>
#import <CoreLocation/CoreLocation.h>

#if __has_include(<React/RCTUtils.h>)
#import <React/RCTUtils.h>
#else
#import "RCTUtils.h"
#endif

static NSString *const kEventAdLoaded = @"interstitialAdLoaded";
static NSString *const kEventAdFailedToLoad = @"interstitialAdFailedToLoad";
static NSString *const kEventAdOpened = @"interstitialAdOpened";
static NSString *const kEventAdFailedToOpen = @"interstitialAdFailedToOpen";
static NSString *const kEventAdClosed = @"interstitialAdClosed";
static NSString *const kEventAdLeftApplication = @"interstitialAdLeftApplication";

@implementation RNAdMobInterstitial
{
    GADInterstitial  *_interstitial;
    NSString *_adUnitID;
    NSString *_testDeviceID;
    NSArray *_testDevices;
    RCTPromiseResolveBlock _requestAdResolve;
    RCTPromiseRejectBlock _requestAdReject;
    BOOL hasListeners;
    NSString *_contentUrl;
    NSCalendar *_birthday;
    GADGender *_gender;
    CLLocation *_location;
    BOOL _childDirected;
    RCTResponseSenderBlock _requestAdCallback;
    RCTResponseSenderBlock _showAdCallback;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
    return @[
             kEventAdLoaded,
             kEventAdFailedToLoad,
             kEventAdOpened,
             kEventAdFailedToOpen,
             kEventAdClosed,
             kEventAdLeftApplication ];
}

#pragma mark exported methods

RCT_EXPORT_METHOD(setAdUnitID:(NSString *)adUnitID)
{
    _adUnitID = adUnitID;
}

RCT_EXPORT_METHOD(setTestDevices:(NSArray *)testDevices)
{
    _testDevices = testDevices;
}

RCT_EXPORT_METHOD(setChildDirected:(BOOL *)childDirected)
{
  _childDirected = childDirected;
}

RCT_EXPORT_METHOD(setContentUrl:(NSString *)contentUrl)
{
  _contentUrl = contentUrl;
}

RCT_EXPORT_METHOD(setGender:(NSString *)gender)
{
  if ([gender isEqualToString:@"male"]) {
    _gender = kGADGenderMale;
  } else {
    _gender = kGADGenderFemale;
  }
}

RCT_EXPORT_METHOD(setLocation:(NSDictionary *)coordinates)
{
  if (coordinates[@"lat"] && coordinates[@"long"]) {
    _location = [[CLLocation alloc]
                 initWithLatitude:[RCTConvert double:coordinates[@"lat"]]
                 longitude:[RCTConvert double:coordinates[@"long"]]];
  }
}

RCT_EXPORT_METHOD(setBirthday:(NSDictionary *)birthday)
{
  if (birthday[@"month"] && birthday[@"day"] && birthday[@"year"]) {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.month = [RCTConvert NSInteger:birthday[@"month"]];
    components.day = [RCTConvert NSInteger:birthday[@"day"]];
    components.year = [RCTConvert NSInteger:birthday[@"year"]];
    _birthday = [[NSCalendar currentCalendar] dateFromComponents:components];
  }
}

RCT_EXPORT_METHOD(requestAd:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    _requestAdResolve = nil;
    _requestAdReject = nil;

    if ([_interstitial hasBeenUsed] || _interstitial == nil) {
        _requestAdResolve = resolve;
        _requestAdReject = reject;

        _interstitial = [[GADInterstitial alloc] initWithAdUnitID:_adUnitID];
        _interstitial.delegate = self;

        GADRequest *request = [self getRequestWithTargeting];
        request.testDevices = _testDevices;
        [_interstitial loadRequest:request];
    } else {
        reject(@"E_AD_ALREADY_LOADED", @"Ad is already loaded.", nil);
    }
}


RCT_EXPORT_METHOD(showAd:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    if ([_interstitial isReady]) {
        [_interstitial presentFromRootViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
        resolve(nil);
    }
    else {
        reject(@"E_AD_NOT_READY", @"Ad is not ready.", nil);
    }
}

RCT_EXPORT_METHOD(isReady:(RCTResponseSenderBlock)callback)
{
    callback(@[[NSNumber numberWithBool:[_interstitial isReady]]]);
}

- (NSDictionary<NSString *,id> *)constantsToExport
{
    return @{
             @"simulatorId": kGADSimulatorID
             };
}

- (void)startObserving
{
    hasListeners = YES;
}

- (GADRequest *)getRequestWithTargeting {
  GADRequest *request = [GADRequest request];
  if (_gender) {
    request.gender = _gender;
  }
  if (_birthday) {
    request.birthday = _birthday;
  }
  if (_location) {
    [request setLocationWithLatitude:_location.coordinate.latitude
                           longitude:_location.coordinate.longitude
                            accuracy:_location.horizontalAccuracy];
  }
  if (_childDirected) {
    [request tagForChildDirectedTreatment:YES];
  }
  if (_contentUrl) {
    request.contentURL = _contentUrl;
  }
  if (_testDeviceID) {
    if ([_testDeviceID isEqualToString:@"EMULATOR"]) {
      request.testDevices = @[kGADSimulatorID];
    } else {
      request.testDevices = @[_testDeviceID];
    }
  }
  return request;
}

- (void)stopObserving
{
    hasListeners = NO;
}

#pragma mark GADInterstitialDelegate

- (void)interstitialDidReceiveAd:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdLoaded body:nil];
    }
    _requestAdResolve(nil);
}

- (void)interstitial:(__unused GADInterstitial *)interstitial didFailToReceiveAdWithError:(GADRequestError *)error
{
    if (hasListeners) {
        NSDictionary *jsError = RCTJSErrorFromCodeMessageAndNSError(@"E_AD_REQUEST_FAILED", error.localizedDescription, error);
        [self sendEventWithName:kEventAdFailedToLoad body:jsError];
    }
    _requestAdReject(@"E_AD_REQUEST_FAILED", error.localizedDescription, error);
}

- (void)interstitialWillPresentScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners){
        [self sendEventWithName:kEventAdOpened body:nil];
    }
}

- (void)interstitialDidFailToPresentScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners){
        [self sendEventWithName:kEventAdFailedToOpen body:nil];
    }
}

- (void)interstitialWillDismissScreen:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdClosed body:nil];
    }
}

- (void)interstitialWillLeaveApplication:(__unused GADInterstitial *)ad
{
    if (hasListeners) {
        [self sendEventWithName:kEventAdLeftApplication body:nil];
    }
}

@end
