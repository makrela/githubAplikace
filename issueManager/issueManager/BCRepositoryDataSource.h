//
//  BCRepositoryDataSource.h
//  issueManager
//
//  Created by Vojtech Belovsky on 4/22/13.
//  Copyright (c) 2013 vojta. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BCRepository;

@interface BCRepositoryDataSource : NSObject<UITableViewDataSource>{
@private
    NSArray *_repositories;
}

- (id)initWithRepositories:(NSArray *)repositories;

-(BCRepository *)getRepositoryAtIndex:(NSUInteger)row;
@end
