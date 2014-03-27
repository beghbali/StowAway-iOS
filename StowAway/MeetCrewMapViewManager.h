//
//  MeetCrewMapViewManager.h
//  StowAway
//
//  Created by Vin Pallen on 3/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


@interface MeetCrewMapViewManager : NSObject

-(void)initializeCrew:(NSMutableArray *)crew;

-(void)startUpdatingMapView:(MKMapView *)mapView
     withSuggestedLocations:(NSDictionary *)suggestedLocations andPusherChannel:(NSString *)locationChannel;

-(void)startAutoCheckinMode;


@end
