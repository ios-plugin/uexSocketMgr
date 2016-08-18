/**
 *
 *	@file   	: uexSocketHelper.h  in EUExSocketMgr
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


#import <Foundation/Foundation.h>



#define UEX_SOCKET_ID NSString *

typedef void (^uexSocketErrorCompletionBlock)(NSError *error);
typedef NS_ENUM(NSInteger,uexSocketCloseFlag){
    uexSocketCloseImmediately = 0,
    uexSocketCloseWhenIDle = 1,
};
typedef NS_ENUM(NSInteger,uexSocketMgrDataType){
    uexSocketMgrDataTypeUTF8 = 0,
    uexSocketMgrDataTypeBase64,
    uexSocketMgrDataTypeGBK,
};

@interface uexSocketHelper: NSObject

+ (UEX_SOCKET_ID)makeSocketID;
+ (UInt32)makeMID;

+ (NSData *)dataFromDataStr:(NSString *)dataStr dataType:(uexSocketMgrDataType)type;
+ (NSString *)dataStrFromData:(NSData *)data dataType:(uexSocketMgrDataType)type;


+ (NSError *)socketAlreadyClosedError;
+ (NSError *)socketTimeoutError;

@end