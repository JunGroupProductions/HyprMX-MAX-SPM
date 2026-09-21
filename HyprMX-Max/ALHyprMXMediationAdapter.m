//
//  ALHyprMXMediationAdapter.m
//

#import "HyprMX_Max.h"
#import <HyprMX/HyprMX.h>

#define ADAPTER_VERSION @"6.4.7.0"

/**
 * Dedicated delegate object for HyprMX initialization.
 */
@interface ALHyprMXMediationAdapterInitializationDelegate : NSObject
@property (nonatomic, weak) HyprMXAdapter *parentAdapter;
@property (nonatomic, copy, nullable) void(^completionBlock)(MAAdapterInitializationStatus, NSString *_Nullable);
- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler;
- (void)initializationDidComplete;
- (void)initializationFailed;
@end

/**
 * Dedicated delegate object for HyprMX AdView ads.
 */
@interface ALHyprMXMediationAdapterAdViewDelegate : NSObject <HyprMXBannerDelegate>
@property (nonatomic,   weak) HyprMXAdapter *parentAdapter;
@property (nonatomic, strong) id<MAAdViewAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate;
- (instancetype)init NS_UNAVAILABLE;
@end

/**
 * Dedicated delegate object for HyprMX interstitial ads.
 */
@interface ALHyprMXMediationAdapterInterstitialAdDelegate : NSObject <HyprMXPlacementShowDelegate>
@property (nonatomic,   weak) HyprMXAdapter *parentAdapter;
@property (nonatomic, strong) id<MAInterstitialAdapterDelegate> delegate;
- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate;
- (instancetype)init NS_UNAVAILABLE;
- (void)adAvailableForPlacement:(HyprMXPlacement *)placement;
- (void)adNotAvailableForPlacement:(HyprMXPlacement *)placement;
@end

/**
 * Dedicated delegate object for HyprMX rewarded ads.
 */
@interface ALHyprMXMediationAdapterRewardedAdDelegate : NSObject <HyprMXPlacementShowDelegate>
@property (nonatomic,   weak) HyprMXAdapter *parentAdapter;
@property (nonatomic, strong) id<MARewardedAdapterDelegate> delegate;
@property (nonatomic, assign, getter=hasGrantedReward) BOOL grantedReward;
- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate;
- (instancetype)init NS_UNAVAILABLE;
- (void)adAvailableForPlacement:(HyprMXPlacement *)placement;
- (void)adNotAvailableForPlacement:(HyprMXPlacement *)placement;
@end

@interface HyprMXAdapter ()

// Initialization
@property (nonatomic, strong) ALHyprMXMediationAdapterInitializationDelegate *initializationDelegate;

// AdView
@property (nonatomic, strong) HyprMXBannerView *adView;
@property (nonatomic, strong) ALHyprMXMediationAdapterAdViewDelegate *adViewDelegate;

// Interstitial
@property (nonatomic, strong) HyprMXPlacement *interstitialAd;
@property (nonatomic, strong) ALHyprMXMediationAdapterInterstitialAdDelegate *interstitialAdDelegate;

// Rewarded
@property (nonatomic, strong) HyprMXPlacement *rewardedAd;
@property (nonatomic, strong) ALHyprMXMediationAdapterRewardedAdDelegate *rewardedAdDelegate;

@end

@implementation HyprMXAdapter

static NSString *const kHyprMXMediator = @"applovin_max_custom";
static NSString *const kHyprMXTestDistributorId = @"1000201300";
static NSString *const kHyprMXTestRewardedPlacementName = @"Rewarded_POS1";
static NSString *const kHyprMXTestInterstitialPlacementName = @"Interstitial_POS1";
static NSString *const kHyprMXTestBannerPlacementName = @"Test_iOS_320x50";

static BOOL testModeEnabled = NO;

#pragma mark - MAAdapter Methods

- (NSString *)SDKVersion
{
    return [HyprMX versionString];
}

