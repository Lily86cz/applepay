//
//  ApplePay.m
//  AppInPurchasing
//
//  Created by Andrew on 2019/11/12.
//  Copyright © 2019 余默. All rights reserved.
//

#import "ApplePay.h"
#import "ApplePayManager.h"
#import "ApplePayConfig.h"
#import "ApplePayFMDB.h"
#import "AFNetworking.h"
#import <Flutter/Flutter.h>
@interface ApplePay () <SKProductsRequestDelegate,SKPaymentTransactionObserver>
{
    NSString *_purchID;
    NSString *_orderID;
    IAPCompletionHandleBlock _handle;
    NSInteger _iapId;
    
    IAPPriceHandleBlock _handle_prices;
    
    
    
}
@property (nonatomic ,strong) NSString *orderNo;
@property (nonatomic ,strong) FlutterMethodChannel *methodChannel;
@property (nonatomic ,assign) BOOL isCheck;
@property (nonatomic ,assign) BOOL isRestore;//是否恢复购买
@end

@implementation ApplePay

/*注意事项：
 1.沙盒环境测试appStore内购流程的时候，请使用没越狱的设备。
 2.请务必使用真机来测试，一切以真机为准。
 3.项目的Bundle identifier需要与您申请AppID时填写的bundleID一致，不然会无法请求到商品信息。
 4.如果是你自己的设备上已经绑定了自己的AppleID账号请先注销掉,否则你哭爹喊娘都不知道是怎么回事。
 5.订单校验 苹果审核app时，仍然在沙盒环境下测试，所以需要先进行正式环境验证，如果发现是沙盒环境则转到沙盒验证。
 识别沙盒环境订单方法：
 1.根据字段 environment = sandbox。
 2.根据验证接口返回的状态码,如果status=21007，则表示当前为沙盒环境。
 苹果反馈的状态码：
 21000 App Store无法读取你提供的JSON数据
 21002 订单数据不符合格式
 21003 订单无法被验证
 21004 你提供的共享密钥和账户的共享密钥不一致
 21005 订单服务器当前不可用
 21006 订单是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
 21007 订单信息是测试用（sandbox），但却被发送到产品环境中验证
 21008 订单信息是产品环境中使用，但却被发送到测试环境中验证
 */

#ifdef DEBUG
#define YMLog(...) NSLog(__VA_ARGS__)
#else
#define YMLog(...)
#endif

+ (instancetype)shareIAPManager {
   
    static ApplePay *IAPManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    
        IAPManager = [[ApplePay alloc] init];
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调
       // [[SKPaymentQueue defaultQueue] addTransactionObserver:IAPManager];
    });
    return IAPManager;
}

