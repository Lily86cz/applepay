//
//  ApplePayManager.m
//  BaseTemplate
//
//  Created by Lily on 2021/11/30.
//  Copyright © 2021 张业. All rights reserved.
//

#import "ApplePayManager.h"
#import "ApplePayFMDB.h"
#import "AFNetworking.h"
#import "ApplePayConfig.h"
#import "PublicMethod.h"
#import <Flutter/Flutter.h>
@interface ApplePayManager ()
@property (nonatomic, strong) SKPaymentTransaction *paymentTransaction;
@property (nonatomic, assign) NSInteger modelid;
@property (nonatomic ,assign) NSInteger ipaID;
@property (nonatomic, strong) FlutterMethodChannel *methodChannel;
@end
@implementation ApplePayManager
+ (instancetype)sharedInstance {
    static ApplePayManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (void) logRequest:(NSMutableDictionary *)param success:(void (^)(NSDictionary *dic))success {
    //1.url
    NSDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:Key_payInfo];
   
    NSURL *url = [NSURL URLWithString:dic[@"payAllLogURL"]];
    //2.创建可变的请求对象
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    //4.修改请求方法为POST
    request.HTTPMethod = @"POST";

    //有参数请求题
    if (param) {
        //5.设置请求体
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:param options:0 error:&error];
        request.HTTPBody = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding];
    }

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    //设置接受数据type
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // 3.获取会话对象
    NSURLSession *session = [NSURLSession sharedSession];

    // 4.根据会话对象，创建Task任务
    NSURLSessionDataTask *sessionDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (!error) {
                if (!data) {
                    return;
                }
                //Json解析
                NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                NSString *status =[NSString stringWithFormat:@"%@",responseDic[@"status"]];
                if ([status isEqualToString:@"200"]) {
                    success(responseDic);
                }

            }else {

            }
        });
    }];
    // 5.执行任务
    [sessionDataTask resume];
    
}
#pragma mark - 调完后台下单后进行内购的操作
- (void)startTopay:(NSDictionary*)info withFlutterMethod:(FlutterMethodChannel *)methodChannel {
    //保存下单记录
    self.methodChannel = methodChannel;
    WeakObj(self);
    NSDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:Key_payInfo];
    BBGPayModel *model = [[BBGPayModel alloc] init];
    model.o_memberId = dic[@"no"];
    model.o_payTransactionsId = info[@"payTransactionsId"];
    model.o_orderNo = info[@"id"];
    self.ipaID = [[ApplePayFMDB defaultFMDB] insertByBBGPayModel:model];
//日志
    NSMutableDictionary *dataParams = [NSMutableDictionary new];
    [dataParams setValue:info[@"payTransactionsId"] forKey:@"orderId"];
    [dataParams setValue:@"后台下单成功" forKey:@"result"];
    [self payLogWithParams:dataParams];
    
    [[ApplePay shareIAPManager] addPurchWithProductID:info[@"id"] andOrderId:info[@"payTransactionsId"] iapId:self.ipaID completeHandle:^(IAPPurchType type, SKPaymentTransaction * _Nonnull paymentTransaction) {
        
        NSMutableDictionary *params = [NSMutableDictionary new];
        [params setValue:info[@"payTransactionsId"] forKey:@"orderId"];
        [params setValue:@"内购流程走完了" forKey:@"result"];
        [self payLogWithParams:params];

        NSString *receipt_data;
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[receiptURL path]]) {
            
            NSData *data = [NSData dataWithContentsOfURL:receiptURL];
            receipt_data = [data base64EncodedStringWithOptions:0];
        }else {
            
//            receipt_data = [[ NSString alloc] initWithData:paymentTransaction.transactionReceipt encoding:NSUTF8StringEncoding];
            return;
        }
      
        [selfWeak applePayBackWithReceipt_data:receipt_data and:paymentTransaction.transactionIdentifier  and:info[@"payTransactionsId"]  andNo:dic[@"no"] andtransaction:paymentTransaction andmodelId:self.ipaID andBool:NO success:^(BOOL succ) {
            if(succ){
                [selfWeak.methodChannel invokeMethod:@"toast" arguments:@"购买成功"];
                // 删除 记录
                [[ApplePayFMDB defaultFMDB] deleteById:self.ipaID];
                // 完成订单
                [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
                [selfWeak.methodChannel invokeMethod:applePay arguments:info];
            }
           
        }];
    }];
    
}

