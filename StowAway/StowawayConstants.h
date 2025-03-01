//
//  StowawayConstants.h
//  StowAway
//
//  Created by Vin Pallen on 2/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import <Foundation/Foundation.h>


//location history
extern NSString *const kPickUpLocationHistoryToWork;
extern NSString *const kPickUpLocationHistoryToHome;
extern NSString *const kDropOffLocationHistoryToWork;
extern NSString *const kDropOffLocationHistoryToHome;
extern NSUInteger kLocationHistorySize;
extern NSString *const kLocationHistoryName; //mkmapitem name
extern NSString *const kLocationHistoryLatitude; //mkmapitem lat
extern NSString *const kLocationHistoryLongitude; //mkmapitem long

//link receipts
extern NSString *const kUserEmail;
extern NSString *const kUserEmailProvider;
extern NSString *const kSupportedEmailProviders[];
extern NSString *const kStowawayEmail;
extern NSString *const kIsUsingStowawayEmail;

//gmail OAuth token
extern NSString *const kGmailAccessToken;
extern NSString *const kGmailRefreshToken;
extern NSString *const kGmailAccessTokenExpiration;

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
extern NSString *const kRequestedForDate;
extern NSString *const kRequestDuration;

extern NSString *const kLastRideToWorkHrs;
extern NSString *const kLastRideToWorkMins;
extern NSString *const kLastRideToHomeHrs;
extern NSString *const kLastRideToHomeMins;

extern NSString *const kPublicId;

//ride result
extern NSString *const kRidePublicId;
extern NSString *const kStatus;
extern NSString *const KStatusFulfilled;
extern NSString *const kStatusCheckedin;
extern NSString *const kStatusMissed;
extern NSString *const kStatusInitiated;

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
extern NSString *const kSuggestedPickUpTime;
extern NSString *const kMKPointAnnotation;
extern NSString *const kSuggestedDefaultDropOffAddr;
extern NSString *const kSuggestedDefaultPickUpAddr;

//crew and waiting constants
extern NSUInteger kMaxCrewCount;
extern NSUInteger kServerPollingIntervalSeconds;

//Pusher
extern NSString *const kPusherCrewLocationEvent;
extern double const kPusherCrewWalkingLocationUpdateThreshholdMeters;

//OnboardingStatus
extern NSString *const kOnboardingStatusReceiptsDone;
extern NSString *const kOnboardingStatusPaymentDone;
extern NSString *const kOnboardingStatusTermsDone;
extern NSString *const kOnboardingStatusTutorialDone;

//animation finding crew
extern double const kFindingCrewFacesAnimationDelay;

//coupon request
extern NSString *const kCouponCodeKey;
extern NSString *const kCouponCodeLoneRider;

//ride credits statement
extern NSString * const kRideCreditsAlertMsgFormat;

//uber api keys
extern NSString *const kUberApiServerToken;

//map annotation
extern NSString *const pickUpPointAnnotationTitle;
extern NSString *const dropOffPointAnnotationTitle;

@interface StowawayConstants: NSObject

+(NSMutableAttributedString *) boldify:(NSString *)boldSubString ofFullString:(NSString *)fullString withFont: (UIFont *)font;

@end


