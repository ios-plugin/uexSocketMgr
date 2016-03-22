//
//  EUExBase.h
//
//  Created by zywx on 11-8-25.
//  Copyright 2011 zywx. All rights reserved.
//
@class EBrowserView;
@interface EUExBase :NSObject {	
	EBrowserView *meBrwView;
}
@property (nonatomic, assign) EBrowserView *meBrwView;
- (id)initWithBrwView:(EBrowserView *)eInBrwView;
- (void)jsSuccessWithName:(NSString *)inCallbackName opId:(NSInteger)inOpId dataType:(NSInteger)inDataType strData:(NSString*)inData;
- (void)jsSuccessWithName:(NSString *)inCallbackName opId:(NSInteger)inOpId dataType:(NSInteger)inDataType intData:(NSInteger)inData;
- (void)jsFailedWithOpId:(int)inOpId errorCode:(int)inErrorCode errorDes:(NSString*)inErrorDes;
- (void)clean;
- (void)stopNetService;
- (NSString*)absPath:(NSString*)inPath;
@end