- (NSString *)adapterVersion
{
    return ADAPTER_VERSION;
}

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler
{
    if ( [HyprMX initializationStatus] == NOT_INITIALIZED )
    {
        NSString *distributorId;
        if (testModeEnabled) {
            distributorId = kHyprMXTestDistributorId;
            [HyprMX setLogLevel: HYPRLogLevelDebug];
            [self log: @"Test mode is enabled. Replacing distributorId with test one %@", distributorId];
        } else {
            distributorId = [parameters.serverParameters al_stringForKey: @"app_id"];
        }
        
        [self log: @"Initializing HyprMX SDK with distributor id: %@", distributorId];
        
        self.initializationDelegate = [[ALHyprMXMediationAdapterInitializationDelegate alloc] initWithParentAdapter: self completionHandler: completionHandler];
        
        [HyprMX setMediationProvider: kHyprMXMediator
                  mediatorSDKVersion: ALSdk.version
                      adapterVersion: self.adapterVersion];
        
        // NOTE: HyprMX deals with CCPA via their UI
        [HyprMX setConsentStatus:[self consentStatusWithParameters: parameters]];
        [HyprMX initWithDistributorId:distributorId completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [self.initializationDelegate initializationDidComplete];
            } else {
                [self.initializationDelegate initializationFailed];
            }
        }];
    }
    else
    {
        if ( [HyprMX initializationStatus] == INITIALIZATION_COMPLETE )
        {
            completionHandler(MAAdapterInitializationStatusInitializedSuccess, nil);
        }
        else if ( [HyprMX initializationStatus] == INITIALIZATION_FAILED )
        {
            completionHandler(MAAdapterInitializationStatusInitializedFailure, nil);
        }
        else if ( [HyprMX initializationStatus] == INITIALIZING )
        {
            completionHandler(MAAdapterInitializationStatusInitializing, nil);
        }
        else
        {
            completionHandler(MAAdapterInitializationStatusInitializedUnknown, nil);
        }
    }
}

// Destroy tears down a HyprMXBannerView (a UIView), so it must run on the main thread. (MAX 13.0.2+ honors this; older SDKs never call it.)
- (nullable NSNumber *)shouldDestroyOnMainThread
{
    return @1;
}

- (void)destroy
{
    self.initializationDelegate = nil;
    
    self.adView.placementDelegate = nil;
    self.adView = nil;
    self.adViewDelegate.delegate = nil;
    self.adViewDelegate = nil;
    
    self.interstitialAd = nil;
    self.interstitialAdDelegate.delegate = nil;
    self.interstitialAdDelegate = nil;
    
    self.rewardedAd = nil;
    self.rewardedAdDelegate.delegate = nil;
    self.rewardedAdDelegate = nil;
}

+ (void)enableTestMode {
    testModeEnabled = YES;
}

#pragma mark - Signal Collection

- (void)collectSignalWithParameters:(id<MASignalCollectionParameters>)parameters andNotify:(id<MASignalCollectionDelegate>)delegate
{
    [self log: @"Collecting signal..."];
    
    [self updateConsentWithParameters: parameters];
    
    NSString *signal = [HyprMX sessionToken];
    [delegate didCollectSignal: signal];
}

#pragma mark - AdView Adapter

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters adFormat:(MAAdFormat *)adFormat andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    NSString *placementId = testModeEnabled ? kHyprMXTestBannerPlacementName : parameters.thirdPartyAdPlacementIdentifier;
    [self log: @"Loading %@ AdView ad for placement: %@...", adFormat.label, placementId];
    
    [self updateConsentWithParameters: parameters];
    
    self.adViewDelegate = [[ALHyprMXMediationAdapterAdViewDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    self.adView = [[HyprMXBannerView alloc] initWithPlacementName: placementId adSize: [self adSizeForAdFormat: adFormat]];
    self.adView.placementDelegate = self.adViewDelegate;
    
    [self.adView loadAdWithCompletion:^(BOOL success) {
        if (success) {
            [delegate didLoadAdForAdView: self.adView];
        } else {
            [delegate didFailToLoadAdViewAdWithError:MAAdapterError.noFill];
        }
    }];
}

#pragma mark - Interstitial Adapter

- (void)loadInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    NSString *placementId = testModeEnabled ? kHyprMXTestInterstitialPlacementName : parameters.thirdPartyAdPlacementIdentifier;
    [self log: @"Loading interstitial ad for placement: %@", placementId];
    
    [self updateConsentWithParameters: parameters];
    
    self.interstitialAdDelegate = [[ALHyprMXMediationAdapterInterstitialAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    self.interstitialAd = [self loadFullscreenAdForPlacementId: placementId
                                                    parameters: parameters
                                                     andNotify: self.interstitialAdDelegate];
}

- (void)showInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    [self log: @"Showing interstitial ad..."];
    
    if ( [self.interstitialAd isAdAvailable] )
    {
        UIViewController *presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];

        [self.interstitialAd showAdFromViewController:presentingViewController delegate:self.interstitialAdDelegate];
    }
    else
    {
        [self log: @"Interstitial ad not ready"];

        [delegate didFailToDisplayInterstitialAdWithError: [MAAdapterError errorWithAdapterError: MAAdapterError.adDisplayFailedError
                                                                        mediatedNetworkErrorCode: 0
                                                                     mediatedNetworkErrorMessage: @"Interstitial ad not ready"]];
    }
}

