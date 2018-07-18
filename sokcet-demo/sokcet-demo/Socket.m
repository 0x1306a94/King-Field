//
//  Socket.m
//  sokcet-demo
//
//  Created by sun on 2018/5/22.
//  Copyright © 2018年 king. All rights reserved.
//

#import "Socket.h"
#import "SocketPacket.h"
#import "Packet.h"

#import <zlib.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <netdb.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <pthread.h>


#define kBUFFER_MAX_LENGHT  1024
#define kDEFAULT_CONNECT_TIMEOUT    30.0

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

///根据域名获取ip地址 - 可以用于控制APP的开关某一个入口，比接口方式速度快的多
static NSArray<NSString *> * getIPWithHostName(const NSString *hostName) {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    const char *hostN= [hostName UTF8String];
    struct hostent *phot;
    @try {
        phot = gethostbyname(hostN);
    } @catch (NSException *exception) {
        return nil;
    }
    if (phot == NULL) {
        return nil;
    }
    NSMutableArray<NSString *> *ips = [NSMutableArray<NSString *> array];
    char **pptr;
    for (pptr = phot->h_addr_list; *pptr != NULL; pptr++) {
        char ip[20] = {0};
        inet_ntop(phot->h_addrtype, *pptr, ip, sizeof(ip));
        NSString *strIPAddress = [NSString stringWithUTF8String:ip];
        [ips addObject:strIPAddress];
    }
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    NSLog(@"=== ip === %@ === time cost: %0.3fs", ips,end - start);
    return ips.copy;
}

@interface Socket ()<NSStreamDelegate>
{
    struct {
        unsigned int didConnection :1;
        unsigned int disconnection :1;
        unsigned int connctionTimeout :1;
        unsigned int didReceivePacket :1;
        unsigned int didError :1;
    } delegateFlags;
}
@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, assign) uint32 port;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, strong) NSString *connectionIP;
@property (nonatomic, assign) BOOL connectionState;

@property (nonatomic, weak) NSTimer *heartbeatTimer;
@end

@implementation Socket

- (void)dealloc {
    [self dissconnection];
#if DEBUG
    NSLog(@"[%@ dealloc]", NSStringFromClass(self.class));
#endif
}
- (instancetype)initWithHost:(NSString *)host port:(uint32)port {
    return [self initWithHost:host port:port timeout:kDEFAULT_CONNECT_TIMEOUT];
}
- (instancetype)initWithHost:(NSString *)host port:(uint32)port timeout:(NSTimeInterval)timeout {
    if (self == [super init]) {
        self.host = host.copy;
        self.port = port;
        self.timeout = timeout;
        self.connectionState = NO;
    }
    return self;
}

