//
//  EUExSocketMgr.m
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import "EUExSocketMgr.h"
#import "EUExSocket.h"
#import "uexSocketTCPClient.h"
#import "uexSocketUDPClient.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface EUExSocketMgr()
@property (nonatomic,strong)NSMutableDictionary *socketObjs;
@property (nonatomic,strong)NSMutableDictionary<UEX_SOCKET_ID,uexSocketUDPClient *> *udps;
@property (nonatomic,strong)NSMutableDictionary<UEX_SOCKET_ID,uexSocketTCPClient *> *tcps;
@end




@implementation EUExSocketMgr


#pragma mark - Life Cycle



- (void)dealloc{
    [self.socketObjs removeAllObjects];
    self.socketObjs = nil;
}

- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    if (self = [super initWithWebViewEngine:engine]) {
        _socketObjs = [NSMutableDictionary dictionary];
        _udps = [NSMutableDictionary dictionary];
        _tcps = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)clean{
    [self.socketObjs removeAllObjects];
    self.socketObjs = nil;
}


#pragma mark - Private

static inline UEX_ERROR SocketError(NSString *msg,UEX_SOCKET_ID sock,NSError * e){
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:sock forKey:@"socketID"];
    [dict setValue:e.localizedDescription forKey:@"error"];
    return uexErrorMake(1,msg,dict);
    
}

#pragma mark - 4.0 API


- (UEX_SOCKET_ID)createUDP:(NSMutableArray *)inArguments {
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *onData) = inArguments;
    NSNumber *port = numberArg(info[@"port"]);
    NSNumber *dataType = numberArg(info[@"dataType"]);
    UEX_PARAM_GUARD_NOT_NIL(port,nil);
    uexSocketMgrDataType type = dataType ? dataType.integerValue : uexSocketMgrDataTypeUTF8;
    uexSocketUDPClient *client = [[uexSocketUDPClient alloc]initWithPort:port.unsignedShortValue onDataBlock:^(NSString * _Nonnull host, UInt16 port, NSData * _Nonnull data) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSString *dataStr = [uexSocketHelper dataStrFromData:data dataType:type];
        [dict setValue:dataStr forKey:@"data"];
        [dict setValue:host forKey:@"host"];
        [dict setValue:@(port) forKey:@"port"];
        [onData executeWithArguments:ACArgsPack(dict)];
    }];
    if (!client) {
        ACLogDebug(@"create UDP client fail!");
        return nil;
    }
    client.dataType = type;
    [self.udps setValue:client forKey:client.identifier];
    return client.identifier;
}

- (void)send:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_SOCKET_ID udp ,NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    NSString *host = stringArg(info[@"host"]);
    NSNumber *port = numberArg(info[@"port"]);
    NSString *dataStr = stringArg(info[@"data"]);
    NSNumber *timeout = numberArg(info[@"timeout"]);
    uexSocketUDPClient *client = self.udps[udp];
    UEX_PARAM_GUARD_NOT_NIL(udp);
    UEX_PARAM_GUARD_NOT_NIL(host);
    UEX_PARAM_GUARD_NOT_NIL(port);
    UEX_PARAM_GUARD_NOT_NIL(dataStr);
    UEX_PARAM_GUARD_NOT_NIL(client);
    
    NSData *data = [uexSocketHelper dataFromDataStr:dataStr dataType:client.dataType];
    NSTimeInterval t = timeout ? timeout.doubleValue / 1000 : -1;
    [client sendData:data toHost:host port:port.unsignedShortValue timeout:t completion:^(NSError *error) {
        UEX_ERROR err = kUexNoError;
        if (error) {
            err = SocketError(@"send error",udp,error);
        }
        [cb executeWithArguments:ACArgsPack(err)];
    }];
}


