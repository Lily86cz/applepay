//
//  ApplePayFMDB.m
//  BaseTemplate
//
//  Created by lily on 2020/12/24.
//  Copyright © 2020 张业. All rights reserved.
//

#import "ApplePayFMDB.h"
#import <FMDB/FMDB.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "PublicMethod.h"
#define Path_document   [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]

#define db_name             @"kejian.db"
#define table_iap           @"tb_iap"  // 内购表

#define insert_start(tb_name)       [NSString stringWithFormat:@"insert into %@ (",tb_name]
#define select_all(tb_name)         [NSString stringWithFormat:@"select * from %@ ",tb_name]
#define delete_(tb_name,name)       [NSString stringWithFormat:@"delete from %@ where %@ = ?",tb_name,name]
#define update_(tb_name)            [NSString stringWithFormat:@"update %@ set ",tb_name]

@implementation BBGPayModel
@end


@interface ApplePayFMDB (){
    
    FMDatabase *fmdb;
    FMDatabaseQueue *_queue;
}
@end

@implementation ApplePayFMDB

static ApplePayFMDB *fmdb = nil;
+ (instancetype) defaultFMDB{
    
    @synchronized(self) {
        
        if(!fmdb) {
            
            fmdb = [[ApplePayFMDB alloc] init];
            [fmdb initDataBase];
        }
    }
    return fmdb;
}

+ (void)drop{
    
    //文件路径
    NSString *filePath = [Path_document stringByAppendingPathComponent:db_name];
    BOOL isSuccess = [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    if(!isSuccess) {
        
        NSLog(@"==fmdb=======  drop file table 失败 ");
    }
}


- (BOOL )checkOpen{
    
    if (fmdb.isOpen) {
        
        [fmdb close];
    }
    return [fmdb open];
}

/// 创建数据库
- (void) initDataBase {
    
    //文件路径
    NSString *filePath = [Path_document stringByAppendingPathComponent:db_name];
    //实例化FMDataBase对象
    NSLog(@"==fmdb=======   db path: %@ ",filePath);
    
    fmdb = [FMDatabase databaseWithPath:filePath];
    
    _queue = [FMDatabaseQueue databaseQueueWithPath:filePath];
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        if([self checkOpen]) {
            
            //初始化数据表
            [self add_IAP_Table];
            [fmdb close];
            
        }else{
            
            NSLog(@"==fmdb=======   数据库打开失败 %@ ", fmdb.lastErrorMessage);
        }
    }];
    
}


/// 创建 内购 表
- (void) add_IAP_Table{
    
    NSArray *array = @[
                       @"create table if not exists ",
                       table_iap,
                       @" (",
                       @"iap_id integer PRIMARY KEY AUTOINCREMENT,",  // 内购表id
                       // 订单相关字段
                       @"o_memberId text,",
                       @"o_payTransactionsId text,",
                       @"o_orderNo text,",
                       @"t_transactionState int,",  // 内购 状态
                       @"t_transactionReceipt text,",// 内购 transactionReceipt
                       @"t_sign text,",              // 内购 sign
                       @"t_transactionIdentifier text,",
                       // 时间
                       @"createTime text,",
                       @"updateTime text",
                       @")"
                       ];
    
    NSString *sql = @"";
    for (NSString *item in array) {
        
        sql = [sql stringByAppendingString:item];
    }
    BOOL success = [fmdb executeUpdate:sql];
    
    if(!success) {
        
        NSLog(@"==fmdb=======  创建 table失败---%@",fmdb.lastErrorMessage);
    }else{
        
        NSLog(@"==fmdb=======   创建 table成功 ");
    }
   
}


