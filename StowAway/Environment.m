//
//  Environment.m
//  StowAway
//
//  Created by bashir eghbali on 5/14/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "Environment.h"

@implementation Environment
static Environment *_ENV = nil;
NSDictionary* environment;

- (id)init
{
    self = [super init];
    
    if (self) {
        // Do Nada
    }
    
    return self;
}

- (void)initializeSharedInstance
{
    NSString* configuration = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Environment"];
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* envsPListPath = [bundle pathForResource:@
                               "Configurations" ofType:@"plist"];
    NSDictionary* environments = [[NSDictionary alloc] initWithContentsOfFile:envsPListPath];
    environment = [environments objectForKey:configuration];
}

- (NSString*)lookup:(NSString*)key
{
    return [environment valueForKey:key];
}

#pragma mark - Lifecycle Methods

+ (Environment *)ENV
{
    @synchronized(self) {
        if (_ENV == nil) {
            _ENV = [[self alloc] init];
            [_ENV initializeSharedInstance];
        }
        return _ENV;
    }
}

@end
