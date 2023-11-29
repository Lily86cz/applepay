//
//  PublicMethod.h
//  Runner
//
//  Created by Lily on 2023/3/1.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN


/// 公共方法
@interface PublicMethod : NSObject


/// 当前时间
+ (NSString *)nowTime;

/// 根据字符串获取文字宽度
+ (CGFloat )getLableWidthString:(NSString *)string withFont:(UIFont *)font;


@end

NS_ASSUME_NONNULL_END