#pragma mark - Rewarded Adapter

- (void)loadRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    NSString *placementId = testModeEnabled ? kHyprMXTestRewardedPlacementName : parameters.thirdPartyAdPlacementIdentifier;
    [self log: @"Loading rewarded ad for placement: %@", placementId];
    
    [self updateConsentWithParameters: parameters];
    
    self.rewardedAdDelegate = [[ALHyprMXMediationAdapterRewardedAdDelegate alloc] initWithParentAdapter: self andNotify: delegate];
    self.rewardedAd = [self loadFullscreenAdForPlacementId: placementId
                                                parameters: parameters
                                                 andNotify: self.rewardedAdDelegate];
}

- (void)showRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    [self log: @"Showing rewarded ad..."];
    
    if ( [self.rewardedAd isAdAvailable] )
    {
        // Configure reward from server.
        [self configureRewardForParameters: parameters];

        UIViewController *presentingViewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];

        [self.rewardedAd showAdFromViewController:presentingViewController delegate:self.rewardedAdDelegate];
    }
    else
    {
        [self log: @"Rewarded ad not ready"];

        [delegate didFailToDisplayRewardedAdWithError: [MAAdapterError errorWithAdapterError: MAAdapterError.adDisplayFailedError
                                                                    mediatedNetworkErrorCode: 0
                                                                 mediatedNetworkErrorMessage: @"Rewarded ad not ready"]];
    }
}

#pragma mark - Shared Methods

- (HyprConsentStatus)consentStatusWithParameters:(id<MAAdapterParameters>)parameters
{
    NSNumber *hasUserConsent = parameters.hasUserConsent;
    NSNumber *isDoNotSell = parameters.isDoNotSell;
    
    // isTrue/isFalse/isNil to match the spec from HyprMX
    if ( ( [self isNil: isDoNotSell] || [self isFalse: isDoNotSell] ) && [self isTrue: hasUserConsent] )
    {
        return CONSENT_GIVEN;
    }
    else if ( [self isTrue: isDoNotSell] || [self isFalse: hasUserConsent] )
    {
        return CONSENT_DECLINED;
    }
    else
    {
        return CONSENT_STATUS_UNKNOWN;
    }
}

- (BOOL)isTrue:(nullable NSNumber *)privacyConsent
{
    return privacyConsent && privacyConsent.boolValue;
}

- (BOOL)isFalse:(nullable NSNumber *)privacyConsent
{
    return privacyConsent && !privacyConsent.boolValue;
}

- (BOOL)isNil:(nullable NSNumber *)privacyConsent
{
    return privacyConsent == nil;
}

- (void)updateConsentWithParameters:(id<MAAdapterParameters>)parameters
{
    // NOTE: HyprMX requested to always set GDPR regardless of region.
    [HyprMX setConsentStatus: [self consentStatusWithParameters: parameters]];
}

#pragma mark - Helper Methods

- (HyprMXPlacement *)loadFullscreenAdForPlacementId:(NSString *)placementId parameters:(id<MAAdapterResponseParameters>)parameters andNotify:(ALHyprMXMediationAdapterInterstitialAdDelegate *)delegate
{
    HyprMXPlacement *fullScreenPlacement = [HyprMX getPlacement: placementId];
    
    NSString *bidResponse = parameters.bidResponse;
    if ( [bidResponse al_isValidString] )
    {
        [fullScreenPlacement loadAdWithBidResponse: bidResponse completion:^(BOOL success) {
            if (success) {
                [delegate adAvailableForPlacement:fullScreenPlacement];
            } else {
                [delegate adNotAvailableForPlacement:fullScreenPlacement];
            }
        }];
    }
    else
    {
        [fullScreenPlacement loadAdWithCompletion:^(BOOL success) {
            if (success) {
                [delegate adAvailableForPlacement:fullScreenPlacement];
            } else {
                [delegate adNotAvailableForPlacement:fullScreenPlacement];
            }
        }];
    }
    
    return fullScreenPlacement;
}

