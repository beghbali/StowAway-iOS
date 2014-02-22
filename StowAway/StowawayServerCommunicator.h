//
//  StowawayServerCommunicator.h
//  StowAway
//
//  Created by Vin Pallen on 2/16/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol StowawayServerCommunicatorDelegate <NSObject>

- (void)stowawayServerCommunicatorResponse:(NSDictionary *)data error:(NSError *)error;

@end

@interface StowawayServerCommunicator : NSObject

@property (nonatomic, weak) id<StowawayServerCommunicatorDelegate> sscDelegate;

-(BOOL) sendServerRequest:(NSString *)bodyString ForURL: (NSString * )url usingHTTPMethod: (NSString *)method;

@end
