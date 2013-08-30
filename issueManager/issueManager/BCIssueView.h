//
//  BCIssueView.h
//  issueManager
//
//  Created by Vojtech Belovsky on 4/23/13.
//  Copyright (c) 2013 vojta. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BCIssueView : UIView

@property UIImageView *backgroundImageView;
@property UIScrollView *tableViews;
@property UIView *navigationBarView;
@property UIButton *chooseCollaboratorButton;
@property UIButton *addNewIssueButton;
@property UILabel *userNameLabel;
@property int numberOfRepos;
@property NSMutableArray *allTableViews;
@property UILabel *repositoryNameLabel;

-(id)initWithNumberOfRepos:(int)numberOfRepos;
-(void)setUserName:(NSString *)userName;
-(void)setRepoName:(NSString *)repoName;

@end
