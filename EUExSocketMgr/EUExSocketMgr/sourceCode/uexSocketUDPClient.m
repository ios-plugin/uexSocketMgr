/**
 *
 *	@file   	: uexSocketUDPClient.m  in EUExSocketMgr
 *
 *	@author 	: CeriNo
 * 
 *	@date   	: 16/8/17
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#import "uexSocketUDPClient.h"
#import <ReactiveObjC/ReactiveObjC.h>
#import <CocoaAsyncSocket/CocoaAsyncSocket.h>

#define UDP_PROTOCOL_SIGNAL(sel) ([self rac_signalForSelector:@selector(sel) fromProtocol:@protocol(GCDAsyncUdpSocketDelegate)])

@interface uexSocketUDPClient ()<GCDAsyncUdpSocketDelegate>
@property (nonatomic,strong)uexSocketUDPOndataBlock onData;
@property (nonatomic,strong)GCDAsyncUdpSocket *socket;
@property (nonatomic,strong)dispatch_queue_t deleateQueue;
@property (nonatomic,assign)UInt16 port;
@property (nonatomic,assign)BOOL isClosed;
@property (nonatomic,strong)NSMutableDictionary<NSNumber *,uexSocketErrorCompletionBlock> *sendDataCallbacks;
@end




@implementation uexSocketUDPClient



- (nullable instancetype)initWithPort:(UInt16)port onDataBlock:(uexSocketUDPOndataBlock)onData{
    self = [super init];
    if (self) {
        _identifier = [uexSocketHelper makeSocketID];
        _port = port;
        _deleateQueue = dispatch_queue_create("com.appcan.socketManager.UDP", DISPATCH_QUEUE_CONCURRENT);
        _onData = onData;
        _sendDataCallbacks = [NSMutableDictionary dictionary];
        if (![self setupSocket]) {
            return nil;
        };
    }
    return self;
}

- (BOOL)setupSocket{
    _socket = [[GCDAsyncUdpSocket alloc]initWithDelegate:self delegateQueue:_deleateQueue];
    NSError *error = nil;
    if (![_socket enableBroadcast:YES error:&error]) {
        ACLogDebug(@"UDPSocket enable broadcast error: %@",error.localizedDescription);
    }
    
    if (![_socket bindToPort:_port error:&error]) {
        ACLogDebug(@"UDPSocket bind to port<%d> error: %@",_port,error.localizedDescription);
        return NO;
    }
    if (![_socket beginReceiving:&error]) {
        ACLogDebug(@"UDPSocket begin receiving error: %@",error.localizedDescription);
    }
    @weakify(self);
    [UDP_PROTOCOL_SIGNAL(udpSocket:didReceiveData:fromAddress:withFilterContext:)
        subscribeNext:^(RACTuple *tuple) {
            @strongify(self);
            RACTupleUnpack(__unused GCDAsyncUdpSocket *sock,NSData *data,NSData *address) = tuple;
            NSString *host = [GCDAsyncUdpSocket hostFromAddress:address];
            UInt16 port = [GCDAsyncUdpSocket portFromAddress:address];
            if (self.onData) {
                self.onData(host,port,data);
            }
     }];
    [[UDP_PROTOCOL_SIGNAL(udpSocket:didSendDataWithTag:)
        merge:UDP_PROTOCOL_SIGNAL(udpSocket:didNotSendDataWithTag:dueToError:)]
        subscribeNext:^(RACTuple *tuple) {
            @strongify(self);
            RACTupleUnpack(__unused GCDAsyncUdpSocket *sock,NSNumber *tag,NSError *e) = tuple;
            uexSocketErrorCompletionBlock cb = self.sendDataCallbacks[tag];
            self.sendDataCallbacks[tag] = nil;
            if (cb) {
                cb(e);
            }
            
    }];
    

    
    
    [self.rac_deallocDisposable addDisposable:
        [RACDisposable disposableWithBlock:^{
        @strongify(self);
        [self.socket close];
        [self clean];
    }]];
    return YES;
}

- (void)closeWithFlag:(uexSocketCloseFlag)flag completion:(uexSocketErrorCompletionBlock)completion{
    if (self.isClosed) {
        completion([uexSocketHelper socketAlreadyClosedError]);
        ACLogDebug(@"UDPSocket<%@> has already closed!",_identifier);
        return;
    }
    @weakify(self);
    __block RACDisposable *disposable =
        [UDP_PROTOCOL_SIGNAL(udpSocketDidClose:withError:)
            subscribeNext:^(RACTuple *tuple) {
                @strongify(self);
                RACTupleUnpack(__unused GCDAsyncUdpSocket *sock,NSError *error) = tuple;
                completion(error);
                [self clean];
                [disposable dispose];
    }];
    switch (flag) {
        case uexSocketCloseImmediately: {
            [self.socket close];
            break;
        }
        case uexSocketCloseWhenIDle: {
            [self.socket closeAfterSending];
            break;
        }
    }
    
}


- (void)clean{
    _onData = nil;
    _socket = nil;
    [_sendDataCallbacks removeAllObjects];
    _isClosed = YES;
    
}

- (void)sendData:(NSData *)data
          toHost:(NSString *)host
            port:(UInt16)port
         timeout:(NSTimeInterval)timeout
      completion:(uexSocketErrorCompletionBlock)completion{

    if (self.isClosed) {
        completion([uexSocketHelper socketAlreadyClosedError]);
        return;
    }
    
    UInt32 mid = [uexSocketHelper makeMID];
    if (completion) {
        [self.sendDataCallbacks setObject:completion forKey:@(mid)];
    }
    if (timeout <= 0) {
        timeout = -1;
    }
    [self.socket sendData:data toHost:host port:port withTimeout:timeout tag:mid];
}

@end