- (UEX_SOCKET_ID)createTCP:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *onStatus,ACJSFunctionRef *onData) = inArguments;
    NSNumber *dataType = numberArg(info[@"dataType"]);
    uexSocketMgrDataType type = dataType ? dataType.integerValue : uexSocketMgrDataTypeUTF8;
    uexSocketTCPClient *client = [[uexSocketTCPClient alloc]initWithOnStatusBlock:^(uexSocketTCPStatus status) {
        [onStatus executeWithArguments:ACArgsPack(@(status))];
    } onDataBlock:^(NSData * _Nonnull data) {
        NSString *dataStr = [uexSocketHelper dataStrFromData:data dataType:type];
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:dataStr forKey:@"data"];
        [onData executeWithArguments:ACArgsPack(dict)];
    }];
    if (!client) {
        return nil;
    }
    client.dataType = type;
    [self.tcps setObject:client forKey:client.identifier];
    return client.identifier;

}

- (void)connect:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_SOCKET_ID tcp,NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    NSString *host = stringArg(info[@"host"]);
    NSNumber *port = numberArg(info[@"port"]);
    NSNumber *timeout = numberArg(info[@"timeout"]);
    uexSocketTCPClient *client = self.tcps[tcp];
    UEX_PARAM_GUARD_NOT_NIL(host);
    UEX_PARAM_GUARD_NOT_NIL(port);
    UEX_PARAM_GUARD_NOT_NIL(tcp);
    UEX_PARAM_GUARD_NOT_NIL(client);
    NSTimeInterval t = timeout ? timeout.doubleValue / 1000 : -1;
    NSError *error = nil;
    BOOL ret = [client connectToHost:host onPort:port.unsignedShortValue withTimeout:t error:&error];
    UEX_ERROR err = kUexNoError;
    if (!ret || error) {
        err = SocketError(@"connect error!",tcp,error);
    }
    [cb executeWithArguments:ACArgsPack(err)];
}

- (void)write:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_SOCKET_ID tcp,NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    NSString *dataStr = stringArg(info[@"data"]);
    NSNumber *timeout = numberArg(info[@"timeout"]);
    uexSocketTCPClient *client = self.tcps[tcp];
    UEX_PARAM_GUARD_NOT_NIL(tcp);
    UEX_PARAM_GUARD_NOT_NIL(client);
    UEX_PARAM_GUARD_NOT_NIL(dataStr);
    NSData *data = [uexSocketHelper dataFromDataStr:dataStr dataType:client.dataType];
    NSTimeInterval t = timeout ? timeout.doubleValue / 1000 : -1;
    [client writeData:data timeout:t completion:^(NSError *error) {
        UEX_ERROR err = kUexNoError;
        if (error) {
            err = SocketError(@"write error!",tcp,error);
        }
        [cb executeWithArguments:ACArgsPack(err)];
    }];
}

- (void)close:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_SOCKET_ID sock,NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    UEX_PARAM_GUARD_NOT_NIL(sock);
    NSNumber *inFlag = numberArg(info[@"flag"]);
    uexSocketCloseFlag flag = inFlag ? inFlag.integerValue : uexSocketCloseImmediately;
    BOOL clientFound = NO;
    
    

    
    uexSocketTCPClient *tcp = self.tcps[sock];
    @weakify(self);
    if (tcp) {
        clientFound = YES;
        [tcp closeWithFlag:flag completion:^(NSError *error) {
            @strongify(self);
            UEX_ERROR err = kUexNoError;
            if (error) {
                err = SocketError(@"close tcp error!",sock,error);
            }
            [cb executeWithArguments:ACArgsPack(err)];
            self.tcps[sock] = nil;
        }];
    }
    uexSocketUDPClient *udp = self.udps[sock];
    if (udp) {
        clientFound = YES;
        [udp closeWithFlag:flag completion:^(NSError *error) {
            @strongify(self);
            UEX_ERROR err = kUexNoError;
            if (error) {
                err = SocketError(@"close tcp error!",sock,error);
            }
            [cb executeWithArguments:ACArgsPack(err)];
            self.udps[sock] = nil;
        }];
        
    }
    if (!clientFound) {
        
        UEX_ERROR err = SocketError(@"invalid socket!",sock,nil);
        [cb executeWithArguments:ACArgsPack(err)];
    }
    
    
}

#pragma mark - 3.O Legacy API
#pragma mark Deprecated

