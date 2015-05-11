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

@implementation EUExSocketMgr

-(id)initWithBrwView:(EBrowserView *) eInBrwView{
    if (self = [super initWithBrwView:eInBrwView]) {
        sobjDict = [[NSMutableDictionary alloc] initWithCapacity:UEX_PLATFORM_CALL_ARGS];
    }
    return self;
}

#pragma -mark 调试之前 一定要度note.txt 文件 不然会后悔一辈子
#pragma mark

-(void)dealloc{
    if (sobjDict) {
        for (EUExSocket *sock in [sobjDict allValues]) {
            if (sock) {
                //[sock release];
                sock = nil;
            }
        }
        [sobjDict release];
        sobjDict = nil;
    }
    [super dealloc];
}

//创建UDPSocket
-(void)createUDPSocket:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    NSString *inPort = [inArguments objectAtIndex:1];
    //12.29----xll
    EUExSocket *udpSocket = [sobjDict objectForKey:inOpId];
    if (udpSocket) {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        return;
    }
    
    //dataType 0是正常字符串 1特殊需求的处理逻辑
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>2) {
        NSString *dataType_str = [inArguments objectAtIndex:2];
        if ([dataType_str isKindOfClass:[NSString class]] && dataType_str.length>0) {
            dataType = [dataType_str intValue];
        }else{
            dataType = 0;
        }
    }else{
        dataType = 0;
    }
    udpSocket = [[EUExSocket alloc] initWithUExObj:self socketType:F_TYEP_UDP];
    udpSocket.opID = inOpId;
    udpSocket.localPort = [inPort intValue];
    udpSocket.dataType = dataType;
    BOOL succ =  [udpSocket creatUDPSocketWithPort:[inPort intValue]];
    if (succ) {
        [sobjDict setObject:udpSocket forKey:inOpId];
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    }else {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateUDPSocket" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    }
    [udpSocket release];
}

//创建TCPSocket
-(void)createTCPSocket:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    EUExSocket *tcpSocket = [sobjDict objectForKey:inOpId];
    if (tcpSocket) {
        [self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
        return;
    }
    
    //dataType 0是正常字符串 1特殊需求的处理逻辑
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>1) {
        NSString *dataType_str = [inArguments objectAtIndex:1];
        if ([dataType_str isKindOfClass:[NSString class]] && dataType_str.length>0) {
            dataType = [dataType_str intValue];
        }else{
            dataType = 0;
        }
    }else{
        dataType = 0;
    }
    
    tcpSocket = [[EUExSocket alloc] initWithUExObj:self socketType:F_TYEP_TCP];
    tcpSocket.opID = inOpId;
    tcpSocket.dataType = dataType;
    [sobjDict setObject:tcpSocket forKey:inOpId];
    [self jsSuccessWithName:@"uexSocketMgr.cbCreateTCPSocket" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    [tcpSocket release];
}

-(void)closeSocket:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    EUExSocket *object = [sobjDict objectForKey:inOpId];
    if (object!=nil) {
        [object CloseSocket:inOpId];
        [sobjDict removeObjectForKey:inOpId];
    }
}

-(void)setTimeOut:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    NSString *inTimeOut = [inArguments objectAtIndex:1];
    EUExSocket *object = [sobjDict objectForKey:inOpId];
    if (object) {
        //设置时间超时
        if (object.sockType == F_TYEP_TCP) {
            object.timeOutInter = [inTimeOut intValue];
        }
    }
}

-(void)setInetAddressAndPort:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    NSString *inRemoteAddress = [inArguments objectAtIndex:1];
    NSString *inRemotePort = [inArguments objectAtIndex:2];
    EUExSocket *object = [sobjDict objectForKey:inOpId];
    if (object!=nil) {
        object.Port = [inRemotePort intValue];
        object.Host = inRemoteAddress;
        [object connectServer:inRemoteAddress port:[inRemotePort intValue]];
    }else {
        //
    }
}

-(void)sendData:(NSMutableArray *)inArguments {
    NSString *inOpId = [inArguments objectAtIndex:0];
    NSString *inMsg = [inArguments objectAtIndex:1];
    EUExSocket *object = [sobjDict objectForKey:inOpId];
    if (object!=nil) {
        [object sendMsg:inMsg];
    }else {
        [self jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    }
}

-(void)uexSocketWithOpId:(int)inOpId data:(NSString*)inData{
    inData = [inData stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *jsStr = [NSString stringWithFormat:@"if(uexSocketMgr.onData!=null){uexSocketMgr.onData(%d,\'%@\')}",inOpId,inData];
    [meBrwView stringByEvaluatingJavaScriptFromString:jsStr];
}

-(void)uexSocketDidDisconnect:(NSString *)opid{
    NSString *jsstr = [NSString stringWithFormat:@"if(uexSocketMgr.onDisconnected!=null){uexSocketMgr.onDisconnected(%d)}",[opid intValue]];
    [meBrwView stringByEvaluatingJavaScriptFromString:jsstr];
}

-(void)clean{
    if (sobjDict) {
        for (EUExSocket *sock in [sobjDict allValues]) {
            if (sock) {
                //[sock release];
                sock = nil;
            }
        }
    }
}

@end
