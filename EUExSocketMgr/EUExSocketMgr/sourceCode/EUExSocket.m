//
//  EUExSocket.m
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import "EUExSocket.h"
#import "AsyncUDPSocket.h"
#import "AsyncSocket.h"
#import "EUExSocketMgr.h"
#import "EUtility.h"
#import "EUExBaseDefine.h"
#import "JSON.h"

@implementation EUExSocket


#pragma mark - 字符处理

//将nsdata中的非法字符替换为A 0x41
-(NSData*)changeData:(NSData*)data{
    char aa[] = {' ',' ',' ',' ',' ',' '};
    NSMutableData *md = [NSMutableData dataWithData:data];
    int loc = 0;
    while(loc < [md length]){
        char buffer;
        [md getBytes:&buffer range:NSMakeRange(loc, 1)];
        //printf("%d", buffer&0x80);
        if((buffer & 0x80) == 0){
            loc++;
            continue;
        }else if((buffer & 0xE0) == 0xC0){
            loc++;
            [md getBytes:&buffer range:NSMakeRange(loc, 1)];
            if((buffer & 0xC0) == 0x80){
                loc++;
                continue;
            }
            loc--;
            //非法字符，将这1个字符替换为AA
            [md replaceBytesInRange:NSMakeRange(loc  , 1) withBytes:aa length:1];
            loc++;
            continue;
        }else if((buffer & 0xF0) == 0xE0){
            loc++;
            [md getBytes:&buffer range:NSMakeRange(loc, 1)];
            if((buffer & 0xC0) == 0x80){
                loc++;
                [md getBytes:&buffer range:NSMakeRange(loc, 1)];
                if((buffer & 0xC0) == 0x80){
                    loc++;
                    continue;
                }
                loc--;
            }
            loc--;
            //非法字符，将这个字符替换为A
            [md replaceBytesInRange:NSMakeRange(loc , 1) withBytes:aa length:1];
            loc++;
            continue;
        }else{
            [md replaceBytesInRange:NSMakeRange(loc, 1) withBytes:aa length:1];
            loc++;
            continue;
        }
    }
    return md;
}

- (NSString*)intStringToBinary:(long long)element{
    NSMutableString *str = [NSMutableString string];
    NSInteger numberCopy = element;
    for(int i = 0; i < 8; i++){
        [str insertString:((numberCopy & 1) ? @"1" : @"0") atIndex:0];
        numberCopy >>= 1;
        //NSLog(@"str is %@",str);
    }
    return str;
}

- (instancetype)initWithEUExObj:(EUExSocketMgr *)euexObj socketType:(uexSocketMgrSocketType)socketType
{
    self = [super init];
    if (self) {
        self.euexObj = euexObj;
        self.socketType = socketType;
    }
    return self;
}



//创建udpsocket对象，绑定端口
- (BOOL)creatUDPSocketWithPort:(UInt16)port{
    AsyncUdpSocket *udpSocket = [[AsyncUdpSocket alloc] initIPv4];
	[udpSocket setDelegate:self];
	NSError *error;
    self.UDPClient = udpSocket;
	[self.UDPClient setDelegate:self];
	[self.UDPClient enableBroadcast:YES error:nil];
	if (port!=0) {
		[self.UDPClient bindToPort:port error:&error];
	}
	[self.UDPClient receiveWithTimeout:-1 tag:0];
	return YES;
}

