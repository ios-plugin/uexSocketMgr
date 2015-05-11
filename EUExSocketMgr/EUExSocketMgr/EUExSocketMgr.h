//
//  EUExSocketMgr.h
//  WBPalm
//
//  Created by AppCan on 11-9-8.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUExBase.h"

#define F_TYEP_TCP				0
#define F_TYEP_UDP				1

@interface EUExSocketMgr : EUExBase {
	NSMutableDictionary *sobjDict;
    int dataType;
}

- (void)uexSocketWithOpId:(int)inOpId data:(NSString*)inData;
-(void)uexSocketDidDisconnect:(NSString *)opid;
@end
