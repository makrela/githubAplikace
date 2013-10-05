//
//  BCIssueViewController.m
//  issueManager
//
//  Created by Vojtech Belovsky on 4/23/13.
//  Copyright (c) 2013 vojta. All rights reserved.
//

#import "BCIssueViewController.h"
#import "BCRepository.h"
#import "BCIssue.h"
#import "BCIssueView.h"
#import "BCIssueDataSource.h"
#import "BCIssueDetailViewController.h"
#import "BCAddIssueViewController.h"
#import "UIAlertView+errorAlert.h"
#import "BCUser.h"
#import <QuartzCore/QuartzCore.h>
#import "BCIssueTitleLabel.h"
#import "BCLabelView.h"
#import "BCLabel.h"
#import "BCHeadeView.h"
#import "BCIssueCell.h"
#import "BCCollaboratorsViewController.h"
#import "BCAppDelegate.h"
#import "TMViewDeckController.h"
#import "UIScrollView+SVPulltoRefresh.h"
#import "BCRepositoryViewController.h"

#define GRAY_FONT_COLOR       [UIColor colorWithRed:.55 green:.55 blue:.55 alpha:1.00]
#define WHITE_COLOR           [UIColor whiteColor]
#define HEADER_HEIGHT         ( 20.0f )
#define FOOTER_HEIGHT         ( 30.0f )

#define MILESTONES_KEY      @"milestones"
#define ISSUES_KEY          @"issues"
#define ANIMATION_DURATION  ( 0.3 )

@interface BCIssueViewController ()

@end

@implementation BCIssueViewController

#pragma mark -
#pragma mark lifecycles

- (id) initWithRepositories:(NSArray *)repositories andLoggedInUser:(BCUser *)user{
  self = [super init];
    if(self){
      _repositories = repositories;
      _nthRepository = 0;
      _userChanged = NO;
      _isShownRepoVC = NO;
      _allDataSources = [[NSMutableArray alloc] init];
      _slideBack = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(slideBackCenterView)];
      [self getAllCollaborators];
      _currentUser = user;
    }
  return self;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
  int index = [_tableView.tableViews indexOfObject:tableView];
  BCIssueDetailViewController *issueDetailViewController = [[BCIssueDetailViewController alloc] initWithIssue:[self getIssueForIndexPath:indexPath fromNthRepository:index] andController:self];
  [self presentViewController:issueDetailViewController animated:YES completion:nil];
}

- (void)loadView {
  _tableView = [[BCIssueView alloc] initWithNumberOfRepos:[_repositories count]];
  [_tableView.scrollViewForTableViews setDelegate:self];
  [_tableView.addNewIssueButton addTarget:self action:@selector(addButtonDidPress) forControlEvents:UIControlEventTouchUpInside];
  [_tableView.chooseCollaboratorButton addTarget:self action:@selector(chooseButtonDidPress) forControlEvents:UIControlEventTouchUpInside];
  [_tableView setRepoName:[(BCRepository *)[_repositories objectAtIndex:_nthRepository] name]];
  
  for(__weak UITableView *tableView in _tableView.tableViews){
    [tableView addPullToRefreshWithActionHandler:^{
      __block BCUser *currentUser = [_currentUser copy];
      __block int currentRepozitoryNumber = _nthRepository;
      __block BCRepository *currentRepozitory = [_repositories objectAtIndex:currentRepozitoryNumber];
      
      [tableView beginUpdates];
      [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        [tableView setAlpha:0.5];
      }];
      [BCRepository getAllMilestonesOfRepository:currentRepozitory withSuccess:^(NSMutableArray *allMilestones) {
        [BCIssue getIssuesFromRepository:currentRepozitory forUser:currentUser WithSuccess:^(NSMutableArray *issues){
          if (![issues count]) {
            [issues addObject:[[BCIssue alloc] initNoIssues]];
          }
          BCIssueDataSource *currentDataSource = [[BCIssueDataSource alloc] initWithIssues:issues withMilestones:allMilestones withCurrentUser:_currentUser];
          [_allDataSources replaceObjectAtIndex:currentRepozitoryNumber withObject:currentDataSource];
          [tableView setDataSource:currentDataSource];
          [tableView reloadData];
          [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            [tableView setAlpha:1];
          }];
          [tableView endUpdates];
          [tableView.pullToRefreshView stopAnimating];
        } failure:^(NSError *error) {
          [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            [tableView setAlpha:1];
          }];
          [tableView endUpdates];
          [tableView.pullToRefreshView stopAnimating];
          [UIAlertView showWithError:error];
        }];
      } failure:^(NSError *error) {
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
          [tableView setAlpha:1];
        }];
        [tableView endUpdates];
        [tableView.pullToRefreshView stopAnimating];
        [UIAlertView showWithError:error];
      }];
    }];
    [tableView.pullToRefreshView setTextColor:GRAY_FONT_COLOR];
    [tableView.pullToRefreshView setTitle:@"Loading new content..." forState:SVPullToRefreshStateLoading];
  }
  
  self.view = _tableView;
  [self createModel];
  for (int i = 0; i < [_repositories count]; i++) {
    [[_tableView.tableViews objectAtIndex:i] setDelegate:self];
  }
}

