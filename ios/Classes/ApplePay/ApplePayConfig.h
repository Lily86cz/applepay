//
//  ApplePayConfig.h
//  Runner
//
//  Created by Lily on 2023/3/1.
//

#ifndef ApplePayConfig_h
#define ApplePayConfig_h

#import "PublicMethod.h"



#define WeakObj(obj) __weak typeof(obj) obj##Weak = obj

CG_INLINE NSString *convertToJSONData(id infoDict) {
    
    if ([infoDict isKindOfClass:[NSDictionary class]]) {
           
           NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithDictionary:infoDict];
           
           for (NSString *key in info.allKeys) {
               
               id value = [info objectForKey:key];
               if (!([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]])) {
                   
                   [info removeObjectForKey:key];
               }
           }
           
           NSError *error;
           NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                              options:NSJSONWritingPrettyPrinted
                                                                error:&error];
           
           NSString *jsonString = @"";
           
           if (! jsonData)
           {
               NSLog(@"Got an error: %@", error);
           }else
           {
               jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
           }
           
           jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  //去除掉首尾的空白字符和换行字符
           
           [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
           
           return jsonString;
       }
       return @"未知";

}


/* FIXME: -  字典转json格式字符串*/
CG_INLINE NSString *dictionaryToJson(NSDictionary *dic){
    
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
/* FIXME: -  判断字典包不包含某个key*/
CG_INLINE id handleNullObjectForKey(NSDictionary *item,NSString *key) {
    
    id object = [item objectForKey:key];
    if ([object isKindOfClass:[NSNull class]]) {
        return nil;
    }
    return object;
}
/* FIXME: -  颜色*/
CG_INLINE UIColor *getColor(NSString *hexColor) { // hexColor 是 #FFFFFF  或者 FFFFFF 样式
    
    if (hexColor.length>0 && ( hexColor.length == 7 || hexColor.length == 6) ) {
        
        if (hexColor.length == 7 && [[hexColor substringToIndex:1] isEqualToString:@"#"]) {
            
            hexColor = [hexColor substringFromIndex:1];
        }
        unsigned int red,green,blue;
        NSRange range;
        range.length = 2;
        
        range.location = 0;
        [[NSScanner scannerWithString:[hexColor substringWithRange:range]] scanHexInt:&red];
        
        range.location = 2;
        [[NSScanner scannerWithString:[hexColor substringWithRange:range]] scanHexInt:&green];
        
        range.location = 4;
        [[NSScanner scannerWithString:[hexColor substringWithRange:range]] scanHexInt:&blue];
        
        return [UIColor colorWithRed:(float)(red/255.0f) green:(float)(green / 255.0f) blue:(float)(blue / 255.0f) alpha:1.0f];
        
    }else{
        
        return [UIColor whiteColor];
    }
}


// 内购
#define Key_orderInfo           @"Key_orderInfo"      //内购补偿机制
#define Key_payBackFail         @"Key_payBackFail"
#define Key_userNo              @"Key_userNo"      //用户no
#define Key_logList             @"Key_logList"      //日志清单
#define Key_payInfo             @"Key_payInfo"      //flutter传过来的用于缓存
#define applePay                @"APPLEPAY"

#define payUrlApi               @"/api/pay/v2/applePay/success" // 支付接口


#define initApplePay @"initApplePay" // 开始初始化苹果支付
#define applePayStartToPay @"applePayStartToPay" // 开始苹果支付
#define restoreApplePay @"restoreApplePay" // 点击恢复购买下单


#endif /* ApplePayConfig_h */
