//
//  EUExSocket.h
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"
#import "AsyncUdpSocket.h"
@class EUExSocketMgr;

@interface EUExSocket : NSObject <AsyncSocketDelegate,AsyncUdpSocketDelegate>{
	AsyncSocket *tcp_client;
	AsyncUdpSocket *udp_client;
	EUExSocketMgr *UExObj;
	NSString *opID;
	NSInteger sockType;
	NSInteger Port;
	NSInteger timeOutInter;
	NSString *Host;
	NSInteger localPort;
}

@property (nonatomic, retain)AsyncUdpSocket *udp_client;
@property (nonatomic,retain)AsyncSocket *tcp_client;
@property (nonatomic,retain)NSData *xml;
@property (nonatomic,retain)NSString *opID;
@property (nonatomic, retain)NSString *Host;
@property NSInteger sockType;
@property NSInteger Port;
@property NSInteger localPort;
@property NSInteger timeOutInter;
@property NSInteger dataType;

- (id) initWithUExObj:(EUExSocketMgr *)UExObj_ socketType:(int)socketType_;
- (BOOL) connectServer:(NSString *) hostIP port:(int) hostPort;
- (void) sendMsg:(NSString *) msg;
//-(void)setSocketTimeOut;
- (NSInteger)CloseSocket:(NSString *)inOpId;
- (BOOL)creatUDPSocketWithPort:(int )port;
@end