//通过IP和端口连接服务器
- (BOOL) connectServer: (NSString *) hostIP port:(UInt16) hostPort{

    if (self.socketType == uexSocketMgrSocketTypeTCP){
        if (self.TCPClient == nil) {
            self.TCPClient = [[AsyncSocket alloc] init];
            [self.TCPClient setDelegate:self];
            NSError *err = nil;
            PluginLog(@"timeout = %",self.timeOutInter);
            BOOL succ;
            if (self.timeOutInter == 0) {
                succ =  [self.TCPClient connectToHost:hostIP onPort:hostPort error:&err];
            }else {
                succ =  [self.TCPClient connectToHost:hostIP onPort:hostPort withTimeout:(self.timeOutInter/1000) error:&err];
            }
            if (!succ) {
                NSLog(@"%@ %@", [err description], [err localizedDescription]);
                self.TCPClient = nil;
                [self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
                return NO;
            } else {
                PluginLog(@"Connect0000!!!");
                
                //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
                //TCP链接成功的回调在delegate中处理
                return YES;
            }
        }
	}
	if (self.socketType == uexSocketMgrSocketTypeUDP) {
		self.Port = hostPort;
		self.Host = hostIP;
		return YES;
    }
	return NO;
}


#pragma mark - 发送数据

- (void)sendMsg: (NSString *)msg {
	PluginLog(@"<<Chao-->sendMsg-->msg: %@",msg);
    NSMutableString* newStr = [NSMutableString stringWithString:msg];
    [newStr replaceOccurrencesOfString:@"\n" withString:@"\r\n" options:NSLiteralSearch range:NSMakeRange(0, [newStr length])];
    
    
    NSData *data;
    switch (self.dataType) {
        case uexSocketMgrDataTypeUTF8: {
            data = [newStr dataUsingEncoding:NSUTF8StringEncoding];
            break;
        }
        case uexSocketMgrDataTypeBase64: {
             data = [[NSData alloc]initWithBase64EncodedString:msg options:0];
            break;
        }
        case uexSocketMgrDataTypeGBK: {
            
            NSStringEncoding encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            data = [newStr dataUsingEncoding:encode];
            break;
        }
    }

    if (self.socketType == uexSocketMgrSocketTypeUDP) {
        BOOL succ = NO;
        if (self.UDPClient) {
            //传数据,
            succ = [self.UDPClient sendData:data toHost:self.Host port:self.Port withTimeout:-1 tag:0];
        }
        
        if (succ) {
            [self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
        }else {
            [self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
            
        }
    }else if (self.socketType == uexSocketMgrSocketTypeTCP) {
        [self.TCPClient writeData:data withTimeout:-1 tag:1];
        [self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    }
    
}


//关闭
- (void)closeSocket:(NSInteger)inOpId{
    if (self.TCPClient &&[self.TCPClient isConnected]){
        [self.TCPClient disconnectAfterReadingAndWriting];
        [self.TCPClient disconnect];
    }
    if (self.UDPClient) {
        [self.UDPClient close];
    }
}


//UDP delegate

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
	PluginLog(@"NO SEND");
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
	PluginLog(@"SEND SUCCESS");
	PluginLog(@"%d:%@",[sock localPort],[sock localHost]);
}

#pragma mark - Udp接受数据

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    NSString *resultString = @"";
    switch (self.dataType) {
        case uexSocketMgrDataTypeUTF8:{
            resultString = [EUtility transferredString:data];
            break;
        }
        case uexSocketMgrDataTypeBase64:{
            if (data){
                resultString = [data base64EncodedStringWithOptions:0];
            }
            break;
        }
        case uexSocketMgrDataTypeGBK: {
            NSStringEncoding encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            resultString = [[NSString alloc]initWithData:data encoding:encode];
            break;
        }
    }
    
    
    NSMutableDictionary * jsDic = [NSMutableDictionary dictionary];
    NSString * portStr = [NSString stringWithFormat:@"%d",port];
    [jsDic setValue:host forKey:@"host"];
    [jsDic setValue:portStr forKey:@"port"];
    [jsDic setValue:resultString forKey:@"data"];
    [self.euexObj onDataCallbackWithOpID:self.opID JSONString:[jsDic JSONFragment]];
    [sock receiveWithTimeout:-1 tag:0];
    return YES;

}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error
{
	PluginLog(@"Not Receive");
}

- (void)onUdpSocketDidClose:(AsyncUdpSocket *)sock
{
	PluginLog(@"Close socket");
}

//TCP delegate
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    PluginLog(@"Error");
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port{
	PluginLog(@"connect success");
	[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	[sock readDataWithTimeout:-1 tag:0];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    [self.euexObj disconnectCallbackWithOpID:self.opID];
	if (self.TCPClient) {
		self.TCPClient = nil;
	}
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag{
	PluginLog(@"send success");
}

#pragma mark - tcp接受数据

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
	NSString *resultString = @"";
    
    switch (self.dataType) {
        case uexSocketMgrDataTypeUTF8: {
            NSString* dataToStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!dataToStr) {
                data = [self changeData:data];
            }
            resultString = [EUtility transferredString:data];
            break;
        }
        case uexSocketMgrDataTypeBase64: {
            resultString = [data base64EncodedStringWithOptions:0];
            break;
        }
        case uexSocketMgrDataTypeGBK: {
            NSStringEncoding encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            resultString = [[NSString alloc]initWithData:data encoding:encode];
            break;
        }
    }

    NSMutableDictionary * jsDic = [NSMutableDictionary dictionary];
    [jsDic setValue:@"" forKey:@"host"];
    [jsDic setValue:@"" forKey:@"port"];
    [jsDic setValue:resultString forKey:@"data"];
    
    [self.euexObj onDataCallbackWithOpID:self.opID JSONString:[jsDic JSONFragment]];
    [sock readDataWithTimeout:-1 tag:0];

}

-(void)dealloc{
 	if (self.UDPClient) {
        self.UDPClient = nil;
 	}
 	if (self.TCPClient) {
		self.TCPClient = nil;
 	}
}
@end

