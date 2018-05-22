//
//  Socket.m
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import "Socket.h"

#import <CFNetwork/CFNetwork.h>

//#define isBigEndian \
//({ \
//    BOOL flag = NO; \
//    int a = 0x1234; \
//    flag = (*(char *)&a == 0x12); \
//    flag; \
//})

/**
 *  @brief 64位数据高度和低地址的交换
 *
 *  @param A 值
 *
 *  @return 返回结果
 */

#define BigSwapLittle64(A)      (A) = ((((uint64)(A) & 0xff00000000000000) >> 56) | \
(((uint64)(A) & 0x00ff000000000000) >> 40) | \
(((uint64)(A) & 0x0000ff0000000000) >> 24) | \
(((uint64)(A) & 0x000000ff00000000) >> 8) | \
(((uint64)(A) & 0x00000000ff000000) << 8) | \
(((uint64)(A) & 0x0000000000ff0000) << 24) | \
(((uint64)(A) & 0x000000000000ff00) << 40) | \
(((uint64)(A) & 0x00000000000000ff) << 56))

/**
 *  @brief 32位数据高度和低地址的交换
 *
 *  @param A 值
 *
 *  @return 返回结果
 */

#define BigSwapLittle32(A)      (A) = ((((uint32)(A) & 0xff000000) >> 24) | \
(((uint32)(A) & 0x00ff0000) >> 8) | \
(((uint32)(A) & 0x0000ff00) << 8) | \
(((uint32)(A) & 0x000000ff) << 24))

/**
 *  @brief 16位数据高度和低地址的交换
 *
 *  @param A 值
 *
 *  @return  返回结果
 */

#define BigSwapLittle16(A)      (A) = ((((uint16)(A) & 0xff00) >> 8) | \
(((uint16)(A) & 0x00ff) << 8))

@interface Socket ()<NSStreamDelegate>
@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, strong) dispatch_queue_t readQueue;
@property (nonatomic, strong) dispatch_queue_t writeQueue;
@property (nonatomic, assign) uint32 port;
@property (nonatomic, copy) NSString *host;
@end

@implementation Socket
- (instancetype)initWithHost:(NSString *)host port:(uint32)port {
    if (self == [super init]) {
        self.host = host.copy;
        self.port = port;
        self.readQueue = dispatch_queue_create("Socket readQueue", DISPATCH_QUEUE_SERIAL);
        self.writeQueue = dispatch_queue_create("Socket writeQueue", DISPATCH_QUEUE_SERIAL);
        if (NSHostByteOrder() == NS_BigEndian) {
            NSLog(@"当前是大端模式");
        } else {
            NSLog(@"当前是小端模式");
        }
    }
    return self;
}

- (void)open {

    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (__bridge CFStringRef)self.host,
                                       self.port,
                                       &readStream,
                                       &writeStream);
    if (readStream && writeStream) {
        self.readStream = CFBridgingRelease(readStream);
        self.writeStream = CFBridgingRelease(writeStream);
        self.readStream.delegate = self;
        self.writeStream.delegate = self;

        dispatch_async(self.readQueue, ^{
            [self.readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [self.readStream open];
            [[NSRunLoop currentRunLoop] run];
        });

        dispatch_async(self.writeQueue, ^{
            [self.writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [self.writeStream open];
            [[NSRunLoop currentRunLoop] run];
        });

    }


}
#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (self.readStream == aStream) {
        [self handleReadStreamWithEvent:eventCode];
    } else {
        [self handleWriteStreamWithEvent:eventCode];
    }
}
- (void)handleReadStreamWithEvent:(NSStreamEvent)eventCode {

    /*
     NSStreamEventNone = 0,
     NSStreamEventOpenCompleted = 1UL << 0,
     NSStreamEventHasBytesAvailable = 1UL << 1,
     NSStreamEventHasSpaceAvailable = 1UL << 2,
     NSStreamEventErrorOccurred = 1UL << 3,
     NSStreamEventEndEncountered = 1UL << 4
     */
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"ReadStream NSStreamEventOpenCompleted");
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            NSLog(@"ReadStream NSStreamEventHasBytesAvailable");
            uint8 buffer[1024];
            memset(buffer, 0, 1024);
            NSInteger len = [self.readStream read:buffer maxLength:1024];
            NSLog(@"读取: %ld", len);
            // 每一个完整的数据 结构为  (2字节头) + (2字节数据长度) + (数据)
            if (len >= 4 && buffer[0] == 'V') {
                int16_t dataLen = 0;
                // 取出 数据长度
                memcpy(&dataLen, buffer + 2, 2);
                // 服务器传输数据 为 大端 网络字节序, 当设备为 小端字节序 则需要将大端转为小端
                if (!(NSHostByteOrder() == NS_BigEndian)) { dataLen = NSSwapBigShortToHost(dataLen); }
                NSLog(@"dataLen: %d", dataLen);
                // 读取数据内容
                char contentBuffer[dataLen];
                memcpy(contentBuffer, buffer + 4, dataLen+1);
                NSLog(@"content: %s", contentBuffer);
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            NSLog(@"ReadStream NSStreamEventHasSpaceAvailable");
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"ReadStream NSStreamEventErrorOccurred");
            break;
        }
        case NSStreamEventEndEncountered:
        {
            NSLog(@"ReadStream NSStreamEventEndEncountered");
            break;
        }
        default:
            break;
    }
}
- (void)handleWriteStreamWithEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"WriteStream NSStreamEventOpenCompleted");
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            NSLog(@"WriteStream NSStreamEventHasBytesAvailable");
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
            NSLog(@"WriteStream NSStreamEventHasSpaceAvailable");
            NSData *data = [self DataForAuthreq];
            NSInteger len = [self.writeStream write:data.bytes maxLength:data.length];
            NSLog(@"写入: %ld", len);
            len = [self.writeStream write:data.bytes maxLength:data.length];
            NSLog(@"写入: %ld", len);
            len = [self.writeStream write:data.bytes maxLength:data.length];
            NSLog(@"写入: %ld", len);
            sleep(5);
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"WriteStream NSStreamEventErrorOccurred");
            break;
        }
        case NSStreamEventEndEncountered:
        {
            NSLog(@"WriteStream NSStreamEventEndEncountered");
            break;
        }
        default:
            break;
    }
}

-(NSMutableData *)DataForAuthreq
{
    NSMutableData * senddata = [NSMutableData new];
    NSString *header = @"V1";
    NSString *content = @"字节转卡积分卡辣椒粉控件阿卡丽很费劲啊看来发货卡夫卡拉横幅马甲本菲卡加班费可能麻痹九分裤垃圾不付款啦被罚款喇叭那几款卡饿了开发加班费解放军阿卡丽金卡节疯狂拉黑卡尔付款啦加快了福建阿来划分就爱咖啡酒吧老板发了不放卡接口里发不发腊八节福利卡被封了卡被封了卡不放辣被封了卡被封了卡办法不付款啦咖啡酒吧看两部分";
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    int16_t len = data.length;
    [senddata appendData:[header dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO]];
//    HTONS(len);
    len = NSSwapHostShortToBig(len);
    [senddata appendBytes:&len length:sizeof(len)];
    [senddata appendData:data];

    return senddata;
}
@end