#pragma mark -- 回调
- (void)applePayBackWithReceipt_data:(NSString *)receipt_data and:(NSString *)transactionsId and:(NSString *)payOrderId andNo:(NSString *)no andtransaction: (SKPaymentTransaction *)transaction andmodelId:(NSInteger )modelId andBool:(BOOL)isRestore success:(void (^)(BOOL succ))success {
    WeakObj(self);
    self.paymentTransaction =transaction;
    self.modelid = modelId;
    NSMutableDictionary *para = [NSMutableDictionary new];
    [para setValue:receipt_data forKey:@"receipt"];//苹果返回的加密数据
    [para setValue:transactionsId forKey:@"transactionsId"];//苹果返回的支付ID
    
    [para setValue:payOrderId forKey:@"orderId"];//订单ID
    NSDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:Key_payInfo];

    
        //1.url
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",dic[@"payUrl"],payUrlApi]];
        //2.创建可变的请求对象
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
        //4.修改请求方法为POST
        request.HTTPMethod = @"POST";
    //5.设置请求体
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:para options:0 error:&error];
    request.HTTPBody = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding];

        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        //设置接受数据type
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

        // 3.获取会话对象
        NSURLSession *session = [NSURLSession sharedSession];

        // 4.根据会话对象，创建Task任务
        NSURLSessionDataTask *sessionDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{

                if (!error) {
                    if (!data) {
                        return;
                    }
                    //Json解析
                    NSHTTPURLResponse * responses = (NSHTTPURLResponse *)response;
                    NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                    NSString *status =[NSString stringWithFormat:@"%@",responseDic[@"status"]];
                    if ([status isEqualToString:@"200"]) {
                        
                        // block
                        if (success) {

                            success(YES);
                        }
                      

                        // 完成订单
                        //移除掉支付成功的字典
                        NSMutableArray *list = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:Key_orderInfo]];
                        NSMutableArray *ary = [NSMutableArray new];
                        for (NSDictionary *info in list) {
                            if ([info[@"payOrderId"] isEqualToString:payOrderId]) {
                                [ary addObject:info];
                            }
                        }
                        for (NSDictionary *info in ary) {
                            if ([list containsObject:info]) {
                                [list removeObject:info];
                            }
                        }
                        //保存数据
                        [[NSUserDefaults standardUserDefaults] setObject:list forKey:Key_orderInfo];
                        [[NSUserDefaults standardUserDefaults] synchronize];

                        
                        //日志接口
                        NSMutableDictionary *dataParams = [NSMutableDictionary new];
                        [dataParams setValue:payOrderId forKey:@"orderId"];
                        [dataParams setValue:[NSString stringWithFormat:@"回调服务器成功，加豆完成,data的satus是%@,response的statusCode是%ld,",status,(long)responses.statusCode] forKey:@"result"];

                        [selfWeak payLogWithParams:dataParams];
                    }else {
                        if (success) {
                            success(NO);
                        }
                        if(!isRestore){
                            [self savePayBackFailByReceipt_data:receipt_data and:transactionsId and:payOrderId andNo:no];
                        }
                        
                        NSString *requestId =[NSString stringWithFormat:@"%@",responseDic[@"requestId"]];
                        NSString *errorCode =[NSString stringWithFormat:@"%@",responseDic[@"errorCode"]];
                        NSString *errorDec =[NSString stringWithFormat:@"%@",responseDic[@"error"]];
                     
                        
                        NSMutableDictionary *dataParams = [NSMutableDictionary new];
                        [dataParams setValue:payOrderId forKey:@"orderId"];
                        [dataParams setValue:[NSString stringWithFormat:@"回调服务器失败，加豆失败,data的satus是%@，response的statusCode是%ld,requestId是%@，errorCode是%@，error是%@",status,(long)responses.statusCode,requestId,errorCode,errorDec] forKey:@"result"];
                        [dataParams setValue:transaction forKey:@"transaction"];
                        [selfWeak payLogWithParams:dataParams];

                    }

                }else {
                    if (success) {
                        success(NO);
                    }
                    id errorInfo =error.userInfo;
                    NSMutableDictionary *dataParams = [NSMutableDictionary new];
                    [dataParams setValue:payOrderId forKey:@"orderId"];
                    [dataParams setValue:[NSString stringWithFormat:@"回调服务器请求接口报错,error是%@",convertToJSONData(errorInfo)] forKey:@"result"];
                    [dataParams setValue:transaction forKey:@"transaction"];
                   
                    [selfWeak payLogWithParams:dataParams];

                    [self.methodChannel invokeMethod:@"hideLoading" arguments:NULL];
                    if(!isRestore){
                        [self savePayBackFailByReceipt_data:receipt_data and:transactionsId and:payOrderId andNo:no];
                    }
                   
                }
            });
        }];
        // 5.执行任务
        [sessionDataTask resume];
}