- (CGSize)adSizeForAdFormat:(MAAdFormat *)adFormat
{
    if ( adFormat == MAAdFormat.banner )
    {
        return kHyprMXAdSizeBanner;
    }
    else if ( adFormat == MAAdFormat.mrec )
    {
        return kHyprMXAdSizeMediumRectangle;
    }
    else if ( adFormat == MAAdFormat.leader )
    {
        return kHyprMXAdSizeLeaderBoard;
    }
    else
    {
        [NSException raise: NSInvalidArgumentException format: @"Unsupported ad format: %@", adFormat];
        return kHyprMXAdSizeBanner;
    }
}

+ (MAAdapterError *)toMaxError:(NSError *)hyprMXError
{
    return [self toMaxError: hyprMXError.code message: nil];
}

+ (MAAdapterError *)toMaxError:(NSInteger)hyprMXErrorCode message:(nullable NSString *)hyprMXMessage
{
    MAAdapterError *adapterError = MAAdapterError.unspecified;
    
    if ( [HyprMX initializationStatus] != INITIALIZATION_COMPLETE )
    {
        return MAAdapterError.notInitialized;
    }
    
    switch ( hyprMXErrorCode )
    {
        case NO_FILL:
            adapterError = MAAdapterError.noFill;
            break;
        case DISPLAY_ERROR:
            adapterError = MAAdapterError.internalError;
            break;
        case PLACEMENT_DOES_NOT_EXIST:
        case AD_SIZE_NOT_SET:
        case PLACEMENT_NAME_NOT_SET:
            adapterError = MAAdapterError.invalidConfiguration;
            break;
        case SDK_NOT_INITIALIZED:
            adapterError = MAAdapterError.notInitialized;
            break;
    }
    
    return [MAAdapterError errorWithAdapterError: adapterError
                        mediatedNetworkErrorCode: hyprMXErrorCode
                     mediatedNetworkErrorMessage: hyprMXMessage ?: @""];
}

@end

@implementation ALHyprMXMediationAdapterInitializationDelegate

- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler;
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.completionBlock = completionHandler;
    }
    return self;
}

- (void)initializationDidComplete
{
    [self.parentAdapter log: @"HyprMX SDK Initialized"];
    
    if ( self.completionBlock )
    {
        self.completionBlock(MAAdapterInitializationStatusInitializedSuccess, nil);
        self.completionBlock = nil;
        
        self.parentAdapter.initializationDelegate = nil;
    }
}

- (void)initializationFailed
{
    [self.parentAdapter log: @"HyprMX SDK failed to initialize"];
    
    if ( self.completionBlock )
    {
        self.completionBlock(MAAdapterInitializationStatusInitializedFailure, nil);
        self.completionBlock = nil;
        
        self.parentAdapter.initializationDelegate = nil;
    }
}

@end

@implementation ALHyprMXMediationAdapterAdViewDelegate

- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MAAdViewAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)adDidLoad:(HyprMXBannerView *)bannerView
{
    [self.parentAdapter log: @"AdView loaded"];
    [self.delegate didLoadAdForAdView: bannerView];
    [self.delegate didDisplayAdViewAd];
}

- (void)adFailedToLoad:(HyprMXBannerView *)bannerView error:(NSError *)error
{
    [self.parentAdapter log: @"AdView failed to load with error: %@", error];
    
    MAAdapterError *adapterError = [HyprMXAdapter toMaxError: error];
    [self.delegate didFailToLoadAdViewAdWithError: adapterError];
}

- (void)adWasClicked:(HyprMXBannerView *)bannerView
{
    [self.parentAdapter log: @"AdView clicked"];
    [self.delegate didClickAdViewAd];
}

- (void)adDidOpen:(HyprMXBannerView *)bannerView
{
    [self.parentAdapter log: @"AdView expanded"]; // Pretty much StoreKit presented
    [self.delegate didExpandAdViewAd];
}

