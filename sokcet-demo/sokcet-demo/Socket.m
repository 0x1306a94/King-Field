//
//  Socket.m
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import "Socket.h"

#import <CFNetwork/CFNetwork.h>
#import <zlib.h>
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


//#define MOD 65521
//#define MAX 5552
//
//unsigned long adler32(unsigned char *buf, size_t len)
//{
//    unsigned long a = 1, b = 0;
//    size_t n;
//
//    while (len) {
//        n = len > MAX ? MAX : len;
//        len -= n;
//        do {
//            a += *buf++;
//            b += a;
//        } while (--n);
//        a %= MOD;
//        b %= MOD;
//    }
//    return a | (b << 16);
//}

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
                // 读取数据内容
                uint32 checksum = 0;
                memcpy(&checksum, buffer + 4, 4);
                if (!(NSHostByteOrder() == NS_BigEndian)) { checksum = NSSwapBigIntToHost(checksum); }
                char contentBuffer[dataLen];
                memcpy(contentBuffer, buffer + 8, dataLen+1);
                uint32 verifyChecksum = (uint32)adler32(1, (const void *)contentBuffer, dataLen);
                if (verifyChecksum == checksum) {
                    NSLog(@"数据校验成功 content: %@", [NSString stringWithCString:contentBuffer encoding:NSUTF8StringEncoding]);
                } else {
                    NSLog(@"数据校验失败");
                }
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
    NSString *content = @",麻烦啦九分裤男安居办法链接啊杯咖啡吧卡了被罚款分布筋阿附近吧家而非金坷垃过节费卡不发酵";
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    int16_t len = (int16_t)data.length;
    [senddata appendData:[header dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO]];
    len = NSSwapHostShortToBig(len);
    [senddata appendBytes:&len length:sizeof(len)];
    uint32 adler = (uint32)adler32(1, data.bytes, (uInt)data.length);
    adler = NSSwapHostIntToBig(adler);
    [senddata appendBytes:&adler length:sizeof(adler)];
    [senddata appendData:data];
    return senddata;
}
@end
