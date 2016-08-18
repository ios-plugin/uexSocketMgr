/**
 *
 *	@file   	: uexSocketHelper.m  in EUExSocketMgr
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


#import "uexSocketHelper.h"

static NSStringEncoding kGBKStringEncoding = 0;
static UInt32 currentMID = 0;
static NSString *const kUexSocketManagerErrorDomain = @"com.appcan.uexSocketManager.errorDomain";

@implementation uexSocketHelper
+ (void)initialize{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kGBKStringEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    });
}


+ (UInt32)makeMID{
    currentMID++;
    return currentMID;
}

+ (UEX_SOCKET_ID)makeSocketID{
    return [NSUUID UUID].UUIDString;
}
+ (NSData *)dataFromDataStr:(NSString *)dataStr dataType:(uexSocketMgrDataType)type{
    NSData *data = nil;
    switch (type) {
        case uexSocketMgrDataTypeUTF8: {
            data = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
            break;
        }
        case uexSocketMgrDataTypeBase64: {
            data = [[NSData alloc]initWithBase64EncodedString:dataStr options:0];
            break;
        }
        case uexSocketMgrDataTypeGBK: {
            data = [dataStr dataUsingEncoding:kGBKStringEncoding];
            break;
        }
    }
    return data;
}

+ (NSString *)dataStrFromData:(NSData *)data dataType:(uexSocketMgrDataType)type{
    NSString *dataStr = nil;
    switch (type) {
        case uexSocketMgrDataTypeUTF8: {
            dataStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            break;
        }
        case uexSocketMgrDataTypeBase64: {
            dataStr = [data base64EncodedStringWithOptions:0];
            break;
        }
        case uexSocketMgrDataTypeGBK: {
            dataStr = [[NSString alloc]initWithData:data encoding:kGBKStringEncoding];
            break;
        }
    }
    return dataStr;
}

+ (NSError *)socketTimeoutError{
    return [NSError errorWithDomain:kUexSocketManagerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"socket time out!"}];
}
+ (NSError *)socketAlreadyClosedError{
    return [NSError errorWithDomain:kUexSocketManagerErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey: @"socket has already closed!"}];
}

@end