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
@synthesize tcp_client,udp_client;
@synthesize xml;
@synthesize sockType,Port,Host,localPort;
@synthesize opID,timeOutInter;
@synthesize dataType;

#pragma -mark 字符处理

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

-(id) initWithUExObj:(EUExSocketMgr *)UExObj_ socketType:(int)socketType_{
	self.sockType = socketType_;
    UExObj = UExObj_;
	return self;
}

//创建udpsocket对象，绑定端口
- (BOOL)creatUDPSocketWithPort:(int )port{
    AsyncUdpSocket *udpSocket = [[AsyncUdpSocket alloc] initIPv4];
	[udpSocket setDelegate:self];
	NSError *error;
    self.udp_client = udpSocket;
	[udpSocket release];
	[udp_client setDelegate:self];
	[udp_client enableBroadcast:YES error:nil];
	if (port!=0) {
		[udp_client bindToPort:port error:&error];
	}
	[udp_client receiveWithTimeout:-1 tag:0];
	return YES;
}

//通过IP和端口连接服务器
- (BOOL) connectServer: (NSString *) hostIP port:(int) hostPort{
    if (sockType == 0){
        if (tcp_client == nil) {
            tcp_client = [[AsyncSocket alloc] init];
            [tcp_client setDelegate:self];
            NSError *err = nil;
            PluginLog(@"timeout = %",self.timeOutInter);
            BOOL succ;
            if (self.timeOutInter == 0) {
                succ =  [tcp_client connectToHost:hostIP onPort:hostPort error:&err];
            }else {
                succ =  [tcp_client connectToHost:hostIP onPort:hostPort withTimeout:(self.timeOutInter/1000) error:&err];
            }
            
            if (!succ) {
                NSLog(@"%@ %@", [err description], [err localizedDescription]);
                tcp_client = nil;
                [UExObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
                return NO;
            } else {
                PluginLog(@"Connect0000!!!");
                [UExObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
                return YES;
            }
        }
	}
	if (sockType == 1) {
		self.Port = hostPort;
		self.Host = hostIP;
		return YES;
    }
	return NO;
}


#pragma -mark 发送数据

- (void)sendMsg: (NSString *)msg {
	PluginLog(@"<<Chao-->sendMsg-->msg: %@",msg);
    NSMutableString* newStr = [NSMutableString stringWithString:msg];
    [newStr replaceOccurrencesOfString:@"\n" withString:@"\r\n" options:NSLiteralSearch range:NSMakeRange(0, [newStr length])];
    
	NSData *data = [newStr dataUsingEncoding:NSUTF8StringEncoding];
    //dataType 0是正常字符串 1特殊需求的处理逻辑
    if (1 == dataType) {
        //解码
        NSData *nsdataFromBase64String = [[NSData alloc]
                                          initWithBase64EncodedString:msg options:0];
        data = nsdataFromBase64String;
//        NSString *base64Decoded = [[NSString alloc]
//                                   initWithData:nsdataFromBase64String encoding:NSUTF8StringEncoding];
//        NSLog(@"Decoded: %@", base64Decoded);
        
        /*
         int length = msg.length/8;
         Byte bytes[msg.length/8];
         for (int i=0; i<length; i++) {
         NSString *_str = [msg substringWithRange:NSMakeRange(i*8, 8)];
         //NSLog(@"_str %@",_str);
         int lTemp = strtol([_str cStringUsingEncoding:NSUTF8StringEncoding], NULL, 2);
         //NSLog(@"%c",lTemp);
         bytes[i] = lTemp;
         }
         NSData *newData = [[[NSData alloc] initWithBytes:bytes length:length] autorelease];
         data = newData;
         */
        
    }
	if (sockType == F_TYEP_UDP) {
		BOOL succ = NO;
		if (udp_client) {
            //传数据,
			succ = [udp_client sendData:data toHost:Host port:Port withTimeout:-1 tag:0];
		}
        
		if (succ) {
			[UExObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
		}else {
			[UExObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
            
		}
	}else if (sockType == F_TYEP_TCP) {
		[tcp_client writeData:data withTimeout:-1 tag:1];
		[UExObj jsSuccessWithName:@"uexSocketMgr.cbSendData" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	}
}

//关闭
- (NSInteger)CloseSocket:(NSString *)inOpId{
	if (tcp_client &&[tcp_client isConnected])
	{
		[tcp_client disconnectAfterReadingAndWriting];
		[tcp_client disconnect];
	}
	if (udp_client) {
		[udp_client close];
	}
	return 0;
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

#pragma -mark Udp接受数据

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    NSString *resultString = nil;
    //dataType 0是正常字符串 1是客户特殊需求
    if (1 == dataType) {
        if (data)
        {
         //编码
         resultString = [data base64EncodedStringWithOptions:0];
            /*
             Byte *myb = (Byte*)[data bytes];
             for (int i = 0; i < data.length; i++) {
             NSString *str = [self intStringToBinary:myb[i]];
             if (!resultString) {
             resultString = [NSString stringWithFormat:@"%@", str];
             }else{
             resultString = [NSString stringWithFormat:@"%@%@", resultString, str];
             }
             }
             */
        }
        
        //else{//正常情况resultString = [EUtility transferredString:data];}
        
    }else{
        //正常情况
        resultString = [EUtility transferredString:data];
    }
    NSMutableDictionary * jsDic = [NSMutableDictionary dictionary];
    NSString * portStr = [NSString stringWithFormat:@"%d",port];
    [jsDic setObject:host forKey:@"host"];
    [jsDic setObject:portStr forKey:@"port"];
    [jsDic setObject:resultString forKey:@"data"];
    
    NSString *getString = [jsDic JSONFragment];
    [UExObj uexSocketWithOpId:[self.opID intValue] data:getString];
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
	[UExObj jsSuccessWithName:@"uexSocketMgr.cbConnected" opId:[self.opID intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	[sock readDataWithTimeout:-1 tag:0];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	NSString *msg = @"Sorry this connect is failure";
	NSLog(@"msg = %@",msg);
	[UExObj uexSocketDidDisconnect:self.opID];
	if (tcp_client) {
		[tcp_client release];
		tcp_client = nil;
	}
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag{
	PluginLog(@"send success");
}

#pragma -mark tcp接受数据

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
	NSString *resultString = nil;
    //dataType 0是正常字符串 1是客户特殊需求
    if (1 == dataType) {
        //编码
        resultString = [data base64EncodedStringWithOptions:0];
        
        /*
        if (data) {
            Byte *myb = (Byte*)[data bytes];
            for (int i = 0; i < data.length; i++) {
                NSString *str = [self intStringToBinary:myb[i]];
                if (!resultString) {
                    resultString = [NSString stringWithFormat:@"%@", str];
                }else{
                    resultString = [NSString stringWithFormat:@"%@%@", resultString, str];
                }
            }
        }else{
            NSString* dataToStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (dataToStr == nil || [dataToStr isKindOfClass:[NSNull class]]==YES ) {
                data = [self changeData:data];
            }
            [dataToStr release];
            resultString = [EUtility transferredString:data];
        }
         */
    }else{
        NSString* dataToStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (dataToStr == nil || [dataToStr isKindOfClass:[NSNull class]]==YES ) {
            data = [self changeData:data];
        }
        [dataToStr release];
        resultString = [EUtility transferredString:data];
    }
    NSMutableDictionary * jsDic = [NSMutableDictionary dictionary];
    [jsDic setObject:@"" forKey:@"host"];
    [jsDic setObject:@"" forKey:@"port"];
    [jsDic setObject:resultString forKey:@"data"];
    
    NSString *getString = [jsDic JSONFragment];
	[UExObj uexSocketWithOpId:[self.opID intValue] data:getString];
	[sock readDataWithTimeout:-1 tag:0];
}

-(void)dealloc{
	PluginLog(@"EUExSocket retain count is %d",[self retainCount]);
	PluginLog(@"EUExSocket dealloc is %x", self);
 	if (udp_client) {
		[udp_client release];
        udp_client = nil;
 	}
	
 	if (tcp_client) {
		[tcp_client release];
		tcp_client = nil;
 	}
	
	//[xml release];
	[opID release];
    if (Host) {
        [Host release];
    }
	[super dealloc];
}
@end

