//
//  WindowManager.h
//  QSX
//
//  Created by Julian Eberius on 01.05.11.
//  Copyright 2011 none. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CGSPrivate.h"

AXError _AXUIElementGetWindow(AXUIElementRef ref, CGWindowID* out);

@interface QSXWindowManager : NSObject {

@private
NSOperationQueue* queue;
NSMutableArray* runningApps;
}
@property(retain) NSMutableArray* runningApps;
@property(retain) NSOperationQueue* queue;

+ (id)sharedManager;
- (NSRect)screenSize;
- (CGSWorkspace)currentSpace;
- (void)toggleShadows:(BOOL)value;
- (NSMutableArray*)apps;
@end