- (instancetype)init {
    if ([super init]) {
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue:updatedTransactions:方法
       [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)xxdealloc{
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}


- (void)checkApplePayOrderWithFlutterMethod:(FlutterMethodChannel *)methodChannel{
    _isCheck = YES;
    [[ApplePayManager sharedInstance] cleanPayLog];//清除日志
    self.methodChannel = methodChannel;
  
}
//点击恢复购买
- (void)clickReStore:(FlutterMethodChannel *)methodChannel andInfo:(NSDictionary*) info{
    NSLog(@"点击了恢复购买");
    self.methodChannel = methodChannel;
    [self.methodChannel invokeMethod:@"showLoading" arguments:NULL];
    
    NSArray *lists = [[ApplePayFMDB defaultFMDB] getAllIAPData];
    BBGPayModel *model = [lists lastObject];
    if (model.t_transactionState!=2&& model.t_transactionReceipt.length>0) {
        
        NSString *receipt_data=model.t_transactionReceipt;
//        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
//        if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptURL path]]) {
//            
//            NSData *data = [NSData dataWithContentsOfURL:receiptURL];
//            receipt_data = [data base64EncodedStringWithOptions:0];
//        }else {
//            
//           
//            receipt_data = [[ NSString alloc] initWithData:model.t_transactionReceipt encoding:NSUTF8StringEncoding];
//        }
//       
        // 回调后台
        WeakObj(self);
        [[ApplePayManager sharedInstance] applePayBackWithReceipt_data:receipt_data and:model.t_transactionIdentifier and:model.o_payTransactionsId andNo:model.o_memberId andtransaction:NULL andmodelId:model.iap_id andBool:YES success:^(BOOL succ) {
            [selfWeak.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
            if(succ){
                [selfWeak.methodChannel invokeMethod:@"toast" arguments:@"恢复购买成功"];
                //日志接口
                NSMutableDictionary *dataParams = [NSMutableDictionary new];
                [dataParams setValue:model.o_payTransactionsId forKey:@"orderId"];
                [dataParams setValue:@"这是点击恢复购买的订单" forKey:@"result"];
                [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
                
                // 删除 记录
                [[ApplePayFMDB defaultFMDB] deleteByBBGPayModel:model];
                [selfWeak.methodChannel invokeMethod:applePay arguments:info];
                // 完成订单
                [self removeAllUncompleteTransactionBeforeStartNewTransaction];
            }else{
             
                [selfWeak.methodChannel invokeMethod:@"toast" arguments:@"恢复购买失败，请稍后重试"];
            }
           
        }];
    }else{
       
        [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
        [self.methodChannel invokeMethod:@"HASNORESTORE" arguments:NULL];
    }

}

//添加内购产品1
- (void)addPurchWithProductID:(NSString *)product_id andOrderId:(nonnull NSString *)orderId iapId:(NSInteger)iapId completeHandle:(nonnull IAPCompletionHandleBlock)handle {
    
    _isCheck = NO;
  
    [self.methodChannel invokeMethod:@"showLoading" arguments:NULL];
    self.orderNo = orderId;
    //移除上次未完成的交易订单
    [self removeAllUncompleteTransactionBeforeStartNewTransaction];
    if (product_id) {
        
        if ([SKPaymentQueue canMakePayments]) {
            
            // 开始购买服务
            _purchID = product_id;
            _orderID = orderId;
            _handle = handle;
            _iapId = iapId;
            NSSet *nsset = [NSSet setWithArray:@[product_id]];
            SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
            request.delegate = self;
            [request start];
            
            NSMutableDictionary *dataParams = [NSMutableDictionary new];
            [dataParams setValue:self.orderNo forKey:@"orderId"];
            [dataParams setValue:@"内购准备支付，正在连接苹果服务器" forKey:@"result"];
            [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
        }else{
            
            [self handleActionWithType:IAPPurchNotArrow data:nil];
        }
    }
}

- (void)handleActionWithType:(IAPPurchType)type data:(NSData *)data{
    switch (type) {
        case IAPPurchSuccess:{
            NSMutableDictionary *dataParams = [NSMutableDictionary new];
            [dataParams setValue:self.orderNo forKey:@"orderId"];
            [dataParams setValue:@"ApplePay购买成功" forKey:@"result"];
            [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
            YMLog(@"购买成功");

            [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
        }break;
        case IAPPurchFailed:
            YMLog(@"购买失败");
            [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
            break;
        case IAPPurchCancel:
            YMLog(@"用户取消购买");
           
            [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
           
            break;
        case IAPPurchVerFailed:
            YMLog(@"订单校验失败");
            break;
        case IAPPurchVerSuccess:
            YMLog(@"订单校验成功");
            break;
        case IAPPurchNotArrow:
            YMLog(@"不允许程序内付费");
            [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
            break;
        default:
            break;
    }
}

- (void)getProductListInfo:(NSArray *)products purchasePriceBlock: (IAPPriceHandleBlock) haddel {
    
    if ([SKPaymentQueue canMakePayments]) {
        
        _handle_prices = haddel;
        NSSet *nsset = [NSSet setWithArray:products];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
        request.delegate = self;
        [request start];
       
    }else{
        
        [self handleActionWithType:IAPPurchNotArrow data:nil];
    }
}

- (void)hiddenLoading {
    
    [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
    [[NSNotificationCenter defaultCenter ] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}


#pragma mark -
// 交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    
    [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
    
    NSMutableDictionary *dataParams = [NSMutableDictionary new];
    [dataParams setValue:self.orderNo forKey:@"orderId"];
    [dataParams setValue:@"内购交易完成（有票据或者没有）" forKey:@"result"];
    [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
    
    // Your application should implement these two methods.
    NSString * productIdentifier = transaction.payment.productIdentifier;
    NSData *data = [productIdentifier dataUsingEncoding:NSUTF8StringEncoding];
    NSString *receipt = [data base64EncodedStringWithOptions:0];
    
    YMLog(@"%@",receipt);
    if ([productIdentifier length] > 0) {

        NSMutableDictionary *orderInfo = [NSMutableDictionary new];
        NSString *receipt_data;
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptURL path]]) {

            NSData *data = [NSData dataWithContentsOfURL:receiptURL];
            receipt_data = [data base64EncodedStringWithOptions:0];
        }else {

            receipt_data = [[ NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
        }
        BBGPayModel *payModel = [[ApplePayFMDB defaultFMDB] getIAPDataByIAPId:_iapId];
        payModel.t_sign = receipt_data;
        payModel.t_transactionReceipt =receipt_data;
        payModel.t_transactionState = transaction.transactionState;
        payModel.t_transactionIdentifier = transaction.transactionIdentifier;
        [[ApplePayFMDB defaultFMDB] changeByBBGPayModel:payModel];//新加
        
        [orderInfo setValue:receipt_data forKey:@"receipt_data"];//苹果返回的加密数据
        [orderInfo setValue:transaction.transactionIdentifier forKey:@"transactionsId"];//苹果返回的支付ID
        [orderInfo setValue:self.orderNo forKey:@"payOrderId"];//订单ID
        //获取之前保存的数据
        NSMutableArray *list = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:Key_orderInfo]];
        //添加数据
        [list addObject:orderInfo];
        //保存数据
        [[NSUserDefaults standardUserDefaults] setObject:list forKey:Key_orderInfo];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        //日志接口
        NSMutableDictionary *dataParams = [NSMutableDictionary new];
        [dataParams setValue:self.orderNo forKey:@"orderId"];
        [dataParams setValue:@"内购交易完成（有票据）,准备前往服务器校验" forKey:@"result"];
        [dataParams setValue:transaction forKey:@"transaction"];
        [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
        
        
//        //将订单数据发送到后端验证
        if (_handle) {

            _handle(IAPPurchSuccess,transaction);
            _handle = nil;
        }
    }else {
        
        //日志接口
        NSMutableDictionary *dataParams = [NSMutableDictionary new];
        [dataParams setValue:self.orderNo forKey:@"orderId"];
        [dataParams setValue:@"内购交易完成（没有票据）" forKey:@"result"];
        [dataParams setValue:transaction forKey:@"transaction"];
        [[ApplePayManager sharedInstance] payLogWithParams:dataParams];

    }
    [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO];
}

// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    
    [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
    
    if (transaction.error.code != SKErrorPaymentCancelled) {
        
        //日志接口
        NSMutableDictionary *dataParams = [NSMutableDictionary new];
        [dataParams setValue:self.orderNo forKey:@"orderId"];
        [dataParams setValue:@"购买失败" forKey:@"result"];
        [dataParams setValue:transaction forKey:@"transaction"];
        [[ApplePayManager sharedInstance] payLogWithParams:dataParams];

        [self.methodChannel invokeMethod:@"toast" arguments:@"购买失败"];
        [self handleActionWithType:IAPPurchFailed data:nil];
    }else{
        //日志接口
        NSMutableDictionary *dataParams = [NSMutableDictionary new];
        [dataParams setValue:self.orderNo forKey:@"orderId"];
        [dataParams setValue:@"用户取消购买" forKey:@"result"];
        [dataParams setValue:transaction forKey:@"transaction"];
        [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
     
        [self handleActionWithType:IAPPurchCancel data:nil];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag{
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if(!receipt){
        // 交易凭证为空验证失败
        [self handleActionWithType:IAPPurchVerFailed data:nil];
        return;
    }
    // 购买成功将交易凭证发送给服务端进行再次校验
    [self handleActionWithType:IAPPurchSuccess data:receipt];
    
    NSError *error;
    NSDictionary *requestContents = @{
        @"receipt-data": [receipt base64EncodedStringWithOptions:0]
    };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) { // 交易凭证为空验证失败
        [self handleActionWithType:IAPPurchVerFailed data:nil];
        return;
    }
    
    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
    
#ifdef DEBUG
#define serverString @"https://sandbox.itunes.apple.com/verifyReceipt"
#else
#define serverString @"https://buy.itunes.apple.com/verifyReceipt"
#endif
    
    
    NSURL *storeURL = [NSURL URLWithString:serverString];
    if (flag) {
        //flag 为YES 时，验证 沙盒环境
       storeURL= [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    }
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    [session dataTaskWithRequest:storeRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        
        if (error) {
            // 无法连接服务器,购买校验失败
            [self handleActionWithType:IAPPurchVerFailed data:nil];
        } else {
            NSError *error;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!jsonResponse) {
                // 苹果服务器校验数据返回为空校验失败
                [self handleActionWithType:IAPPurchVerFailed data:nil];
            }
            
            // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
            NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
            if (status && [status isEqualToString:@"21007"]) {
                [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES];
              
            }else if(status && [status isEqualToString:@"0"]){
                [self handleActionWithType:IAPPurchVerSuccess data:nil];

            }
            YMLog(@"----验证结果 %@",jsonResponse);
        }
    }];
    
   
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    
    NSArray *product = response.products;
    if([product count] <= 0){
        YMLog(@"--------------没有商品------------------");
        return;
    }
    if (_handle_prices) {
        
        NSMutableArray* productListArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < [product count]; ++i) {
            
            NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
            SKProduct* p = [product objectAtIndex:i];
            [dict setObject:(p.localizedTitle != nil ? p.localizedTitle : @"") forKey:@"localizedTitle"];
            [dict setObject:(p.localizedDescription != nil ? p.localizedDescription : @"") forKey:@"localizedDescription"];
            [dict setObject:p.price forKey:@"price"];
            [dict setObject:p.productIdentifier forKey:@"productIdentifier"];
            NSString* currencySymbol = [p.priceLocale objectForKey:NSLocaleCurrencySymbol];
            [dict setObject:currencySymbol forKey:@"priceLocale"];
            [productListArray addObject:dict];
        }
        
        _handle_prices(productListArray);
        _handle_prices = nil;
        return;
    }
    
    
    SKProduct *p = nil;
    for(SKProduct *pro in product){
        if([pro.productIdentifier isEqualToString:_purchID]){
            p = pro;
            break;
        }
    }
    
    YMLog(@"productID:%@", response.invalidProductIdentifiers);
    YMLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    YMLog(@"%@",[p description]);
    YMLog(@"%@",[p localizedTitle]);
    YMLog(@"%@",[p localizedDescription]);
    YMLog(@"%@",[p price]);
    YMLog(@"%@",[p productIdentifier]);
    if (p) {
        SKPayment *payment = [SKPayment paymentWithProduct:p];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
      
    }
}

//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    YMLog(@"------------------错误-----------------:%@", error);

    [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
}

- (void)requestDidFinish:(SKRequest *)request{
    YMLog(@"------------反馈信息结束-----------------");
}

#pragma mark - SKPaymentTransactionObserver，//监听购买结果2

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{

    if (_isCheck) {
     
        /*
         1.启动App时，检查是否有未完成的订单
         2.若 有 订单存在 并且支付成功 就 回调后台。与后台交互成功 之后 才要 结束该订单。
        */

        for (SKPaymentTransaction *tran in transactions) {
            switch (tran.transactionState) {
                case SKPaymentTransactionStatePurchased:{

                    BBGPayModel *model = [[ApplePayFMDB defaultFMDB] getIAPDataByTransactionIdentifier:tran.transactionIdentifier];

                    // 如果model为空 ，就获取所有记录的最后一条
                    if (!model) {

                        NSArray *lists = [[ApplePayFMDB defaultFMDB] getAllIAPData];
                        model = [lists lastObject];
                    }
                    // 需要让后端 添加个 memberId 字段

                    if (model.t_transactionState!=2) {

                        NSString *receipt_data;
                        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                        if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptURL path]]) {

                            NSData *data = [NSData dataWithContentsOfURL:receiptURL];
                            receipt_data = [data base64EncodedStringWithOptions:0];
                        }else {

                            receipt_data = [[ NSString alloc] initWithData:tran.transactionReceipt encoding:NSUTF8StringEncoding];
                        }
                        NSLog(@"走进了追回的回调");
                        // 回调后台
                        [[ApplePayManager sharedInstance] applePayBackWithReceipt_data:receipt_data and:tran.transactionIdentifier and:model.o_payTransactionsId andNo:model.o_memberId andtransaction:tran andmodelId:model.iap_id andBool:NO success:^(BOOL succ) {
                            
                            if(succ){
                                [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
                                [self.methodChannel invokeMethod:@"toast" arguments:@"购买成功"];
                                //日志接口
                                NSMutableDictionary *dataParams = [NSMutableDictionary new];
                                [dataParams setValue:model.o_payTransactionsId forKey:@"orderId"];
                                [dataParams setValue:@"这是追回的订单" forKey:@"result"];
                                [[ApplePayManager sharedInstance] payLogWithParams:dataParams];
                                
                                // 删除 记录
                                [[ApplePayFMDB defaultFMDB] deleteByBBGPayModel:model];
                              
                                // 完成订单
                                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                            }
                          
                        }];
                    }
                }break;
                case SKPaymentTransactionStatePurchasing:

                    [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                   
                    break;
                case SKPaymentTransactionStateRestored:
    
                    NSLog(@"走了恢复购买");
                    [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                   // 消耗型不支持恢复购买
                   
                    break;
                case SKPaymentTransactionStateFailed:
                    [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                  
                    break;
                default:
                    break;
            }
        }
        
        _isCheck = NO;
      
    }else {
        
        // 获取 记录中的数据 （model）
        BBGPayModel *payModel = [[ApplePayFMDB defaultFMDB] getIAPDataByIAPId:_iapId];
        
        for (SKPaymentTransaction *tran in transactions) {
            
            
            switch (tran.transactionState) {
                case SKPaymentTransactionStatePurchased:{
                    YMLog(@"交易完成");

                    NSString *receipt_data;
                    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptURL path]]) {
                        
                        NSData *data = [NSData dataWithContentsOfURL:receiptURL];
                        receipt_data = [data base64EncodedStringWithOptions:0];
                    }else {
                        
                        receipt_data = [[ NSString alloc] initWithData:tran.transactionReceipt encoding:NSUTF8StringEncoding];
                    }
                    payModel.t_sign = receipt_data;
                    payModel.t_transactionState = tran.transactionState;
                    payModel.t_transactionReceipt =receipt_data;
                    payModel.t_transactionIdentifier = tran.transactionIdentifier;
                    
                    // 保存到数据库里面
                    NSLog(@"走进了正常购买的回调");
                    [[ApplePayFMDB defaultFMDB] changeByBBGPayModel:payModel];
                    [self completeTransaction:tran];

                } break;
                case SKPaymentTransactionStatePurchasing:{
                    YMLog(@"商品添加进列表");

                    payModel.t_transactionState = tran.transactionState;

                    // 保存到数据库里面
                    [[ApplePayFMDB defaultFMDB] changeByBBGPayModel:payModel];
                    
                }break;
                case SKPaymentTransactionStateRestored:
                    YMLog(@"已经购买过商品");
                    // 消耗型不支持恢复购买
                    [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                    break;
                case SKPaymentTransactionStateFailed:
                    [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                    [self failedTransaction:tran];

                    payModel.t_transactionState = tran.transactionState;
                    payModel.t_transactionIdentifier = tran.transactionIdentifier;
                    // 保存到数据库里面
                    [[ApplePayFMDB defaultFMDB] changeByBBGPayModel:payModel];

                    break;
                default:
                    break;
            }
        }
    }
}

#pragma mark -- 结束上次未完成的交易 防止串单
-(void)removeAllUncompleteTransactionBeforeStartNewTransaction{
    NSArray* transactions = [SKPaymentQueue defaultQueue].transactions;
    if (transactions.count > 0) {
        //检测是否有未完成的交易
        SKPaymentTransaction* transaction = [transactions firstObject];
        if (transaction.transactionState != SKPaymentTransactionStatePurchasing) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
}


@end
