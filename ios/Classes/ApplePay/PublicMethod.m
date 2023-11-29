//
//  PublicMethod.m
//  Runner
//
//  Created by Lily on 2023/3/1.
//

#import "PublicMethod.h"

@implementation PublicMethod

+ (NSString *)nowTime {
    //获取当前时间日期
    NSDate *date=[NSDate date];
    NSDateFormatter *format1=[[NSDateFormatter alloc] init];
    [format1 setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    return [format1 stringFromDate:date];
}

+ (CGFloat )getLableWidthString:(NSString *)string withFont:(UIFont *)font {
    
    CGFloat width =[string boundingRectWithSize:CGSizeMake(1000, font.pointSize) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:font} context:nil].size.width;
    return width;
}


@end
