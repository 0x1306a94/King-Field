//
//  main.m
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Socket.h"


int main(int argc, const char * argv[]) {

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        static Socket *socket = nil;
        socket = [[Socket alloc] initWithHost:@"127.0.0.1" port:8800];
        NSLog(@"start open....");
        [socket open];
    });

    [[NSRunLoop mainRunLoop] run];
    return 0;
}
