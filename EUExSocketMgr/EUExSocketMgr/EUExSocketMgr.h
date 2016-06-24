//
//  EUExSocketMgr.h
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>





typedef NS_ENUM(NSInteger,uexSocketMgrDataType){
    uexSocketMgrDataTypeUTF8 = 0,
    uexSocketMgrDataTypeBase64,
    uexSocketMgrDataTypeGBK,
};
typedef NS_ENUM(NSInteger,uexSocketMgrSocketType){
    uexSocketMgrSocketTypeTCP = 0,
    uexSocketMgrSocketTypeUDP,
};

@interface EUExSocketMgr : EUExBase

- (void)onDataCallbackWithOpID:(NSInteger)opid JSONString:(NSString *)json;
- (void)disconnectCallbackWithOpID:(NSInteger)opid;



@end