-(void)viewDidLoad{
  UIRefreshControl *refreshControl = [[UIRefreshControl alloc]
                                      init];
  refreshControl.tintColor = [UIColor magentaColor];
  [refreshControl addTarget:self action:@selector(createModel) forControlEvents:UIControlEventValueChanged];
  self.refreshControl = refreshControl;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  int index = [_tableView.tableViews indexOfObject:tableView];
  BCIssue *currentIssue = [self getIssueForIndexPath:indexPath fromNthRepository:index];
  return [BCIssueCell heightOfCellWithIssue:currentIssue width:ISSUE_WIDTH titleFont:CELL_TITLE_FONT offset:OFFSET];
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
  int index = [_tableView.tableViews indexOfObject:tableView];
  BCHeadeView *headerView;
  if ([_allDataSources count] > index) {
    BCIssueDataSource *currentDataSource = [_allDataSources objectAtIndex:index];
    BCIssue *currentIssue = [[currentDataSource.dataSource objectForKey:[currentDataSource.dataSourceKeyNames objectAtIndex:section]] objectAtIndex:0];
    if ([currentIssue.title isEqualToString:NO_ISSUES]) {
      return [[BCHeadeView alloc] init];
    }
    headerView = [[BCHeadeView alloc] initWithFrame:CGRectMake(0, _tableView.navigationBarView.frame.size.height, _tableView.frame.size.width, HEADER_HEIGHT) andMilestone:currentIssue.milestone];
    return headerView;
  }else{
    return [[BCHeadeView alloc] init];
  }
}

