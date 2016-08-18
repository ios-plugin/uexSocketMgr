/**
 *
 *	@file   	: uexSocketUDPClient.h  in EUExSocketMgr
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

#import "uexSocketHelper.h"

NS_ASSUME_NONNULL_BEGIN;

typedef void (^uexSocketUDPOndataBlock)(NSString *host,UInt16 port,NSData *data);

@interface uexSocketUDPClient: NSObject
@property (nonatomic,strong)UEX_SOCKET_ID identifier;
@property (nonatomic,assign)uexSocketMgrDataType dataType;

- (nullable instancetype)initWithPort:(UInt16)port
                          onDataBlock:(uexSocketUDPOndataBlock)onData;

- (void)sendData:(NSData *)data
          toHost:(NSString *)host
            port:(UInt16)port
         timeout:(NSTimeInterval)timeout
      completion:(uexSocketErrorCompletionBlock)completion;




- (void)closeWithFlag:(uexSocketCloseFlag)flag completion:(uexSocketErrorCompletionBlock)completion;



@end
NS_ASSUME_NONNULL_END;