- (void)connection {

    NSInputStream *readStream = nil;
    NSOutputStream *writeStream = nil;
    NSString *host = self.host;
    NSArray<NSString *> *ips = getIPWithHostName(host);
    if (!ips || ips.count == 0) return;
    self.connectionIP = ips.firstObject;
    [NSStream getStreamsToHostWithName:ips.firstObject
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
    if (self.timeout > 0) {
        [self performSelector:@selector(connectionTimeout) withObject:nil afterDelay:self.timeout];
    }
}
- (void)dissconnection {
    [self __disconnection:YES];
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
- (void)sendData:(NSData *)data {
    if (!data || !self.writeStream.hasSpaceAvailable || !self.connectionState) return;
    SocketPacket *packet = [[SocketPacket alloc] initWithData:data];
    [self sendPacket:packet];
}
- (void)sendPacket:(SocketPacket *)packet {
    if (!packet || !self.writeStream.hasSpaceAvailable || !self.connectionState) return;
    NSData *sendData = nil;
    [packet encodeWithData:&sendData];
    if ([self.writeStream write:sendData.bytes maxLength:sendData.length] == -1) {
        [self didError:self.writeStream.streamError];
    }
}
#pragma mark - Rewrite Setter
- (void)setDelegate:(id<SocketDelegate>)delegate {
    _delegate = delegate;
    self->delegateFlags.didConnection = [delegate respondsToSelector:@selector(sokcet:didConnectionHost:port:)];
    self->delegateFlags.disconnection = [delegate respondsToSelector:@selector(socketDisconnection:)];
    self->delegateFlags.didReceivePacket = [delegate respondsToSelector:@selector(sokcet:didReceivePacket:)];
    self->delegateFlags.connctionTimeout = [delegate respondsToSelector:@selector(socketConnectionTimeout:)];
    self->delegateFlags.didError = [delegate respondsToSelector:@selector(sokcet:didError:)];
}
- (void)connectionTimeout {
    if (self->delegateFlags.connctionTimeout) {
        [self.delegate socketConnectionTimeout:self];
    }
    [self __disconnection:NO];
}
#pragma mark - Call Delegate
- (void)__connectionSuccessful {
    self.connectionState = self.readStream.streamStatus == NSStreamStatusOpen && self.writeStream.streamStatus == NSStreamStatusOpen;
    if (self.connectionState) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeout) object:nil];
        [self cretaeHeartbeatTimer];
        if (self->delegateFlags.didConnection) {
            [self.delegate sokcet:self didConnectionHost:self.connectionIP port:self.port];
        }
    }
}
- (void)__disconnection:(BOOL)needCallDelegate {
    if (!self.connectionState) return;
    [self closeReadStream];
    [self closeWriteStream];
    self.connectionState = NO;
    [self invalidateHeartbeatTimer];
    if (self->delegateFlags.disconnection && needCallDelegate) {
        [self.delegate socketDisconnection:self];
    }
}
- (void)didError:(NSError *)error {
    if (!error || !self->delegateFlags.didError) return;
    [self.delegate sokcet:self didError:error];
}
- (void)didReceivePacket:(SocketPacket *)packet {
    if (self->delegateFlags.didReceivePacket) {
        [self.delegate sokcet:self didReceivePacket:packet];
    }
}
#pragma mark - Heartbeat Timer
- (void)cretaeHeartbeatTimer {
    if (self.heartbeatTimer) return;
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                           target:self
                                                         selector:@selector(heartbeatTimerHandler)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.heartbeatTimer forMode:NSDefaultRunLoopMode];
}
- (void)invalidateHeartbeatTimer {
    if (!self.heartbeatTimer) return;
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
}
- (void)heartbeatTimerHandler {
    SocketPacket *packet = [[SocketPacket alloc] initWithData:[@"heartbeat" dataUsingEncoding:NSUTF8StringEncoding]];
    [self sendPacket:packet];
}

#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            if (!self.connectionState) {
                [self __connectionSuccessful];
            }
            break;
        case NSStreamEventEndEncountered:
            [self dissconnection];
            break;
        case NSStreamEventErrorOccurred:
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeout) object:nil];
            [self __disconnection:NO];
            [self didError:aStream.streamError];
            break;
        default:
            break;
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
    if (eventCode == NSStreamEventHasBytesAvailable) {
        @autoreleasepool {
            NSMutableData *data = [NSMutableData data];
            int16_t dataLen = 0;
            while ([self.readStream hasBytesAvailable]) {
                uint8_t buffer[kBUFFER_MAX_LENGHT];
                memset(buffer, 0, kBUFFER_MAX_LENGHT);
                NSInteger len = [self.readStream read:buffer maxLength:kBUFFER_MAX_LENGHT];
                if (len <= 0) continue;

                if (buffer[0] == 'V') {
                    memcpy(&dataLen, buffer + 2, 2);
                    dataLen = NSSwapBigShortToHost(dataLen);
                    [data appendBytes:buffer length:len];
                    if (dataLen + 8 <= len) {
                        SocketPacket *packet = [SocketPacket decodWithData:data.copy];
                        [self didReceivePacket:packet];
                        data = [NSMutableData data];
                        dataLen = 0;
                    }
                } else if (dataLen > 0) {
                    NSInteger length = MIN(((dataLen + 8) - data.length), len);
                    [data appendBytes:buffer length:length];
                    if (data.length == dataLen + 8) {
                        SocketPacket *packet = [SocketPacket decodWithData:data.copy];
                        [self didReceivePacket:packet];
                        data = [NSMutableData data];
                        dataLen = 0;
                        if (length < len) {
                            // 还有数据
                            NSInteger remainingLen = len - length;
                            uint8_t tmpBuffer[remainingLen];
                            memset(tmpBuffer, 0, remainingLen);
                            memcpy(tmpBuffer, buffer + length, remainingLen);
                            if (tmpBuffer[0] == 'V') {
                                memcpy(&dataLen, tmpBuffer + 2, 2);
                                dataLen = NSSwapBigShortToHost(dataLen);
                                [data appendBytes:tmpBuffer length:remainingLen];
                                if (dataLen + 8 <= len) {
                                    SocketPacket *packet = [SocketPacket decodWithData:data.copy];
                                    [self didReceivePacket:packet];
                                    data = [NSMutableData data];
                                    dataLen = 0;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
- (void)handleWriteStreamWithEvent:(NSStreamEvent)eventCode {

}
@end
