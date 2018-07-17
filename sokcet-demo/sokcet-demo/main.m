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

int main(int argc, const char * argv[]) {



    NSString *str = @"你大爷的,总算调通了!妈蛋的";
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];

    Packet *packet = packet_init(data.bytes, data.length);
    void *buffer = NULL;
    packet_pack(&buffer, packet);
    data = [NSData dataWithBytes:packet->data length:packet->datalen];
    str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", str);

    Packet *tmp = NULL;
    packet_upack(&tmp, buffer);
    data = [NSData dataWithBytes:tmp->data length:tmp->datalen];
    str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", str);

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static Socket *socket = nil;
        socket = [[Socket alloc] initWithHost:@"127.0.0.1" port:8800];
        NSLog(@"start open....");
        [socket open];
        sleep(5);
        NSString *str = @"你大爷的,总算调通了!妈蛋的";
        NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
        [socket send:data.bytes length:data.length];
    });

    [[NSRunLoop mainRunLoop] run];
    return 0;
}
