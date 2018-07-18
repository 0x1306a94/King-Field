//
//  main.m
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Socket.h"
#import "Packet.h"
#import "SocketPacket.h"

@interface SocketHandler : NSObject<SocketDelegate>

@end


@implementation SocketHandler
- (void)sokcet:(Socket *)sokcet didConnectionHost:(NSString *)host port:(uint32)port {
    NSLog(@"connection to %@:%d", host, port);
}
- (void)socketDisconnection:(Socket *)sokcet {
    NSLog(@"disconnection");
}
- (void)socketConnectionTimeout:(Socket *)sokcet {
    NSLog(@"connection timeout");
}
- (void)sokcet:(Socket *)sokcet didError:(NSError *)error {
    NSLog(@"socket error: %@", error);
}
- (void)sokcet:(Socket *)sokcet didReceivePacket:(SocketPacket *)packet {
    NSLog(@"%@", [packet debugDescription]);
    if ([packet verifyPacket]) {
        NSLog(@"数据校验成功");
    } else {
        NSLog(@"数据校验失败");
    }
}
@end

int main(int argc, const char * argv[]) {

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static Socket *socket = nil;
        static SocketHandler *handelr = nil;
        handelr = [SocketHandler new];
        socket = [[Socket alloc] initWithHost:@"localhost" port:8800];
        NSLog(@"start connection....");
        socket.delegate = handelr;
        [socket connection];
        sleep(10);
        NSString *str = @"你大爷的,总算调通了!妈蛋的";
        NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
        [socket sendData:data];
    });

    [[NSRunLoop mainRunLoop] run];
    return 0;
}
