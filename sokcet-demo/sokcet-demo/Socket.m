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
#import <sys/types.h>
#import <sys/sysctl.h>
#import <pthread.h>

#import "Packet.h"


static struct {
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    CFRunLoopRef runloop;
} controller;

static void *controller_main(void *info)
{
    pthread_setname_np("me.kinghub.socket.controller");

    pthread_mutex_lock(&controller.mutex);
    controller.runloop = CFRunLoopGetCurrent();
    pthread_mutex_unlock(&controller.mutex);
    pthread_cond_signal(&controller.cond);

    CFRunLoopSourceContext context;
    bzero(&context, sizeof(context));

    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(controller.runloop, source, kCFRunLoopDefaultMode);

    CFRunLoopRun();

    CFRunLoopRemoveSource(controller.runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);

    pthread_mutex_destroy(&controller.mutex);
    pthread_cond_destroy(&controller.cond);

    return NULL;
}

static CFRunLoopRef controller_get_runloop()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_mutex_init(&controller.mutex, NULL);
        pthread_cond_init(&controller.cond, NULL);
        controller.runloop = NULL;

        pthread_create(&controller.thread, NULL, controller_main, NULL);

        pthread_mutex_lock(&controller.mutex);
        if (controller.runloop == NULL) {
            pthread_cond_wait(&controller.cond, &controller.mutex);
        }
        pthread_mutex_unlock(&controller.mutex);
    });

    return controller.runloop;
}

@interface Socket ()<NSStreamDelegate>
@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, assign) uint32 port;
@property (nonatomic, copy) NSString *host;
@end

@implementation Socket
- (void)dealloc {
    [self closeReadStream];
    [self closeWriteStream];
#if DEBUG
    NSLog(@"[%@ dealloc]", NSStringFromClass(self.class));
#endif
}
- (instancetype)initWithHost:(NSString *)host port:(uint32)port {
    if (self == [super init]) {
        self.host = host.copy;
        self.port = port;
    }
    return self;
}

- (void)open {

    NSInputStream *readStream = nil;
    NSOutputStream *writeStream = nil;
    [NSStream getStreamsToHostWithName:self.host
                                  port:self.port
                           inputStream:&readStream
                          outputStream:&writeStream];

    if (readStream && writeStream) {
        self.readStream = readStream;
        self.writeStream = writeStream;
        self.readStream.delegate = self;
        self.writeStream.delegate = self;

        [self openReadStream];
        [self openWriteStream];
    }
}
- (void)openReadStream {
    if (!self.readStream) return;
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.readStream;
    CFReadStreamScheduleWithRunLoop(readStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFReadStreamOpen(readStream);
}

- (void)openWriteStream {
    if (!self.writeStream) return;
    CFWriteStreamRef writeStream = (__bridge CFWriteStreamRef)self.writeStream;
    CFWriteStreamScheduleWithRunLoop(writeStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFWriteStreamOpen(writeStream);
}
- (void)closeReadStream {
    if (!self.readStream) return;
    CFReadStreamRef readStream = (__bridge CFReadStreamRef)self.readStream;
    CFReadStreamUnscheduleFromRunLoop(readStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFReadStreamClose(readStream);
    self.readStream.delegate = nil;
    self.readStream = nil;
}

- (void)closeWriteStream {
    if (!self.writeStream) return;
    CFWriteStreamRef writeStream = (__bridge CFWriteStreamRef)self.writeStream;
    CFWriteStreamUnscheduleFromRunLoop(writeStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFWriteStreamClose(writeStream);
    self.writeStream.delegate = nil;
    self.writeStream = nil;
}
- (void)send:(const void *)data length:(int16_t)len {

    if (self.writeStream.hasSpaceAvailable) {
        Packet* packet = packet_init(data, len);
        void *buffer = NULL;
        packet_pack(&buffer, packet);
        NSInteger writeLen = [self.writeStream write:buffer maxLength:packet->packetlen];
        NSLog(@"写入: %ld", writeLen);
    }
}
#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode == NSStreamEventErrorOccurred) {
        NSLog(@"%@", aStream.streamError);
    }
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
//            NSLog(@"ReadStream NSStreamEventOpenCompleted");
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
//            NSLog(@"ReadStream NSStreamEventHasBytesAvailable");
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
                dataLen = NSSwapBigShortToHost(dataLen);
                // 读取数据内容
                int32_t checksum = 0;
                memcpy(&checksum, buffer + 4, 4);
                checksum = NSSwapBigIntToHost(checksum);
                char contentBuffer[dataLen - 8];
                memcpy(contentBuffer, buffer + 8, dataLen - 8);
                uint32 verifyChecksum = (uint32)adler32(1, (const void *)contentBuffer, dataLen);
                if (verifyChecksum == checksum) {
                    NSString *content = [[NSString alloc] initWithData:[NSData dataWithBytes:contentBuffer length:dataLen - 8] encoding:NSUTF8StringEncoding];
                    NSLog(@"数据校验成功 content: %@", content);
                } else {
                    NSLog(@"数据校验失败");
                }
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
//            NSLog(@"ReadStream NSStreamEventHasSpaceAvailable");
            break;
        }
        case NSStreamEventErrorOccurred:
        {
//            NSLog(@"ReadStream NSStreamEventErrorOccurred");
            break;
        }
        case NSStreamEventEndEncountered:
        {
//            NSLog(@"ReadStream NSStreamEventEndEncountered");
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
//            NSLog(@"WriteStream NSStreamEventOpenCompleted");
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
//            NSLog(@"WriteStream NSStreamEventHasBytesAvailable");
            break;
        }
        case NSStreamEventHasSpaceAvailable:
        {
//            NSLog(@"WriteStream NSStreamEventHasSpaceAvailable");
//            NSData *data = [self DataForAuthreq];
//            NSInteger len = [self.writeStream write:data.bytes maxLength:data.length];
//            NSLog(@"写入: %ld", len);
//            len = [self.writeStream write:data.bytes maxLength:data.length];
//            NSLog(@"写入: %ld", len);
//            len = [self.writeStream write:data.bytes maxLength:data.length];
//            NSLog(@"写入: %ld", len);
//            sleep(5);
            break;
        }
        case NSStreamEventErrorOccurred:
        {
//            NSLog(@"WriteStream NSStreamEventErrorOccurred");
            break;
        }
        case NSStreamEventEndEncountered:
        {
//            NSLog(@"WriteStream NSStreamEventEndEncountered");
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
