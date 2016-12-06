//
//  EUExSocketMgr.h
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "uexSocketHelper.h"





typedef NS_ENUM(NSInteger,uexSocketMgrSocketType){
    uexSocketMgrSocketTypeTCP = 0,
    uexSocketMgrSocketTypeUDP,
};

@interface EUExSocketMgr : EUExBase

- (void)onDataCallbackWithOpID:(NSInteger)opid JSONString:(NSString *)json;
- (void)disconnectCallbackWithOpID:(NSInteger)opid;



@end
