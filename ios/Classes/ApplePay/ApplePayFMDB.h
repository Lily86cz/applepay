//
//  ApplePayFMDB.h
//  BaseTemplate
//
//  Created by lily on 2020/12/24.
//  Copyright © 2020 张业. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 内购表数据模型
@interface BBGPayModel : NSObject

//@"iap_id integer PRIMARY KEY AUTOINCREMENT,",  // 内购表id
//// 订单相关字段
//@"o_memberId text,",
//@"o_orderId text,",
//@"o_orderNo text,",
//// 内购相关字段
//@"t_uuid text,",             // 内购的 uuid
//@"t_transactionState int,",  // 内购 状态
//@"t_transactionReceipt text,",// 内购 transactionReceipt
//@"t_sign text,",              // 内购 sign
//@"t_productIdentifier text,",
//// 时间
//@"createTime integer,",
//@"updateTime integer",

@property(nonatomic,assign) NSInteger iap_id;
@property(nonatomic,strong) NSString *o_memberId;
@property(nonatomic,strong) NSString *o_payTransactionsId;
@property(nonatomic,strong) NSString *o_orderNo;


//@property(nonatomic,strong) NSString *t_uuid;
@property(nonatomic,assign) NSInteger t_transactionState; // applypay 状态
@property(nonatomic,strong) NSString *t_transactionReceipt;//
@property(nonatomic,strong) NSString *t_sign;
@property(nonatomic,strong) NSString *t_transactionIdentifier;

@property(nonatomic,strong) NSString *createTime;
@property(nonatomic,strong) NSString *updateTime;


@end



@interface ApplePayFMDB : NSObject

+ (instancetype)defaultFMDB;
+ (void)drop; // 删除数据库

/// 创建数据库
- (void) initDataBase;

/// 插入数据
- (NSInteger)insertByBBGPayModel:(BBGPayModel *)BBGPayModel;
    
/// 所有数据
- (NSMutableArray *)getAllIAPData;

///// 根据 uuid 获取记录
//- (NSMutableArray *)getIAPDataByUUID:(NSString *)uuid;

/// 根据 transactionIdentifier 获取记录
- (BBGPayModel *)getIAPDataByTransactionIdentifier:(NSString *)transactionIdentifier;

/// 根据 iapid 获取记录
- (BBGPayModel *)getIAPDataByIAPId:(NSInteger )iapid;

/// 修改数据
- (void)changeByBBGPayModel:(BBGPayModel *)BBGPayModel;

/// 删除数据
- (void) deleteByBBGPayModel:(BBGPayModel *)BBGPayModel;
- (void) deleteById:(NSInteger )iapId;

@end

NS_ASSUME_NONNULL_END
