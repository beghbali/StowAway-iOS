//
//  StowawayConstants.m
//  StowAway
//
//  Created by Vin Pallen on 2/17/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "StowawayConstants.h"


NSString *const kUserEmail          = @"email";
NSString *const kUserEmailProvider  = @"email_provider";
NSString *const kFirstName          = @"first_name";
NSString *const kLastName           = @"last_name";
NSString *const kPublicId           = @"public_id";
NSString *const kUserPublicId       = @"user_public_id";
NSString *const kFbId               = @"uid";
NSString *const kGmailAccessToken   = @"gmail_access_token";
NSString *const kGmailRefreshToken  = @"gmail_refresh_token";
NSString *const kStowawayEmail      = @"stowaway_email";

//APNS
NSString *const kDeviceType         = @"device_type";
NSString *const kDeviceToken        = @"device_token";

//ride request
NSString *const kPickUpAddress                  = @"pickup_address";
NSString *const kDropOffUpAddress               = @"dropoff_address";
NSString *const kPickUpLat                      = @"pickup_lat";
NSString *const kPickUpLong                     = @"pickup_lng";
NSString *const kDropOffLat                     = @"dropoff_lat";
NSString *const kDropOffLong                    = @"dropoff_lng";
NSString *const kRequestPublicId                = @"request_public_id";
NSString *const kRequestedAt                    = @"requested_at";
NSString *const kPickUpDefaultCurrentLocation   = @"Current Location";

//ride result
NSString *const kRidePublicId           = @"ride_public_id";
NSString *const kStatus                 = @"status";
NSString *const KStatusFulfilled        = @"fulfilled";
NSString *const kStatusCheckedin        = @"checkedin";
NSString *const kStatusMissed           = @"missed";

//crew member
NSString *const kIsCaptain              = @"isCaptain";
NSString *const kCrewFbImage            = @"crewFbImage";
NSString *const kCrewFbName             = @"crewFbName";
NSString *const kDesignation            = @"designation";
NSString *const kDesignationCaptain     = @"captain";
NSString *const kIsCheckedIn            = @"isCheckedIn";

//meet the crew
NSString *const kLocationChannel                = @"location_channel";
NSString *const kSuggestedDropOffAddr           = @"suggested_dropoff_address";
NSString *const kSuggestedPickUpAddr            = @"suggested_pickup_address";
NSString *const kSuggestedDropOffLong           = @"suggested_dropoff_lng";
NSString *const kSuggestedDropOffLat            = @"suggested_dropoff_lat";
NSString *const kSuggestedPickUpLong            = @"suggested_pickup_lng";
NSString *const kSuggestedPickUpLat             = @"suggested_pickup_lat";
NSString *const kMKPointAnnotation              = @"mapPoint";
NSString *const kIsRideFinalized                = @"isRideFinalized";
NSString *const kSuggestedDefaultDropOffAddr    = @"suggested dropoff location";
NSString *const kSuggestedDefaultPickUpAddr     = @"suggested pickup location";

//countdown timer
NSUInteger kCountdownTimerMaxSeconds    = (60*5); //5mins
NSUInteger kMaxCrewCount                = 4; //1 captain + 3 stowaways

//Pusher
NSString *const kPusherApiKey                                   = @"403b5fc6f392db2fe167";
NSString *const kPusherCrewLocationEvent                        = @"client-location-update";
double const kPusherCrewWalkingLocationUpdateThreshholdMeters   = 5; //5meters == 16feet


//OnboardingStatus
NSString *const kOnboardingStatusReceiptsDone   = @"OnboardingStatusReceiptsDone";
NSString *const kOnboardingStatusPaymentDone    = @"OnboardingStatusPaymentDone";
NSString *const kOnboardingStatusTermsDone      = @"OnboardingStatusTermsDone";


