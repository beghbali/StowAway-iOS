//
//  Environment.h
//  StowAway
//
//  Created by bashir eghbali on 5/14/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Environment : NSObject
- (NSString*)lookup:(NSString*)key;
@end
static Environment *ENV;