-(UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
  return [[UIView alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
  return HEADER_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
  return FOOTER_HEIGHT;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
  if (scrollView == _tableView.scrollViewForTableViews) {
    int contentOffset = scrollView.contentOffset.x;
    if (contentOffset < 0 && !_isShownRepoVC) {
      [_tableView.scrollViewForTableViews setUserInteractionEnabled:NO];
      _isShownRepoVC = YES;
      BCAppDelegate *myDelegate = [[UIApplication sharedApplication] delegate];
      [myDelegate.deckController slideCenterControllerToTheRightWithLeftController:      [[BCRepositoryViewController alloc] initWithRepositories:[NSMutableArray arrayWithArray:_repositories] andLoggedInUser:[BCUser sharedInstanceWithSuccess:nil failure:nil]] animated:YES withCompletion:nil];
      [self.view addGestureRecognizer:_slideBack];
      [_tableView.scrollViewForTableViews setUserInteractionEnabled:NO];
      [_tableView.chooseCollaboratorButton setEnabled:NO];
    }
    if (contentOffset%(int)self.view.frame.size.width == 0) {
      int originalOffset = _nthRepository*self.view.frame.size.width;
      if (contentOffset != originalOffset) {
        if (contentOffset < originalOffset) {
          _nthRepository--;
          [_tableView setRepoName:[(BCRepository *)[_repositories objectAtIndex:_nthRepository] name]];
          [_tableView animatePaginatorWithCurrentRepoNumber:_nthRepository];
        }else{
          _nthRepository++;
          [_tableView setRepoName:[(BCRepository *)[_repositories objectAtIndex:_nthRepository] name]];
          [_tableView animatePaginatorWithCurrentRepoNumber:_nthRepository];
        }
      }
    }
  }
}

#pragma mark -
#pragma mark buttonActions

- (void)addButtonDidPress{
  BCAddIssueViewController *addIssueVC = [[BCAddIssueViewController alloc] initWithRepository:[_repositories objectAtIndex:_nthRepository] withController:self withCurrentUser:_currentUser];
  [self.navigationController pushViewController:addIssueVC animated:YES];
}

-(void)chooseButtonDidPress{
  [UIView animateWithDuration:ANIMATION_DURATION animations:^{
    [[_tableView.tableViews objectAtIndex:_nthRepository] setAlpha:0.0];
  }];
  BCCollaboratorsViewController *chooseCollVC = [[BCCollaboratorsViewController alloc] initWithCollaborators:_allCollaborators andIssueViewCtrl:self];
  [self.view addGestureRecognizer:_slideBack];
  [_tableView.scrollViewForTableViews setUserInteractionEnabled:NO];
  [_tableView.chooseCollaboratorButton setEnabled:NO];
  BCAppDelegate *myDelegate = [[UIApplication sharedApplication] delegate];
  [myDelegate.deckController slideCenterControllerToTheRightWithLeftController:chooseCollVC animated:YES withCompletion:nil];
//  [self.navigationController pushViewController:chooseCollVC animated:YES];
}

#pragma mark -
#pragma mark public

-(void)slideBackCenterView{
  BCAppDelegate *myDelegate = [[UIApplication sharedApplication] delegate];
  if ([myDelegate.deckController leftControllerPresented]) {
    if (_userChanged) {
      [self createModel];
      _userChanged = NO;
    }else{
      [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        [[_tableView.tableViews objectAtIndex:_nthRepository] setAlpha:1];
      }];
    }
    [_tableView.chooseCollaboratorButton setEnabled:YES];
    [self.view removeGestureRecognizer:_slideBack];
    [_tableView.scrollViewForTableViews setUserInteractionEnabled:YES];
    [myDelegate.deckController slideCenterControllerBackAnimated:YES withCompletion:nil];
    _isShownRepoVC = NO;
  }
}

-(void)addNewIssue:(BCIssue *)newIssue{
  BCIssueDataSource *currentDataSource = [_allDataSources objectAtIndex:_nthRepository];
  [currentDataSource addNewIssue:newIssue];
  [[_tableView.tableViews objectAtIndex:_nthRepository] setDataSource:currentDataSource];
}

//to the future, for changing issues
-(void)changeIssue:(BCIssue *)issue forNewIssue:(BCIssue*)newIssue{
  [[_allDataSources objectAtIndex:_nthRepository] changeIssue:issue forNewIssue:newIssue];
}

-(void)removeIssue:(BCIssue *)issue{
  [[_allDataSources objectAtIndex:_nthRepository] removeIssue:issue];
}

#pragma mark -
#pragma mark private

//-(void)reloadDataInTableView:(UITableView*)tableView{
//  [UIView animateWithDuration:0.2 animations:^{
//    [tableView setAlpha:0];
//  } completion:^(BOOL finished) {
//    [tableView reloadData];
//    [UIView animateWithDuration:0.2 animations:^{
//      [tableView setAlpha:1];
//    }];
//  }];
//}

-(BCIssue *)getIssueForIndexPath:(NSIndexPath *)indexPath fromNthRepository:(int)nthRepository{
  BCIssueDataSource *currentDataSource = [_allDataSources objectAtIndex:nthRepository];
  BCIssue *myIssue = [[currentDataSource.dataSource objectForKey:[currentDataSource.dataSourceKeyNames objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
  return myIssue;
}

-(void)createModel{
  [_tableView.activityIndicatorView startAnimating];
  __block int i = 0;
  __block BCUser *currentUser = [_currentUser copy];
  [_tableView setUserName:currentUser.userLogin];
  __block void (^myFailureBlock) (NSError *error) = [^(NSError *error){
    [_tableView.activityIndicatorView stopAnimating];
    [UIAlertView showWithError:error];
  } copy];
  __block void (^milestonesSuccessBlock) (NSMutableArray *milestones);
  milestonesSuccessBlock = [^(NSMutableArray *milestones) {
    [BCIssue getIssuesFromRepository:[_repositories objectAtIndex:i] forUser:currentUser WithSuccess:^(NSMutableArray *issues){
      if (![issues count]) {
        [issues addObject:[[BCIssue alloc] initNoIssues]];
      }
      BCIssueDataSource *currentDataSource = [[BCIssueDataSource alloc] initWithIssues:issues withMilestones:milestones withCurrentUser:_currentUser];
      if ( _allDataSources.count > i ){
        [_allDataSources replaceObjectAtIndex:i withObject:currentDataSource];
      } else {
        [_allDataSources addObject:currentDataSource];
      }
      UITableView *currentTableView = [_tableView.tableViews objectAtIndex:i];
      [currentTableView setDataSource:currentDataSource];
      [currentTableView reloadData];
      i++;
      [UIView animateWithDuration:0.5 animations:^{
        [currentTableView setAlpha:1];
      }];
      if (i != [_repositories count]) {
        [BCRepository getAllMilestonesOfRepository:[_repositories objectAtIndex:i] withSuccess:milestonesSuccessBlock failure:myFailureBlock];
      }else{
        [_tableView.activityIndicatorView stopAnimating];
      }
    }failure:myFailureBlock];
  } copy];
  
  [BCRepository getAllMilestonesOfRepository:[_repositories objectAtIndex:i] withSuccess:milestonesSuccessBlock failure:myFailureBlock];
}

-(void)getAllCollaborators{
  __block int i = 0;
  __block BCRepository *currentRepo = [_repositories objectAtIndex:i];
  __block NSMutableArray *allCollaborators = [[NSMutableArray alloc] init];
  __block void (^myFailureBlock) (NSError *error) = [^(NSError *error) {
    [UIAlertView showWithError:error];
  } copy];
  __block void (^mySuccessBlock) (NSArray *collaborators);
  mySuccessBlock = [^(NSArray *collaborators){
    for (BCUser *newCollaborator in collaborators) {
      BOOL addCollaborator = YES;
      int numberOfCollaborators = [allCollaborators count];
      if (numberOfCollaborators) {
        for (int i = 0; i < numberOfCollaborators; i++){
          BCUser *currentCollaborator = [allCollaborators objectAtIndex:i];
          if ([currentCollaborator.userId isEqualToNumber:newCollaborator.userId]) {
            addCollaborator = NO;
          }
        }
        if (addCollaborator) {
          [allCollaborators addObject:newCollaborator];
        }
      }else{
        [allCollaborators addObject:newCollaborator];
      }
    }
    i++;
    if ([_repositories count] == i) {
      _allCollaborators = allCollaborators;
    }else{
      currentRepo = [_repositories objectAtIndex:i];
      [BCRepository getAllCollaboratorsOfRepository:currentRepo withSuccess:mySuccessBlock failure:myFailureBlock];
    }
  } copy];
  [BCRepository getAllCollaboratorsOfRepository:currentRepo withSuccess:mySuccessBlock failure:myFailureBlock];
}


@end