- (void)adDidClose:(HyprMXBannerView *)bannerView
{
    [self.parentAdapter log: @"AdView collapse"]; // Pretty much StoreKit dismissed
    [self.delegate didCollapseAdViewAd];
}

@end

@implementation ALHyprMXMediationAdapterInterstitialAdDelegate

- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MAInterstitialAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)adAvailableForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Interstitial ad loaded: %@", placement.placementName];
    [self.delegate didLoadInterstitialAd];
}

- (void)adNotAvailableForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Interstitial failed to load: %@", placement.placementName];
    
    MAAdapterError *adapterError = [HyprMXAdapter toMaxError: NO_FILL message: nil];
    [self.delegate didFailToLoadInterstitialAdWithError: adapterError];
}

- (void)adExpiredForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Interstitial expired: %@", placement.placementName];
}

- (void)adWillStartForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Interstitial did show: %@", placement.placementName];
    [self.delegate didDisplayInterstitialAd];
}

- (void)adDidCloseForPlacement:(HyprMXPlacement *)placement didFinishAd:(BOOL)finished
{
    [self.parentAdapter log: @"Interstitial ad hidden with finished state: %d for placement: %@", finished, placement.placementName];
    [self.delegate didHideInterstitialAd];
}

- (void)adDisplayError:(NSError *)error placement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Interstitial failed to display with error: %@ for placement: %@", error.localizedDescription, placement.placementName];

    MAAdapterError *adapterError = [MAAdapterError errorWithAdapterError: MAAdapterError.adDisplayFailedError
                                                mediatedNetworkErrorCode: error.code
                                             mediatedNetworkErrorMessage: error.localizedDescription];

    [self.delegate didFailToDisplayInterstitialAdWithError: adapterError];
}

@end

@implementation ALHyprMXMediationAdapterRewardedAdDelegate

- (instancetype)initWithParentAdapter:(HyprMXAdapter *)parentAdapter andNotify:(id<MARewardedAdapterDelegate>)delegate
{
    self = [super init];
    if ( self )
    {
        self.parentAdapter = parentAdapter;
        self.delegate = delegate;
    }
    return self;
}

- (void)adAvailableForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Rewarded ad loaded: %@", placement.placementName];
    [self.delegate didLoadRewardedAd];
}

- (void)adNotAvailableForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Rewarded ad failed to load: %@", placement.placementName];
    
    MAAdapterError *adapterError = [HyprMXAdapter toMaxError: NO_FILL message: nil];
    [self.delegate didFailToLoadRewardedAdWithError: adapterError];
}

- (void)adExpiredForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Rewarded ad expired: %@", placement.placementName];
}

- (void)adWillStartForPlacement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Rewarded ad did show: %@", placement.placementName];
}

- (void)adImpression:(HyprMXPlacement *)placement
{
    [self.delegate didDisplayRewardedAd];
}

- (void)adDidCloseForPlacement:(HyprMXPlacement *)placement didFinishAd:(BOOL)finished
{
    if ( [self hasGrantedReward] || [self.parentAdapter shouldAlwaysRewardUser] )
    {
        MAReward *reward = [self.parentAdapter reward];
        [self.parentAdapter log: @"Rewarded user with reward: %@", reward];
        [self.delegate didRewardUserWithReward: reward];
    }
    
    [self.parentAdapter log: @"Rewarded ad hidden with finished state: %d for placement: %@", finished, placement.placementName];
    [self.delegate didHideRewardedAd];
}

- (void)adDisplayError:(NSError *)error placement:(HyprMXPlacement *)placement
{
    [self.parentAdapter log: @"Rewarded ad failed to display with error: %@, for placement: %@", error.localizedDescription, placement.placementName];

    MAAdapterError *adapterError = [MAAdapterError errorWithAdapterError: MAAdapterError.adDisplayFailedError
                                                mediatedNetworkErrorCode: error.code
                                             mediatedNetworkErrorMessage: error.localizedDescription];

    [self.delegate didFailToDisplayRewardedAdWithError: adapterError];
}

- (void)adDidRewardForPlacement:(HyprMXPlacement *)placement rewardName:(NSString *)rewardName rewardValue:(NSInteger)rewardValue
{
    [self.parentAdapter log: @"Rewarded ad for placement: %@ granted reward with rewardName: %@, rewardValue: %ld", placement.placementName, rewardName, (long) rewardValue];
    self.grantedReward = YES;
}

@end
