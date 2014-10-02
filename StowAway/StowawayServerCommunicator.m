//
//  StowawayServerCommunicator.m
//  StowAway
//
//  Created by Vin Pallen on 2/16/14.
//  Copyright (c) 2014 StowAway. All rights reserved.
//

//TODO: create a network health monitor - which can inform the ui if there is no network connectivity

#import "StowawayServerCommunicator.h"
#import <Security/Security.h>

@interface StowawayServerCommunicator() <NSURLSessionDelegate, NSURLSessionDataDelegate>//, NSURLAuthenticationChallengeSender>

@end

@implementation StowawayServerCommunicator

-(BOOL) sendServerRequest:(NSString *)bodyString ForURL: (NSString * )url usingHTTPMethod: (NSString *)method;
{
#ifdef DEBUG
    NSLog(@"sendServerRequest:: \n url: ## %@ ## \n bodyData: ## %@ ## \n method ## %@ ##", url, bodyString, method);
#endif
    if (!url || !method ) {
        return NO;
    }
    
    NSData      *bodyData   = [bodyString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString    *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[bodyData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL         :[NSURL URLWithString:url]];
    [request setHTTPMethod  :method];
    [request setValue       :postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue       :@"application/json" forHTTPHeaderField:@"Content-Type"];

    if ([bodyString isEqualToString:@"uber"])
    {
        NSString *authStr = [NSString stringWithFormat:@"Token %@", kUberApiServerToken];
        [request setValue:authStr forHTTPHeaderField:@"Authorization"];
    }
    else
    {
        [request setHTTPBody    :bodyData];
    }

    
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.allowsCellularAccess = YES;
    sessionConfiguration.timeoutIntervalForRequest = 30.0;
    sessionConfiguration.timeoutIntervalForResource = 60.0;

    NSURLSession *session =   [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                            delegate:self
                                                       delegateQueue: nil];

    
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
                                              
                                              NSLog(@"%s: httpResp.statusCode %ld, error %@", __func__, (long)httpResp.statusCode , error );
                                              
                                              if (error ||
                                                  ([method isEqualToString: @"POST"] && (httpResp.statusCode != 201)) ||
                                                  ([method isEqualToString: @"PUT"] && (httpResp.statusCode != 200)) )   //201=post successful
                                              {
                                                  NSLog(@"SSCommunicator: error !!" );
                                                  NSError * sscError = [NSError errorWithDomain:@"http error" code:httpResp.statusCode userInfo:nil];
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      [self.sscDelegate stowawayServerCommunicatorResponse:nil error:sscError];});
                                                  
                                              } else
                                              {
                                                  NSDictionary *results = jsonData ?
                                                  [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error]: nil;
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      //NSLog(@"\n.........%@, %@...self.sscDelegate  %@\n", results, error, self.sscDelegate );
                                                      [self.sscDelegate stowawayServerCommunicatorResponse:results error:error];});
                                              }
                                          }];
    
    [postDataTask resume];
    
    return YES;
}

/*
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
    NSLog(@"%s:", __func__);
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSLog(@"%s:", __func__);
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSLog(@"%s:", __func__);
}


- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSLog(@"%s:......................", __func__);
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                            didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                              completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSLog(@"%s:", __func__);
    
}
*/

@end