/* FIXME:插入数据 */
- (NSInteger)insertByBBGPayModel:(BBGPayModel *)BBGPayModel{
    
    long long __block i;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        BBGPayModel.createTime = [PublicMethod nowTime];
        
        NSString *sql = [self getInsertSql:[self getAllProperty:[BBGPayModel class]] withTableName:table_iap];
        [self checkOpen];
        BOOL isAddSuccess = [fmdb executeUpdate:sql,
                             BBGPayModel.o_memberId,
                             BBGPayModel.o_payTransactionsId,
                             BBGPayModel.o_orderNo,
                             
//                             BBGPayModel.t_uuid,
                             @(BBGPayModel.t_transactionState),
                             BBGPayModel.t_transactionReceipt,
                             BBGPayModel.t_sign,
                             BBGPayModel.t_transactionIdentifier,
                             
                             BBGPayModel.createTime,
                             BBGPayModel.updateTime
                             ];
        if(!isAddSuccess) {
            NSLog(@"==fmdb=======  插入信息失败  %@ ",fmdb.lastErrorMessage);
        }else{
            NSLog(@"==fmdb=======  插入信息成功   ");
        }
        i = 0;
        if (isAddSuccess) {
            
            i = [fmdb lastInsertRowId]; // 获取此记录 id
        }
        [fmdb close];
    }];
    return i;
}

/* FIXME:获取数据 */
/// 所有数据
- (NSMutableArray *)getAllIAPData{
    
    NSMutableArray __block *array;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        [self checkOpen];
        FMResultSet *result = [fmdb executeQuery:select_all(table_iap)];
        array = [self analysisResultSet:result];
        [fmdb close];
    }];
    return array;
}

/// 根据 uuid 获取记录
- (NSMutableArray *)getIAPDataByUUID:(NSString *)uuid{
    
    BBGPayModel __block *ipaModel;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        [self checkOpen];
        NSString *whereString = [NSString stringWithFormat:@"where t_uuid = %@",uuid];
        FMResultSet *result = [fmdb executeQuery:[NSString stringWithFormat:@"%@ %@",select_all(table_iap),whereString]];
        NSArray *array = [self analysisResultSet:result];
        if (array.count > 0) {
            
            ipaModel = array[0];
        }
        [fmdb close];
    }];
    return ipaModel;
}

/// 根据 orderNo 获取记录
- (BBGPayModel *)getIAPDataByTransactionIdentifier:(NSString *)transactionIdentifier; {
    
    BBGPayModel __block *ipaModel;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        [self checkOpen];
        NSString *whereString = [NSString stringWithFormat:@"where t_transactionIdentifier = %@",transactionIdentifier];
        FMResultSet *result = [fmdb executeQuery:[NSString stringWithFormat:@"%@ %@",select_all(table_iap),whereString]];
        NSArray *array = [self analysisResultSet:result];
        if (array.count > 0) {
            
            ipaModel = array[0];
        }
        [fmdb close];
    }];
    return ipaModel;
}

/// 根据 iapid 获取记录
- (BBGPayModel *)getIAPDataByIAPId:(NSInteger )iapid{
    
    BBGPayModel __block *ipaModel;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        [self checkOpen];
        NSString *whereString = [NSString stringWithFormat:@"where iap_id = %ld",(long)iapid];
        FMResultSet *result = [fmdb executeQuery:[NSString stringWithFormat:@"%@ %@",select_all(table_iap),whereString]];
        NSArray *array = [self analysisResultSet:result];
        if (array.count > 0) {
            
            ipaModel = array[0];
        }
        [fmdb close];
    }];
    return ipaModel;
}

/* FIXME:修改数据 */
- (void)changeByBBGPayModel:(BBGPayModel *)BBGPayModel{
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        BBGPayModel.updateTime = [PublicMethod nowTime]; ;
        NSString *sql = [self getUpdateBBGPayModelSql:BBGPayModel];
        [self checkOpen];
        BOOL isAddSuccess = [fmdb executeUpdate:sql,
                             BBGPayModel.o_memberId,
                             BBGPayModel.o_payTransactionsId,
                             BBGPayModel.o_orderNo,
                             
//                             BBGPayModel.t_uuid,
                             @(BBGPayModel.t_transactionState),
                             BBGPayModel.t_transactionReceipt,
                             BBGPayModel.t_sign,
                             BBGPayModel.t_transactionIdentifier,
                             
                             BBGPayModel.createTime,
                             BBGPayModel.updateTime
                             ];
    
        if(!isAddSuccess) {
            
            NSLog(@"==fmdb=======  修改信息失败  %@ ",fmdb.lastErrorMessage);
        }else{
            
            NSLog(@"==fmdb=======  修改信息成功   ");
        }
        [fmdb close];
    }];
}

