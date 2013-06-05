//
//  BCOrg.h
//  issueManager
//
//  Created by Vojtech Belovsky on 6/4/13.
//  Copyright (c) 2013 vojta. All rights reserved.
//

#import <Mantle/Mantle.h>
@class BCUser;

@interface BCOrg : MTLModel

@property (nonatomic, copy, readonly) NSString *orgLogin;
@property (nonatomic, copy, readonly) NSNumber *orgId;
@property (nonatomic, copy, readonly) NSURL *avatarUrl;
@property (nonatomic, copy, readonly) NSURL *htmlUrl;
+ (void)getAllOrgsFromUser:(BCUser *)user WithSuccess:(void (^)(NSArray *allOrgs))success failure:(void(^) (NSError *error)) failure;

@end
