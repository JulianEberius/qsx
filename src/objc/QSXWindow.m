//
//  Window.m
//  QSX
//
//  Created by Julian Eberius on 01.05.11.
//  Copyright 2011 none. All rights reserved.
//

#import "QSXWindow.h"
#import "QSXWindowManager.h"


@implementation QSXApp

@synthesize _identifier;
@synthesize _name;
@synthesize _windows;
@synthesize _pid;
@synthesize appRef;
@synthesize windowCreatedObserver;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        self._windows = [NSMutableArray arrayWithCapacity:3];
    }

    return self;
}

- (void)dealloc
{
    self._windows = nil;
    self._name = nil;
    self._identifier = nil;
    self.appRef = nil;
    self.windowCreatedObserver = nil;
    [super dealloc];
}

- (void)setAccessibilityFlag:(NSString*)flag toValue:(BOOL)value {
    AXUIElementSetAttributeValue(appRef, (CFStringRef)flag, [NSNumber numberWithBool:value]);
}
@end




@implementation AsyncCheckResizeOperation

@synthesize window;
@synthesize targetSize;

-(id)initWithQSXWindow:(QSXWindow *)theWindow andTargetSize:(CGSize)theTargetSize {
    self = [super init];
    if (self) {
        self.window = theWindow;
        self.targetSize = theTargetSize;
    }

    return self;
}

-(void)main {
    CGSize windowSize;
    AXValueRef temp;
    AXUIElementRef windowRef = self.window.windowRef;

    // The actual values for the window size don't "appear" instantly
    [NSThread sleepForTimeInterval:0.2];
    if ([self isCancelled])
        return;

    AXUIElementCopyAttributeValue(
                                  windowRef, kAXSizeAttribute, (CFTypeRef *)&temp
                                  );
    AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);
    CFRelease(temp);
    if ([self isCancelled])
        return;

    // NSLog(@"AppName: %@ current Size: %@ and target Size %@", self.window._app._name,
    //     NSStringFromSize(windowSize), NSStringFromSize([self targetSize]));
    int wDiff = (int)([self targetSize].width - windowSize.width);
    int hDiff = (int)([self targetSize].height - windowSize.height);
    int x, y;
    while (wDiff > 0 || hDiff > 0) {
        x = wDiff > 0 ? 1 : 0;
        y = hDiff > 0 ? 1 : 0;
        [[self window] resizeByWidth:x height:y];
        wDiff--; hDiff--;

        if ([self isCancelled])
            return;
    }
}
@end


@implementation QSXWindow

@synthesize _title;
@synthesize _subrole;
@synthesize _position;
@synthesize _size;
@synthesize _app;
@synthesize cgWindowID;
@synthesize windowRef;
@synthesize destroyedObserver;
@synthesize focusedObserver;
@synthesize currentResizeCheckOperation;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (void)dealloc
{
    // NSLog(@"window deallocated: %@", _title);
    self._title = nil;
    self._subrole = nil;
    self._app = nil;
    self.windowRef = nil;
    self.destroyedObserver = nil;
    [super dealloc];
}

- (void)moveByX:(NSInteger)x Y:(NSInteger) y {
    AXValueRef temp;
    CGPoint windowPosition;

    AXUIElementCopyAttributeValue(
                                  windowRef, kAXPositionAttribute, (CFTypeRef *)&temp
                                  );
    AXValueGetValue(temp, kAXValueCGPointType, &windowPosition);
    CFRelease(temp);

    windowPosition.y += y;
    windowPosition.x += x;
    temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
    AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, temp);
    self._position = *(NSPoint*)&windowPosition;
    CFRelease(temp);
}
- (void)moveToX:(NSInteger)x Y:(NSInteger) y {
    AXValueRef temp;
    CGPoint windowPosition;

    windowPosition = CGPointMake(x,y);
    temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
    AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, temp);
    self._position = *(NSPoint*)&windowPosition;
    CFRelease(temp);
}
- (void)resizeByWidth:(NSInteger)width height:(NSInteger) height {
    AXValueRef temp;
    CGSize windowSize;

    AXUIElementCopyAttributeValue(
                                  windowRef, kAXSizeAttribute, (CFTypeRef *)&temp
                                  );
    AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);
    CFRelease(temp);

    windowSize.width += width;
    windowSize.height += height;
    temp = AXValueCreate(kAXValueCGSizeType, &windowSize);
    AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, temp);
    self._size = *(NSSize*)&windowSize;
    CFRelease(temp);

}
- (void)resizeToWidth:(NSInteger)width height:(NSInteger) height {
    AXValueRef temp;
    CGSize windowSize;

    windowSize = CGSizeMake(width,height);
    temp = AXValueCreate(kAXValueCGSizeType, &windowSize);
    AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, temp);
    self._size = *(NSSize*)&windowSize;
    CFRelease(temp);

    // TODO: there are race conditions here I think... add locks? simplify somehow?
    // some windows don't resize correctly (e.g. MacVim, Terminal)
    // Asynchronously check, and resize step by step in this case

    // NSOperation* op = [[AsyncCheckResizeOperation alloc] initWithQSXWindow:self andTargetSize:windowSize];
    // if ([self currentResizeCheckOperation] != NULL ) {
    //     [[self currentResizeCheckOperation] cancel];
    // }
    // [self setCurrentResizeCheckOperation:op];

    // [[[QSXWindowManager sharedManager] queue] addOperation:op];
}

- (BOOL)focusWindow {
  BOOL couldFocus = YES;
  if (AXUIElementSetAttributeValue(self.windowRef, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue) != kAXErrorSuccess) {
    NSLog(@"ERROR: Could not change focus to window");
    couldFocus = NO;
  }
  pid_t focusPID = self._app._pid;
  ProcessSerialNumber psn;
  GetProcessForPID(focusPID, &psn);
  SetFrontProcessWithOptions(&psn, kSetFrontProcessFrontWindowOnly);
  return couldFocus;
}

- (void)setAccessibilityFlag:(NSString*)flag toValue:(BOOL)value {
    AXUIElementSetAttributeValue(windowRef, (CFStringRef)flag, [NSNumber numberWithBool:value]);
}

- (bool)accessibilityFlag:(NSString*)flag {
    NSNumber *val;
    AXUIElementCopyAttributeValue(windowRef, (CFStringRef)flag, (CFTypeRef*)&val);
    return [val boolValue];
}

- (CGSWorkspace)windowSpace {
    CGSWorkspace workspace;
    CGError err = CGSGetWindowWorkspace(_CGSDefaultConnection(), self.cgWindowID, &workspace);
    if (err != 0) {
        NSLog(@"----> Error getting workspace for window!");
    }
    return workspace;
}

@end