//创建UDPSocket
- (UEX_BOOL)createUDPSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSInteger inPort = [[inArguments objectAtIndex:1] integerValue];
    EUExSocket *udpSocket = [self.socketObjs objectForKey:@(inOpId)];
    if (udpSocket) {
        //[self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        return UEX_FALSE;
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
        //[self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbCreateUDPSocket" arguments:ACArgsPack(@(inOpId),@2,@0)];
        return @YES;
    }else {
       // [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbCreateUDPSocket" arguments:ACArgsPack(@(inOpId),@2,@1)];
        return UEX_TRUE;
    }

}

//创建TCPSocket
- (UEX_BOOL)createTCPSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    EUExSocket *tcpSocket = [self.socketObjs objectForKey:@(inOpId)];
    if (tcpSocket) {
        //[self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbCreateTCPSocket" arguments:ACArgsPack(@(inOpId),@2,@1)];
        return UEX_FALSE;
    }
    uexSocketMgrDataType dataType = uexSocketMgrDataTypeUTF8;
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>1) {
        dataType = [inArguments[1] integerValue];
    }
    
    tcpSocket = [[EUExSocket alloc] initWithEUExObj:self socketType:uexSocketMgrSocketTypeTCP];
    tcpSocket.opID = inOpId;
    tcpSocket.dataType = dataType;
    [self.socketObjs setObject:tcpSocket forKey:@(inOpId)];
    //[self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbCreateTCPSocket" arguments:ACArgsPack(@(inOpId),@2,@0)];
    return UEX_TRUE;
}

- (void)closeSocket:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object) {
        [object closeSocket:inOpId];
        [self.socketObjs removeObjectForKey:@(inOpId)];
    }
}

- (void)setTimeOut:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSInteger inTimeOut = [[inArguments objectAtIndex:1] integerValue];
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object && object.socketType == uexSocketMgrSocketTypeTCP) {
        object.timeOutInter = inTimeOut;
    }
}

- (void)setInetAddressAndPort:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSString *inRemoteAddress = [inArguments objectAtIndex:1];
    NSInteger inRemotePort = [[inArguments objectAtIndex:2] integerValue];
    ACJSFunctionRef *func = JSFunctionArg(inArguments.lastObject);
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    if (object) {
        object.Port = inRemotePort;
        object.Host = inRemoteAddress;
        [object connectServer:inRemoteAddress port:(int)inRemotePort Function:func];
    }else{
        [func executeWithArguments:ACArgsPack(@(1))];
    }
}

- (void)sendData:(NSMutableArray *)inArguments {
    NSInteger inOpId = [[inArguments objectAtIndex:0] integerValue];
    NSString *inMsg = [inArguments objectAtIndex:1];
    ACJSFunctionRef *func = JSFunctionArg(inArguments.lastObject);
    EUExSocket *object = [self.socketObjs objectForKey:@(inOpId)];
    object.fun = func;
    if (object!=nil) {
        [object sendMsg:inMsg];
    }else {
        //[self jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:inOpId dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbSendData" arguments:ACArgsPack(@1)];
        [func executeWithArguments:ACArgsPack(@1)];
    }
}


- (void)onDataCallbackWithOpID:(NSInteger)opid JSONString:(NSString *)json{
    json = [json stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    //NSString *jsStr = [NSString stringWithFormat:@"if(uexSocketMgr.onData){uexSocketMgr.onData(%@,'%@')}",@(opid),json];
    //[EUtility brwView:self.meBrwView evaluateScript:jsStr];
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.onData" arguments:ACArgsPack(@(opid),[json ac_JSONFragment])];

}

- (void)disconnectCallbackWithOpID:(NSInteger)opid{
    //NSString *jsStr = [NSString stringWithFormat:@"if(uexSocketMgr.onDisconnected){uexSocketMgr.onDisconnected(%ld)}",(long)opid];
   // [EUtility brwView:self.meBrwView evaluateScript:jsStr];
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.onDisconnected" arguments:ACArgsPack(@(opid))];
}




@end
