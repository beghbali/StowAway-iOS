//
//  StowawayConstants.h
//  StowAway
//
//  Created by Vin Pallen on 2/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kPublicId;

//link receipts
extern NSString *const kUserEmail;
extern NSString *const kUserEmailProvider;
extern NSString *const kStowawayEmail;

//gmail OAuth token
extern NSString *const kGmailAccessToken;
extern NSString *const kGmailRefreshToken;

//FB login
extern NSString *const kFirstName;
extern NSString *const kLastName;
extern NSString *const kFbId;
extern NSString *const kUserPublicId;

//APNS
extern NSString *const kDeviceType;
extern NSString *const kDeviceToken;

//ride request
extern NSString *const kPickUpAddress;
extern NSString *const kPickUpDefaultCurrentLocation;
extern NSString *const kDropOffUpAddress;
extern NSString *const kPickUpLat;
extern NSString *const kPickUpLong;
extern NSString *const kDropOffLat;
extern NSString *const kDropOffLong;
extern NSString *const kRequestPublicId;
extern NSString *const kRequestedAt;

//ride result
extern NSString *const kRidePublicId;
extern NSString *const kStatus;
extern NSString *const KStatusFulfilled;
extern NSString *const kStatusCheckedin;
extern NSString *const kStatusMissed;

//crew member
extern NSString *const kIsCaptain;
extern NSString *const kCrewFbImage;
extern NSString *const kCrewFbName;
extern NSString *const kDesignation;
extern NSString *const kDesignationCaptain;
extern NSString *const kIsCheckedIn;


//meet the crew
extern NSString *const kLocationChannel;
extern NSString *const kSuggestedDropOffAddr;
extern NSString *const kSuggestedPickUpAddr;
extern NSString *const kSuggestedDropOffLong;
extern NSString *const kSuggestedDropOffLat;
extern NSString *const kSuggestedPickUpLong;
extern NSString *const kSuggestedPickUpLat;
extern NSString *const kMKPointAnnotation;
extern NSString *const kIsRideFinalized;
extern NSString *const kSuggestedDefaultDropOffAddr;
extern NSString *const kSuggestedDefaultPickUpAddr;

//crew and waiting constants
extern NSUInteger kCountdownTimerMaxSeconds;
extern NSUInteger kMaxCrewCount;

//Pusher
extern NSString *const kPusherApiKey;
extern NSString *const kPusherCrewLocationEvent;
extern double const kPusherCrewWalkingLocationUpdateThreshholdMeters;




