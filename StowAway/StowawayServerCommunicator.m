//
//  StowawayServerCommunicator.m
//  StowAway
//
//  Created by Vin Pallen on 2/16/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

#import "StowawayServerCommunicator.h"
#import <Security/Security.h>

@interface StowawayServerCommunicator() <NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLAuthenticationChallengeSender>

@end

@implementation StowawayServerCommunicator

-(BOOL) sendServerRequest:(NSString *)bodyString ForURL: (NSString * )url usingHTTPMethod: (NSString *)method;
{
    NSLog(@"sendServerRequest:: \n url: ## %@ ## \n bodyData: ## %@ ## \n method ## %@ ##", url, bodyString, method);


    if ( !bodyString || !url || !method ) {
        return NO;
    }
    
    NSData      *bodyData   = [bodyString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString    *postLength = [NSString stringWithFormat:@"%d", [bodyData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL         :[NSURL URLWithString:url]];
    [request setHTTPMethod  :method];
    [request setValue       :postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue       :@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody    :bodyData];
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.allowsCellularAccess = YES;
    sessionConfiguration.timeoutIntervalForRequest = 30.0;
    sessionConfiguration.timeoutIntervalForResource = 60.0;

    NSURLSession *session =   [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                            delegate:self
                                                       delegateQueue: [NSOperationQueue mainQueue]];

    
    /*
     sessionConfiguration.HTTPAdditionalHeaders = @{
     @"api-key"       : @"API_KEY",
     };
     */
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSURLSessionDataTask *postDataTask = [session
                                          dataTaskWithRequest:request
                                          completionHandler:^(NSData *jsonData,
                                                              NSURLResponse *response,
                                                              NSError *error)
                                          {
                                              [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                              
                                              
                                              NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                                              
                                              NSLog(@"httpResp.statusCode %d, error %@",httpResp.statusCode , error );
                                              
                                              if (error ||
                                                  ([method isEqualToString: @"POST"] && (httpResp.statusCode != 201)) ||
                                                  ([method isEqualToString: @"PUT"] && (httpResp.statusCode != 200)) )   //201=post successful
                                              {
                                                  NSLog(@"ERROR !!" );
                                                  [self.sscDelegate gotServerResponse:nil error:error];
                                                  
                                              } else
                                              {
                                                  NSDictionary *results = jsonData ?
                                                  [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error]: nil;
                                                  
                                                  [self.sscDelegate gotServerResponse:results error:error];
                                              }
                                          }];
    
    [postDataTask resume];
    
    return YES;
}


#pragma mark - SSL

- (NSURLCredential *) getSSLCertificateCredentials
{
    NSString *certPath = [[NSBundle mainBundle] pathForResource:@"certificate" ofType:@"cer"];
    NSData *certData = [[NSData alloc] initWithContentsOfFile:certPath];
    
    SecIdentityRef myIdentity = NULL;
    
    SecCertificateRef myCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
    SecCertificateRef certArray[1] = { myCert };
    CFArrayRef myCerts = CFArrayCreate(NULL, (void *)certArray, 1, NULL);
    NSURLCredential *credential = [NSURLCredential credentialWithIdentity:myIdentity
                                            certificates:(__bridge NSArray *)myCerts
                                             persistence:NSURLCredentialPersistencePermanent];
    
    return credential;
}

#pragma mark - delegate methods

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    
}


/* The task has received a request specific authentication challenge.
 * If this delegate is not implemented, the session specific authentication challenge
 * will *NOT* be called and the behavior will be the same as using the default handling
 * disposition.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                            didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                              completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    
}


@end
