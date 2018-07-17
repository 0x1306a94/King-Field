//
//  Packet.h
//  sokcet-demo
//
//  Created by sun on 2018/7/17.
//  Copyright © 2018年 king. All rights reserved.
//

#ifndef Packet_h
#define Packet_h

#include <stdlib.h>

// 固定头 V1 (2字节) + data length (2字节 数据长度) + checksum (4字节 adler32 校验算法值) + data

extern const int PacketHeaderSize;

typedef struct {
    char       version[2];
    int16_t    datalen;
    uint32_t   checksum;
    void*      data;

    int16_t    packetlen;
} Packet;

Packet* packet_init(const void *__data, int16_t dataLen);

void packet_set(Packet* packet, const void *__data, int16_t dataLen);

void packet_pack(void **__data, Packet* packet);

void packet_upack(Packet** packet, const void *__data);

void packet_reset(Packet* packet);
#endif /* Packet_h */
