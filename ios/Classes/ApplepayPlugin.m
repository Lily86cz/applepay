#import "ApplepayPlugin.h"
#import "ApplePay.h"
#import "ApplePayConfig.h"
#import "ApplePayManager.h"

@interface ApplepayPlugin()<FlutterStreamHandler>
@property (nonatomic, strong) FlutterMethodChannel *MethodChannel;
@end
@implementation ApplepayPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"applepay"
                                     binaryMessenger:[registrar messenger]];
    
    ApplepayPlugin* instance = [[ApplepayPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    instance.MethodChannel =channel;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([initApplePay isEqualToString:call.method]) {
        NSDictionary *dic =call.arguments;
        [[NSUserDefaults standardUserDefaults] setValue:dic forKey:Key_payInfo];
        if([dic[@"isCheckPay"] boolValue]){
            [[ApplePay shareIAPManager] checkApplePayOrderWithFlutterMethod:self.MethodChannel];
        }
        
    }else if ([applePayStartToPay isEqualToString:call.method]) {
        NSDictionary *dic =call.arguments;
        [[ApplePayManager sharedInstance] startTopay:dic withFlutterMethod:self.MethodChannel];
    }else if ([restoreApplePay isEqualToString:call.method]) {
        NSDictionary *dic =call.arguments;
        [[NSUserDefaults standardUserDefaults] setValue:dic forKey:Key_payInfo];
        [[ApplePay shareIAPManager] clickReStore:self.MethodChannel andInfo:dic];
        
    }else {
        result(FlutterMethodNotImplemented);
    }
}

@end
