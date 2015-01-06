//
//  LSConversationListViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/29/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSUIConversationListViewController.h"
#import "SVProgressHUD.h"
#import "LSUser.h"
#import "LSUIConversationViewController.h"
#import "LSSettingsTableViewController.h"
#import "LSConversationDetailViewController.h"

@interface LSUIConversationListViewController () <LYRUIConversationListViewControllerDelegate, LYRUIConversationListViewControllerDataSource, LSSettingsTableViewControllerDelegate, UIActionSheetDelegate>

@end

@implementation LSUIConversationListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.delegate = self;
    self.dataSource = self;
    
    // Left navigation item
    if (self.shouldDisplaySettingsItem) {
        UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(settingsButtonTapped)];
        settingsButton.accessibilityLabel = @"Settings Button";
        [self.navigationItem setLeftBarButtonItem:settingsButton];
    }

    // Right navigation item
    UIBarButtonItem *composeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                                   target:self
                                                                                   action:@selector(composeButtonTapped)];
    composeButton.accessibilityLabel = @"Compose Button";
    [self.navigationItem setRightBarButtonItem:composeButton];
}

#pragma mark Conversation List View Controller Delegate Methods

/**
 
 LAYER UI KIT - Allows your application to react to a conversation selection. This application pushses a subclass of 
 the `LYRUIConversationViewController` component.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didSelectConversation:(LYRConversation *)conversation
{
    [self presentControllerWithConversation:conversation];
}

/**
 
 LAYER UI KIT - Allows your application react to a conversations deletion if necessary. This application does not 
 need to react because the superclass component will handle removing the conversation in response to a deletion.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didDeleteConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode
{
    NSLog(@"Conversation Successsfully Deleted");
}

/**
 
 LAYER UI KIT - Allows your application react to a failed conversation deletion if necessary.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didFailDeletingConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode error:(NSError *)error
{
    NSLog(@"Conversation Deletion Failed with Error: %@", error);
}

#pragma mark Conversation List View Controller Data Source Methods

/**
 
 LAYER UI KIT - Returns a label that is used to represent the conversation. This application puts the 
 name representing the `lastMessage.sentByUserID` property first in the string.
 
 */
- (NSString *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController labelForConversation:(LYRConversation *)conversation
{
    NSString *conversationName = conversation.metadata[LYRUIConversationNameTag];
    if (conversationName) {
        return conversationName;
    }
    
    if (!self.layerClient.authenticatedUserID) return @"Not auth'd";

    NSMutableSet *participantIdentifiers = [conversation.participants mutableCopy];
    if (self.layerClient.authenticatedUserID) {
        [participantIdentifiers removeObject:self.layerClient.authenticatedUserID];
    }
    
    if (participantIdentifiers.count == 0) return @"Personal Conversation";
    
    NSMutableSet *participants = [[self.applicationController.persistenceManager participantsForIdentifiers:participantIdentifiers] mutableCopy];
    if (participants.count == 0) return @"No Matching Participants";
    
    // Put the latest message sender's name first
    NSMutableArray *fullNames = [NSMutableArray new];
    for (id<LYRUIParticipant> participant in participants) {
        if (!participant.fullName) continue;
        if ([conversation.lastMessage.sentByUserID isEqualToString:participant.participantIdentifier]) {
            [fullNames insertObject:participant.fullName atIndex:0];
        } else {
            [fullNames addObject:participant.fullName];
        }
    }

    NSString *fullNamesString = [fullNames componentsJoinedByString:@", "];
    return fullNamesString;
}

/**
 
 LAYER UI KIT - If needed, your application can display an avatar image that represnts a conversation. If no image 
 is returned, no image will be displayed.
 
 */
- (UIImage *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController imageForConversation:(LYRConversation *)conversation
{
    return nil;
}

#pragma mark Selected Conversation Methods

- (void)presentControllerWithConversation:(LYRConversation *)conversation
{
    LSUIConversationViewController *existingConversationViewController;
    NSUInteger listViewControllerIndex = [self.navigationController.viewControllers indexOfObject:self];
    if (listViewControllerIndex + 1 < self.navigationController.viewControllers.count) {
        id nextViewController = [self.navigationController.viewControllers objectAtIndex:listViewControllerIndex + 1];
        if ([nextViewController isKindOfClass:[LSUIConversationViewController class]]) {
            existingConversationViewController = nextViewController;
        }
    }
    if (existingConversationViewController && existingConversationViewController.conversation == conversation) {
        if (self.navigationController.topViewController == existingConversationViewController) return;
        [self.navigationController popToViewController:existingConversationViewController animated:YES];
        return;
    }

    LSUIConversationViewController *conversationViewController = [LSUIConversationViewController conversationViewControllerWithConversation:conversation layerClient:self.applicationController.layerClient];
    conversationViewController.applicationController = self.applicationController;
    conversationViewController.showsAddressBar = YES;
    if (self.navigationController.topViewController == self) {
        [self.navigationController pushViewController:conversationViewController animated:YES];
    } else {
        NSMutableArray *viewControllers = [self.navigationController.viewControllers mutableCopy];
        NSRange replacementRange = NSMakeRange(listViewControllerIndex + 1, viewControllers.count - listViewControllerIndex - 1);
        [viewControllers replaceObjectsInRange:replacementRange withObjectsFromArray:@[conversationViewController]];
        [self.navigationController setViewControllers:viewControllers animated:YES];
    }
}

#pragma mark - Bar Button Functionality Methods

- (void)settingsButtonTapped
{
    LSSettingsTableViewController *settingsTableViewController = [[LSSettingsTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    settingsTableViewController.applicationController = self.applicationController;
    settingsTableViewController.settingsDelegate = self;
    
    UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:settingsTableViewController];
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

- (void)composeButtonTapped
{
    [self presentControllerWithConversation:nil];
}

#pragma mark - Push Notification Selection Method

- (void)selectConversation:(LYRConversation *)conversation
{
    if (conversation) {
        [self presentControllerWithConversation:conversation];
    }
}

#pragma mark - Settings View Controller Delegate

- (void)logoutTappedInSettingsTableViewController:(LSSettingsTableViewController *)settingsTableViewController
{
    [SVProgressHUD show];
    if (self.applicationController.layerClient.isConnected) {
        [self.applicationController.layerClient deauthenticateWithCompletion:^(BOOL success, NSError *error) {
            [self.applicationController.APIManager deauthenticate];
            [SVProgressHUD dismiss];
        }];
    } else {
        [self.applicationController.APIManager deauthenticate];
        [SVProgressHUD dismiss];
    }
}

@end