//日志总调用方法
- (void)payLogWithParams:(NSDictionary *) param {
    NSDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:Key_payInfo];
   
    id orderId = handleNullObjectForKey(param, @"orderId");
    id result = handleNullObjectForKey(param, @"result");//sign
    id transaction = handleNullObjectForKey(param, @"transaction");//sign
    
    NSMutableDictionary *params = [NSMutableDictionary new];
   
    NSString *sign;
    NSString *productIdentifier;
    NSString *transactionsId;
    if(transaction!=nil){
        SKPaymentTransaction* newTransaction =transaction;
        sign = [[ NSString alloc] initWithData:newTransaction.transactionReceipt encoding:NSUTF8StringEncoding];
        productIdentifier = newTransaction.payment.productIdentifier;
        transactionsId = newTransaction.transactionIdentifier;
    }
    [params setValue:orderId forKey:@"orderId"];
    [params setValue:result forKey:@"result"];
    [params setValue:[PublicMethod nowTime] forKey:@"nowTime"];
    [params setValue:dic[@"no"] forKey:@"no"];
    [params setValue:sign forKey:@"haveVerificationData"];
    [params setValue:[NSString stringWithFormat:@"%@%@",dic[@"payUrl"],payUrlApi] forKey:@"payUrl"];
    [params setValue:productIdentifier forKey:@"haveTransactionsId"];
    [params setValue:transactionsId forKey:@"transactionsId"];
    
    [self payLogWithPayServiceWiithParam:params];
    [self allPayLogRequestWithParam:params withIsCleanAll:NO];
    NSMutableArray *aryLogList = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:Key_logList]];
    
    [params removeObjectForKey:@"haveVerificationData"];
    [aryLogList addObject:params];
    [[NSUserDefaults standardUserDefaults] setValue:aryLogList forKey:Key_logList];
   
}
//支付域日志
- (void)payLogWithPayServiceWiithParam:(NSMutableDictionary*) param {
    NSMutableDictionary *paras = [NSMutableDictionary new];
    NSString *str = dictionaryToJson(param);
    [paras setValue:str forKey:@"logJson"];
    
    NSDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:Key_payInfo];
    NSString *url=dic[@"payLogURL"];//上架
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain",nil];
    [manager POST:url parameters:paras  progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSLog(@"%@",  responseObject);
        id jsonObj = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        if ([jsonObj isKindOfClass:[NSDictionary class]]) {
            
            NSDictionary *esponse = [NSDictionary dictionaryWithDictionary:(NSDictionary *)jsonObj];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
    
}
//汇总接口
- (void)allPayLogRequestWithParam:(NSMutableDictionary*)para withIsCleanAll:(BOOL) isCleanAll {
    NSMutableDictionary *params = [NSMutableDictionary new];
    if(!isCleanAll){
       
        [params setValue:para forKey:@"logList"];
        [self logRequest:params success:^(NSDictionary *dic) {
            NSLog(@"ddd");
        }];
    }else {
        NSMutableArray*ary = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:Key_logList]];
       
        if(ary.count>0){

            [params setValue:ary forKey:@"logList"];
            [self logRequest:params success:^(NSDictionary *dic) {
                NSMutableArray *a = [NSMutableArray new];
                [[NSUserDefaults standardUserDefaults]setValue:a forKey:Key_logList];
            }];
        }
       
    }
    
}
// 清除日志
- (void) cleanPayLog {
    
    [self allPayLogRequestWithParam:nil withIsCleanAll:YES];
}
#pragma mark -  保存回调失败记录
- (void)savePayBackFailByReceipt_data:(NSString *)receipt_data and:(NSString *)transactionsId and:(NSString *)payOrderId  andNo:(NSString *)menberID{
    
    NSMutableDictionary *failInfo;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:Key_payBackFail]) {
        
        failInfo = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:Key_payBackFail]];
    }else {
        
        failInfo = [[NSMutableDictionary alloc] init];
    }
    NSMutableDictionary *currectFailInfo;
    if ([failInfo.allKeys containsObject:transactionsId]) {
        
        currectFailInfo = [NSMutableDictionary dictionaryWithDictionary:failInfo[transactionsId]];
        
    }else {
        
        currectFailInfo = [NSMutableDictionary dictionaryWithDictionary:@{
            
            @"receipt_data":receipt_data?receipt_data:@"",
            @"transactionsId":transactionsId?transactionsId:@"",
            @"payOrderId":payOrderId?payOrderId:@"",
            @"memberID":menberID?menberID:@"",
            @"payBackCount":@1, //
        }];
    }
    
    //累计次数
    NSInteger payBackCount = [currectFailInfo[@"payBackCount"] integerValue];
    payBackCount ++;
    NSMutableDictionary *dataParams = [NSMutableDictionary new];
    [dataParams setValue:payOrderId forKey:@"orderId"];
    [dataParams setValue:[NSString stringWithFormat:@"支付回调重试3次的第%ld次",(long)payBackCount] forKey:@"result"];
   
    [self payLogWithParams:dataParams];
    if (payBackCount > 1) {
        // 大于3次无须再回调 了
        //移除掉该字典
        NSMutableArray *list = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:Key_orderInfo]];
        NSMutableArray *ary = [NSMutableArray new];
        for (NSDictionary *info in list) {
            if ([info[@"payOrderId"] isEqualToString:payOrderId]||!info[@"payOrderId"]) {
                [ary addObject:info];
            }
        }
        for (NSDictionary *info in ary) {
            if ([list containsObject:info]) {
                [list removeObject:info];
            }
        }
        //保存数据
        [[NSUserDefaults standardUserDefaults] setObject:list forKey:Key_orderInfo];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            //ShowMessageInCenter(@"您好，您的套餐购买未到账，请联系客服咨询，谢谢。", 1.5);
            [self.methodChannel invokeMethod:@"toast" arguments:@"您好，您的套餐购买未到账，请联系客服咨询，谢谢。"];
        });
       
        return;
        
    }
   
    [currectFailInfo setValue:@(payBackCount) forKey:@"payBackCount"];
    // 重新放进 缓存里面
    [failInfo setValue:currectFailInfo forKey:transactionsId];
    [[NSUserDefaults standardUserDefaults] setObject:failInfo forKey:Key_payBackFail];
    
    //10秒后调用方法
    [self performSelector:@selector(reSend:) withObject:currectFailInfo afterDelay:10.0];
}

- (void)reSend:(NSMutableDictionary *)currectFailInfo{
    
    WeakObj(self);
    [self applePayBackWithReceipt_data:currectFailInfo[@"receipt_data"] and:currectFailInfo[@"transactionsId"] and:currectFailInfo[@"payOrderId"] andNo:currectFailInfo[@"memberID"] andtransaction:selfWeak.paymentTransaction andmodelId:self.modelid andBool:NO success:^(BOOL succ) {
        
        if(succ){
            // 删除 记录
            [[ApplePayFMDB defaultFMDB] deleteById:selfWeak.modelid];
            // 完成订单
            [[SKPaymentQueue defaultQueue] finishTransaction:selfWeak.paymentTransaction];
        }
      
    }];
}

@end
