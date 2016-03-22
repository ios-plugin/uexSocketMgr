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
#import "EUExSocketMgr.h"




@interface EUExSocket : NSObject <AsyncSocketDelegate,AsyncUdpSocketDelegate>

@property (nonatomic,weak)EUExSocketMgr *euexObj;
@property (nonatomic,strong)AsyncUdpSocket *UDPClient;
@property (nonatomic,strong)AsyncSocket *TCPClient;
@property (nonatomic,strong)NSData *xml;
@property (nonatomic,assign)NSInteger opID;
@property (nonatomic,strong)NSString *Host;
@property (nonatomic,assign)uexSocketMgrSocketType socketType;
@property (nonatomic,assign)NSInteger Port;
@property (nonatomic,assign)NSInteger localPort;
@property (nonatomic,assign)NSInteger timeOutInter;
@property (nonatomic,assign)uexSocketMgrDataType dataType;


- (instancetype)initWithEUExObj:(EUExSocketMgr *)euexObj socketType:(uexSocketMgrSocketType)socketType;


- (BOOL)connectServer:(NSString *) hostIP port:(UInt16)hostPort;
- (void)sendMsg:(NSString *) msg;
//-(void)setSocketTimeOut;
- (void)closeSocket:(NSInteger)inOpId;
- (BOOL)creatUDPSocketWithPort:(UInt16)port;
@end
