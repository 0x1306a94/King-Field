//
//  SocketPacket.h
//  sokcet-demo
//
//  Created by sun on 2018/7/18.
//  Copyright © 2018年 king. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SocketPacket : NSObject
// 固定值 V1
@property (nonatomic, strong, readonly) NSString *version;
@property (nonatomic, assign, readonly) int16_t packetlen;
@property (nonatomic, assign, readonly) int16_t datalen;
@property (nonatomic, assign, readonly) uint32_t checksum;
@property (nonatomic, strong, readonly) NSData *data;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithData:(NSData * _Nonnull)data;
- (instancetype)initWithData:(const void * _Nonnull)data datalen:(int16_t)datalen NS_DESIGNATED_INITIALIZER;
+ (instancetype)decodWithData:(NSData * _Nonnull)data;

- (void)encodeWithData:(NSData * _Nonnull * _Nullable)data;

- (BOOL)verifyPacket;
@end
NS_ASSUME_NONNULL_END
