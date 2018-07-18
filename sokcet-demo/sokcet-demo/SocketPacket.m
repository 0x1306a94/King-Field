//
//  SocketPacket.m
//  sokcet-demo
//
//  Created by sun on 2018/7/18.
//  Copyright © 2018年 king. All rights reserved.
//

#import "SocketPacket.h"
#import <zlib.h>

@interface SocketPacket ()
@property (nonatomic, strong) NSString *version;
@property (nonatomic, assign) int16_t packetlen;
@property (nonatomic, assign) int16_t datalen;
@property (nonatomic, assign) uint32_t checksum;
@property (nonatomic, strong) NSData *data;
@end

@implementation SocketPacket

- (instancetype)initWithData:(NSData * _Nonnull)data {
    if (!data) return nil;
    return [self initWithData:data.bytes datalen:data.length];
}

- (instancetype)initWithData:(const void * _Nonnull)data datalen:(int16_t)datalen {
    if (self == [super init]) {
        self.version = @"V1";
        self.packetlen = 8 + datalen;
        self.datalen = datalen;
        self.checksum = (uint32_t)adler32(1, (const Bytef *)data, (uInt)datalen);
        self.data = [NSData dataWithBytes:data length:datalen];
    }
    return self;
}

+ (instancetype)decodWithData:(NSData * _Nonnull)data {
    if (!data) return nil;
    SocketPacket *packet = [[SocketPacket.class alloc] init];
    char *version = (char *)malloc(sizeof(char) * 2);
    memcpy(version, data.bytes, 2);
    packet.version = [NSString stringWithCString:version encoding:NSUTF8StringEncoding];
    int16_t datalen = 0;
    memcpy(&datalen, data.bytes + 2, 2);
    datalen = NSSwapBigShortToHost(datalen);
    packet.datalen = datalen;

    uint32_t checksum = 0;
    memcpy(&checksum, data.bytes + 4, 4);
    checksum = NSSwapBigIntToHost(checksum);
    packet.checksum = checksum;

    void *dataBuffer = (void *)malloc(packet.datalen);
    memcpy(dataBuffer, data.bytes + 8, packet.datalen);
    packet.data = [NSData dataWithBytes:dataBuffer length:packet.datalen];
    packet.packetlen = 8 + packet.datalen;
    free(dataBuffer);
    return packet;
}

- (void)encodeWithData:(NSData * _Nonnull * _Nullable)data {
    void *buffer = (void *)malloc(self.packetlen);
    memset(buffer, 0, self.packetlen);
    strcpy(buffer, self.version.UTF8String);
    int16_t length = NSSwapHostShortToBig(self.datalen);
    memcpy(buffer + 2, &length, 2);
    uint32_t checksum = NSSwapHostIntToBig(self.checksum);
    memcpy(buffer + 4, &checksum, 4);
    memcpy(buffer + 8, self.data.bytes, self.datalen);
    *data = [NSData dataWithBytes:buffer length:self.packetlen];
    free(buffer);
}
- (BOOL)verifyPacket {
    uint32_t checksum = (uint32_t)adler32(1, (const Bytef *)self.data.bytes, (uInt)self.datalen);
    return self.checksum == checksum;
}

- (NSString *)debugDescription {
    NSString *dataString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:
            @"\nversion: %@"
            @"\npacketlen: %@"
            @"\ndatalen: %@"
            @"\nchecksum: %@"
            @"\ndata: %@\n",
            self.version,
            @(self.packetlen).stringValue,
            @(self.datalen).stringValue,
            @(self.checksum).stringValue,
            dataString ?: @""];
}
@end
