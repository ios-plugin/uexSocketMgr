//
//  EUExSocketMgr.m
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import "EUExSocketMgr.h"
#import "EUtility.h"
#import "EUExSocket.h"
#import "AsyncUDPSocket.h"
#import "AsyncSocket.h"
#import "EUExBaseDefine.h"




@interface EUExSocketMgr()
@property (nonatomic,strong)NSMutableDictionary *socketObjs;

@end


@implementation EUExSocketMgr

-(id)initWithBrwView:(EBrowserView *) eInBrwView{
    if (self = [super initWithBrwView:eInBrwView]) {
        _socketObjs = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma -mark 调试之前 一定要度note.txt 文件 不然会后悔一辈子
#pragma mark

-(void)dealloc{
    [self.socketObjs removeAllObjects];
    self.socketObjs = nil;
}

//创建UDPSocket
-(void)createUDPSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSInteger inPort = [[inArguments objectAtIndex:1] integerValue];
    EUExSocket *udpSocket = [self.socketObjs objectForKey:@(inOpId)];
    if (udpSocket) {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        return;
    }
    uexSocketMgrDataType dataType = uexSocketMgrDataTypeUTF8;
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>2) {
        dataType = [inArguments[2] integerValue];
    }
    udpSocket = [[EUExSocket alloc] initWithEUExObj:self socketType:uexSocketMgrSocketTypeUDP];
    udpSocket.opID = inOpId;
    udpSocket.localPort = inPort;
    udpSocket.dataType = dataType;
    BOOL succ =  [udpSocket creatUDPSocketWithPort:inPort];
    if (succ) {
        [self.socketObjs setObject:udpSocket forKey:@(inOpId)];
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    }else {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    }

}

//创建TCPSocket
-(void)createTCPSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    EUExSocket *tcpSocket = [self.socketObjs objectForKey:@(inOpId)];
    if (tcpSocket) {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        return;
    }
    uexSocketMgrDataType dataType = uexSocketMgrDataTypeUTF8;
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>1) {
        dataType = [inArguments[1] integerValue];
    }
    
    tcpSocket = [[EUExSocket alloc] initWithEUExObj:self socketType:uexSocketMgrSocketTypeTCP];
    tcpSocket.opID = inOpId;
    tcpSocket.dataType = dataType;
    [self.socketObjs setObject:tcpSocket forKey:@(inOpId)];
    [self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];

}

-(void)closeSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object) {
        [object closeSocket:inOpId];
        [self.socketObjs removeObjectForKey:@(inOpId)];
    }
}

-(void)setTimeOut:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSInteger inTimeOut = [[inArguments objectAtIndex:1] integerValue];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object && object.socketType == uexSocketMgrSocketTypeTCP) {
        object.timeOutInter = inTimeOut;
    }
}

-(void)setInetAddressAndPort:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSString *inRemoteAddress = [inArguments objectAtIndex:1];
    NSInteger inRemotePort = [[inArguments objectAtIndex:2] integerValue];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object) {
        object.Port = inRemotePort;
        object.Host = inRemoteAddress;
        [object connectServer:inRemoteAddress port:(int)inRemotePort];
    }
}

-(void)sendData:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSString *inMsg = [inArguments objectAtIndex:1];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object!=nil) {
        [object sendMsg:inMsg];
    }else {
        [self jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    }
}


- (void)onDataCallbackWithOpID:(NSInteger)opid JSONString:(NSString *)json{
    json = [json stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *jsStr = [NSString stringWithFormat:@"if(uexSocketMgr.onData){uexSocketMgr.onData(%@,'%@')}",@(opid),json];
    [EUtility brwView:self.meBrwView evaluateScript:jsStr];

}

- (void)disconnectCallbackWithOpID:(NSInteger)opid{
    NSString *jsStr = [NSString stringWithFormat:@"if(uexSocketMgr.onDisconnected){uexSocketMgr.onDisconnected(%ld)}",(long)opid];
    [EUtility brwView:self.meBrwView evaluateScript:jsStr];
}



-(void)clean{
    [self.socketObjs removeAllObjects];
    self.socketObjs = nil;
}

@end
