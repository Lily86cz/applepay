//
//  ApplePay.h
//  AppInPurchasing
//
//  Created by Andrew on 2019/11/12.
//  Copyright © 2019 余默. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <Flutter/Flutter.h>
NS_ASSUME_NONNULL_BEGIN

typedef enum {
    IAPPurchSuccess = 0,//购买成功
    IAPPurchFailed = 1, //购买失败el
    IAPPurchCancel = 2, //取消购买
    IAPPurchVerFailed = 3, //订单校验失败
    IAPPurchVerSuccess = 4, //订单校验成功
    IAPPurchNotArrow = 5, //不允许内购
}IAPPurchType;

typedef void(^IAPCompletionHandleBlock)(IAPPurchType type, SKPaymentTransaction *paymentTransaction);
typedef void(^IAPPriceHandleBlock)(NSArray *prices);

@interface ApplePay : NSObject


+ (instancetype)shareIAPManager;



/// 下单
/// @param product_id 内购商品id
/// @param handle 结果
- (void)addPurchWithProductID:(NSString *)product_id andOrderId:(NSString *)orderId iapId:(NSInteger)iapId completeHandle:(IAPCompletionHandleBlock)handle;



/// 获取内购商品价格
/// @param products 商品ids
/// @param haddel 返回价格数组
- (void)getProductListInfo:(NSArray *)products purchasePriceBlock: (IAPPriceHandleBlock) haddel;



/// App启动检查苹果支付订单
- (void)checkApplePayOrderWithFlutterMethod:(FlutterMethodChannel *)methodChannel;


- (void)clickReStore:(FlutterMethodChannel *)methodChannel andInfo:(NSDictionary*) info;
@end

NS_ASSUME_NONNULL_END
