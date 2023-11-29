//
//  ApplePayManager.h
//  BaseTemplate
//
//  Created by Lily on 2021/11/30.
//  Copyright © 2021 张业. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ApplePay.h"
#import "ApplePayFMDB.h"
#import <Flutter/Flutter.h>
NS_ASSUME_NONNULL_BEGIN

@interface ApplePayManager : NSObject


+ (instancetype)sharedInstance;
//内购回调
- (void)applePayBackWithReceipt_data:(NSString *)receipt_data and:(NSString *)transactionsId and:(NSString *)payOrderId andNo:(NSString *)no andtransaction: (SKPaymentTransaction *)transaction andmodelId:(NSInteger )modelId andBool:(BOOL)isRestore  success:(void (^)(BOOL succ))success ;
////日志监测
//- (void)paymentLogWithResult:(NSString *)result andOrderId:(NSString *)orderId andNo:(NSString *) no andtransaction: (SKPaymentTransaction *)transaction;

//日志调用总方法
- (void)payLogWithParams:(NSDictionary *) param;

//清除日志
- (void) cleanPayLog;

//开始下单
- (void)startTopay:(NSDictionary*)info withFlutterMethod:(FlutterMethodChannel *)methodChannel;
@end

NS_ASSUME_NONNULL_END