/* FIXME:删除数据 */
- (void) deleteByBBGPayModel:(BBGPayModel *)bbgPayModel{
    
    [self deleteById:bbgPayModel.iap_id];
}
- (void) deleteById:(NSInteger )iapId {
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        [self checkOpen];
        
        NSString *sql = [NSString stringWithFormat:@"delete from %@ where iap_id = %ld ",table_iap,iapId];
        BOOL isSuccess = [fmdb executeUpdate:sql];
        if(!isSuccess) {
            
            NSLog(@"==fmdb=======  删除失败  %@ ",fmdb.lastErrorMessage);
        }else{
            
            NSLog(@"==fmdb=======  删除成功   ");
        }
        [fmdb close];
    }];
}


#pragma mark - orther func

- (NSMutableArray *) getAllProperty:(Class) class{
    
    NSMutableArray *array = [NSMutableArray new];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(class, &count);
    for(int i = 0; i < count; i++){
        
        objc_property_t property = properties[i];
        //取得属性名
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        [array addObject:[NSString stringWithFormat:@"%@",propertyName]];
    }
    free(properties);
    if (array.count>0) {
        [array removeObjectAtIndex:0]; // 去掉 主键
    }
    return  array;
}

- (NSString *)getInsertSql:(NSMutableArray *)arrayProperty withTableName:(NSString *)tb_name{
    
    
    NSMutableArray *sqlArray = [[NSMutableArray alloc] init];
    
    [sqlArray addObject:insert_start(tb_name)];
    
    for (NSString *property in arrayProperty) {
        
        [sqlArray addObject:[property stringByAppendingString:@","]];
    }
    
    [sqlArray addObject:@") values("];
    
    for (int i = 0; i < arrayProperty.count; i ++) {
        
        [sqlArray addObject:@"?,"];
    }
    [sqlArray addObject:@")"];
    
    NSString *sql = @"";
    for (NSString *item in sqlArray) {
        
        sql = [sql stringByAppendingString:item];
    }
    
    sql = [sql stringByReplacingOccurrencesOfString:@",)" withString:@")"];
    NSLog(@"==fmdb======= sql = %@",sql);
    
    return  sql;
}

- (NSString *)getUpdateBBGPayModelSql:(BBGPayModel*)BBGPayModel {
    
    
    NSMutableArray *arrayProperty =  [self getAllProperty:[BBGPayModel class]];
    
    NSMutableArray *sqlArray = [[NSMutableArray alloc] init];
    
    [sqlArray addObject:update_(table_iap)]; //update %@ set
    
    for (NSString *property in arrayProperty) {
        
        NSString *string = [NSString stringWithFormat:@"%@ = ?",property];
        [sqlArray addObject:[string stringByAppendingString:@","]];
    }
    NSString *whereString = [NSString stringWithFormat:@" where iap_id = %ld",BBGPayModel.iap_id];
    [sqlArray addObject:whereString];
    
    NSString *sql = @"";
    for (NSString *item in sqlArray) {
        
        sql = [sql stringByAppendingString:item];
    }
    
    sql = [sql stringByReplacingOccurrencesOfString:@", where" withString:@" where"];
    NSLog(@"==fmdb=======  sql = %@",sql);
    
    return  sql;
}

/* FIXME:解析数据 */
- (NSMutableArray *)analysisResultSet:(FMResultSet *)result{
    
    NSMutableArray *array = [NSMutableArray new];
    while([result next]) {
      
        BBGPayModel *paymodel = [[BBGPayModel alloc] init];
        paymodel.iap_id                 = [[result stringForColumn:@"iap_id"] integerValue];
        paymodel.o_memberId             = [result stringForColumn:@"o_memberId"];
        paymodel.o_payTransactionsId    = [result stringForColumn:@"o_payTransactionsId"] ;
        paymodel.o_orderNo              = [result stringForColumn:@"o_orderNo"];
//        BBGPayModel.t_uuid                 = [result stringForColumn:@"t_uuid"];
        paymodel.t_transactionReceipt   = [result stringForColumn:@"t_transactionReceipt"];
        paymodel.t_transactionState     = [[result stringForColumn:@"t_transactionState"] integerValue];
        paymodel.t_transactionIdentifier = [result stringForColumn:@"t_transactionIdentifier"];
        paymodel.updateTime             = [result stringForColumn:@"updateTime"];
        paymodel.createTime             = [result stringForColumn:@"createTime"];
        [array addObject:paymodel];
    }
    return  array;
}

@end
