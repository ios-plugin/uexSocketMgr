/**
 *
 *	@file   	: uexSocketTCPClient.m  in EUExSocketMgr
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


#import "uexSocketTCPClient.h"
#import <ReactiveObjC/ReactiveObjC.h>
#import <CocoaAsyncSocket/CocoaAsyncSocket.h>

#define TCP_PROTOCOL_SIGNAL(sel) ([self rac_signalForSelector:@selector(sel) fromProtocol:@protocol(GCDAsyncSocketDelegate)])


@interface uexSocketTCPClient()<GCDAsyncSocketDelegate>
@property (nonatomic,strong)GCDAsyncSocket *socket;
@property (nonatomic,strong)NSMutableDictionary<NSNumber *,uexSocketErrorCompletionBlock> *writeCallbacks;
@property (nonatomic,strong)dispatch_queue_t delegateQueue;
@property (nonatomic,assign)BOOL isClosed;
@property (nonatomic,strong)uexSocketTCPOnDataBlock onData;
@property (nonatomic,strong)uexSocketTCPOnStatusBlock onStatus;

@end
@implementation uexSocketTCPClient


- (instancetype)initWithOnStatusBlock:(uexSocketTCPOnStatusBlock)onStatus onDataBlock:(uexSocketTCPOnDataBlock)onData{
    self = [super init];
    if (self) {
        _identifier = [uexSocketHelper makeSocketID];
        _delegateQueue = dispatch_queue_create("com.appcan.SocketManager.TCP", DISPATCH_QUEUE_CONCURRENT);
        _onData = onData;
        _onStatus = onStatus;
        _writeCallbacks = [NSMutableDictionary dictionary];
        [self setupSocket];
    }
    return self;
}

- (void)setupSocket{
    _socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:_delegateQueue];
    @weakify(self);
    [[TCP_PROTOCOL_SIGNAL(socket:didWriteDataWithTag:)
        merge:TCP_PROTOCOL_SIGNAL(socket:shouldTimeoutWriteWithTag:elapsed:bytesDone:) ]
        subscribeNext:^(RACTuple *tuple) {
            @strongify(self);
            RACTupleUnpack(__unused GCDAsyncSocket *sock,NSNumber *tag,NSNumber *e) = tuple;
            uexSocketErrorCompletionBlock cb = self.writeCallbacks[tag];
            if (cb) {
                cb(e ? [uexSocketHelper socketTimeoutError] : nil);
            }
    }];
    [[[[TCP_PROTOCOL_SIGNAL(socket:didConnectToHost:port:) map:^id(id value) {return @(uexSocketTCPStatusConnected);}]
        doNext:^(id x) {
            @strongify(self);
            [self.socket readDataWithTimeout:-1 tag:0];
        }]
        merge:[TCP_PROTOCOL_SIGNAL(socketDidDisconnect:withError:) map:^id(id value) {return @(uexSocketTCPStatusDisconnected);}]]
        subscribeNext:^(NSNumber *status) {
            @strongify(self);
            if (self.onStatus) {
                self.onStatus(status.integerValue);
            }
    }];
    [TCP_PROTOCOL_SIGNAL(socket:didReadData:withTag:)
        subscribeNext:^(RACTuple *tuple) {
            @strongify(self);
            RACTupleUnpack(GCDAsyncSocket *sock,NSData *data) = tuple;
            if (self.onData) {
                self.onData(data);
            }
            [sock readDataWithTimeout:-1 tag:0];
     }];
    [self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
        @strongify(self);
        [self.socket disconnect];
        [self clean];
    }]];
}

- (void)clean{
    self.socket = nil;
    self.isClosed = YES;
    [self.writeCallbacks removeAllObjects];
    self.onData = nil;
    self.onStatus = nil;
}

- (BOOL)connectToHost:(NSString *)host onPort:(uint16_t)port withTimeout:(NSTimeInterval)timeout error:(NSError * _Nullable __autoreleasing *)errPtr{
    if (timeout <= 0) {
        timeout = -1;
    }
    return [self.socket connectToHost:host
                               onPort:port
                          withTimeout:timeout
                                error:errPtr];
}


- (void)writeData:(NSData *)data timeout:(NSTimeInterval)timeout completion:(uexSocketErrorCompletionBlock)completion{
    if (self.isClosed) {
        if (completion) {
            completion([uexSocketHelper socketAlreadyClosedError]);
        }
        return;
    }
    UInt32 mid = [uexSocketHelper makeMID];
    if (completion) {
        [self.writeCallbacks setObject:completion forKey:@(mid)];
    }
    [self.socket writeData:data withTimeout:timeout tag:mid];
    
}

- (void)closeWithFlag:(uexSocketCloseFlag)flag completion:(uexSocketErrorCompletionBlock)completion{
    if (self.isClosed) {
        if (completion) {
            completion([uexSocketHelper socketAlreadyClosedError]);
        }
        return;
    }
    switch (flag) {
        case uexSocketCloseImmediately: {
            [self.socket disconnect];
            if (completion) {
                completion(nil);
            }
            break;
        }
        case uexSocketCloseWhenIDle: {
            @weakify(self);
            __block RACDisposable *disposable = [TCP_PROTOCOL_SIGNAL(socketDidDisconnect:withError:) subscribeNext:^(RACTuple *tuple) {
                @strongify(self);
                RACTupleUnpack(__unused GCDAsyncSocket *sock,NSError *error) = tuple;
                if (completion) {
                    completion(error);
                }
                [self clean];
                [disposable dispose];
            }];
            [self.socket disconnectAfterWriting];
            break;
        }
    }
    
}
@end
