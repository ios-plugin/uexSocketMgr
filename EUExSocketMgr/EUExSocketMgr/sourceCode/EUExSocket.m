//
//  EUExSocket.m
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import "EUExSocket.h"
#import "EUExSocketMgr.h"
#import "EUtility.h"
#import "EUExBaseDefine.h"


@interface EUExSocket()

@end
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
    long long numberCopy = element;
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
    self.UDPClient = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	NSError *error;
	[self.UDPClient enableBroadcast:YES error:nil];
    BOOL isBind = NO;
	if (port!=0) {
	 isBind =[self.UDPClient bindToPort:port error:&error];
	}
    if (![self.UDPClient beginReceiving:&error])
    {
        NSLog(@"Error receiving:%@", error);
        //return NO;
    }
    
	return isBind;
}

//通过IP和端口连接服务器
- (BOOL)connectServer: (NSString *) hostIP port:(UInt16) hostPort Function:(ACJSFunctionRef *)func{
    self.fun = func;
    if (self.socketType == uexSocketMgrSocketTypeTCP){
        if (self.TCPClient == nil) {
            self.TCPClient = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
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
                //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
                [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbConnected" arguments:ACArgsPack(@(self.opID),@2,@1)];
                [func executeWithArguments:ACArgsPack(@1)];
                func = nil;
                return NO;
            } else {
                PluginLog(@"Connect0000!!!");
                [func executeWithArguments:ACArgsPack(@0)];
                func = nil;
                
                return YES;
            }
        }
	}
	if (self.socketType == uexSocketMgrSocketTypeUDP) {
		self.Port = hostPort;
		self.Host = hostIP;
        //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
        [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbConnected" arguments:ACArgsPack(@(self.opID),@2,@0)];
        [func executeWithArguments:ACArgsPack(@0)];
        func = nil;
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
        if (self.UDPClient) {
            //传数据,
            [self.UDPClient sendData:data toHost:self.Host port:self.Port withTimeout:-1 tag:0];
           
        }
        
    }else{
        
        [self.TCPClient writeData:data withTimeout:-1 tag:1];
        
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
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error{
    PluginLog(@"NO SEND");
    //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbSendData" arguments:ACArgsPack(@(self.opID),@2,@1)];
    [self.fun executeWithArguments:ACArgsPack(@1)];
    self.fun = nil;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag{
    PluginLog(@"SEND SUCCESS");
    PluginLog(@"%d:%@",[sock localPort],[sock localHost]);
    //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
     [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbSendData" arguments:ACArgsPack(@(self.opID),@2,@0)];
     [self.fun executeWithArguments:ACArgsPack(@0)];
    self.fun = nil;
}
#pragma mark - Udp接受数据
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
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
    NSString * portStr = [NSString stringWithFormat:@"%d",[GCDAsyncUdpSocket portFromAddress:address]];
    [jsDic setValue:[GCDAsyncUdpSocket hostFromAddress:address] forKey:@"host"];
    [jsDic setValue:portStr forKey:@"port"];
    [jsDic setValue:resultString forKey:@"data"];
    [self.euexObj onDataCallbackWithOpID:self.opID JSONString:[jsDic ac_JSONFragment]];

}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error{
    PluginLog(@"Close socket");
    [self.euexObj disconnectCallbackWithOpID:self.opID];
    if (self.UDPClient) {
        self.UDPClient = nil;
    }
}






//TCP delegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    PluginLog(@"connect success");
    //	[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbConnected" arguments:ACArgsPack(@(self.opID),@2,@0)];
    [self.fun executeWithArguments:ACArgsPack(@0)];
    self.fun = nil;
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    [self.euexObj disconnectCallbackWithOpID:self.opID];
    if (self.TCPClient) {
        self.TCPClient = nil;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    PluginLog(@"send success");
    //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
    [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbSendData" arguments:ACArgsPack(@(self.opID),@2,@0)];
    [self.fun executeWithArguments:ACArgsPack(@0)];
    self.fun = nil;
   
}
- (NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    PluginLog(@"发送数据到服务器超时");
    //[self.euexObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:self.opID dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
    [self.euexObj.webViewEngine callbackWithFunctionKeyPath:@"uexSocketMgr.cbSendData" arguments:ACArgsPack(@(self.opID),@2,@1)];
    [self.fun executeWithArguments:ACArgsPack(@1)];
    self.fun = nil;

    return -1;
}
#pragma mark - tcp接受数据

//- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
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
    
    [self.euexObj onDataCallbackWithOpID:self.opID JSONString:[jsDic ac_JSONFragment]];
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

