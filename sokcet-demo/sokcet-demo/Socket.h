//
//  Socket.h
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface Socket : NSObject
@property (nonatomic, assign, readonly) uint32 port;
@property (nonatomic, copy, readonly) NSString *host;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithHost:(NSString *)host port:(uint32)port NS_DESIGNATED_INITIALIZER;
- (void)open;

- (void)send:(const void *)data length:(int16_t)len;
@end
