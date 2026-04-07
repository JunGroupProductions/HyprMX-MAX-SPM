//
//  HyprMX_Max.h
//

#import <AppLovinSDK/AppLovinSDK.h>

@interface HyprMXAdapter : ALMediationAdapter <MASignalProvider, MAAdViewAdapter, MAInterstitialAdapter, MARewardedAdapter>
+(void)enableTestMode;
@end
