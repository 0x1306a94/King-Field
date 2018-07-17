//
//  Packet.c
//  sokcet-demo
//
//  Created by sun on 2018/7/17.
//  Copyright © 2018年 king. All rights reserved.
//

#include "Packet.h"

#include <stdio.h>
#include <zlib.h>
#include <libkern/OSByteOrder.h>

// 固定头 V1 (2字节) + data length (2字节 数据长度) + checksum (4字节 adler32 校验算法值) + data

const int PacketHeaderSize = 8;

Packet* packet_init(const void *__data, int16_t dataLen) {
    Packet *packet = (Packet *)malloc(sizeof(Packet));
    packet_set(packet, __data, dataLen);
    return packet;
}

void packet_set(Packet* packet, const void *__data, int16_t dataLen) {
    if (packet == NULL) return;
    packet->version[0] = 'V';
    packet->version[1] = '1';
    packet->datalen = dataLen;
    packet->checksum = (uint32_t)adler32(1, __data, (uInt)dataLen);
    packet->packetlen = PacketHeaderSize + packet->datalen;
    packet->data = (void *)malloc(dataLen);
    memset(packet->data, 0, dataLen);
    memcpy(packet->data, __data, dataLen);
}

void packet_pack(void **__data, Packet* packet) {
    *__data = (void *)malloc(packet->datalen);
    memset(*__data, 0, packet->datalen);
    memcpy(*__data, packet->version, 2);
    int16_t length = OSSwapHostToBigInt16(packet->datalen);
    memcpy(*__data + 2, &length, 2);
    uint32_t checksum = OSSwapHostToBigInt32(packet->checksum);
    memcpy(*__data + 4, &checksum, 4);
    memcpy(*__data + PacketHeaderSize, packet->data, packet->datalen);
}

void packet_upack(Packet** packet, const void *__data) {
    *packet = (Packet *)malloc(sizeof(Packet));
    memcpy((*packet)->version, __data, 2);
    memcpy(&((*packet)->datalen), __data + 2, 2);
    memcpy(&((*packet)->checksum), __data + 4, 4);
    (*packet)->datalen = OSSwapBigToHostInt16((*packet)->datalen);
    (*packet)->checksum = OSSwapBigToHostInt32((*packet)->checksum);
    (*packet)->packetlen = PacketHeaderSize + (*packet)->datalen;
    (*packet)->data = (void *)malloc((*packet)->datalen);
    memset((*packet)->data, 0, (*packet)->datalen);
    memcpy((*packet)->data, __data + PacketHeaderSize, (*packet)->datalen);
}

void packet_reset(Packet* packet) {
    if (packet == NULL) return;
    bzero(packet, sizeof(Packet));
}
