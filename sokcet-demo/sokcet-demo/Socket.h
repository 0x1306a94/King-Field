//
//  Socket.h
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SocketDelegate;

@class SocketPacket;

@interface Socket : NSObject
@property (nonatomic, assign, readonly) uint32 port;
@property (nonatomic, copy, readonly) NSString *host;

@property (nonatomic, weak) id<SocketDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithHost:(NSString *)host port:(uint32)port;
- (instancetype)initWithHost:(NSString *)host port:(uint32)port timeout:(NSTimeInterval)timeout NS_DESIGNATED_INITIALIZER;
- (void)connection;

- (void)sendData:(NSData *)data;
- (void)sendPacket:(SocketPacket *)packet;
@end


@protocol SocketDelegate <NSObject>

@optional
- (void)sokcet:(Socket *)sokcet didConnectionHost:(NSString *)host port:(uint32)port;
- (void)socketConnectionTimeout:(Socket *)sokcet;
- (void)socketDisconnection:(Socket *)sokcet;
- (void)sokcet:(Socket *)sokcet didReceivePacket:(SocketPacket *)packet;
- (void)sokcet:(Socket *)sokcet didError:(NSError *)error;
@end
