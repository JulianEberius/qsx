//
//  WindowManager.m
//  QSX
//
//  Created by Julian Eberius on 01.05.11.
//  Copyright 2011 none. All rights reserved.
//

#import "QSXWindowManager.h"
#import "QSXWindow.h"

@interface QSXWindowManager (private)
- (void)windowCreated:(AXUIElementRef)element;
- (void)windowFocused:(AXUIElementRef)element;
- (void)windowDestroyed:(AXUIElementRef)element;
- (void)fillWindowListOfApp:(QSXApp*)app;
- (void)setObserverForApp:(QSXApp*)app;
- (void)setObserverForWindow:(QSXWindow*)window;
- (QSXApp*)appForWindowElem:(AXUIElementRef)window_elem;
- (QSXWindow*)windowForWindowElem:(AXUIElementRef)window_elem inApp:(QSXApp*)app;
- (QSXWindow*)initWindowObject:(AXUIElementRef)w;
- (QSXApp*)initAppObject:(NSDictionary*)appDict;
- (void)applicationLaunched:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
@end

static QSXWindowManager *sharedWindowManager = nil;

@implementation QSXWindowManager

@synthesize runningApps;
@synthesize queue;

static void appObserver(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *self)
{
    if (CFStringCompare(notification,kAXWindowCreatedNotification,0) == 0) {
        [(id)self performSelectorOnMainThread:@selector(windowCreated:) withObject:(id)element waitUntilDone:NO];
    } else if (CFStringCompare(notification,kAXApplicationActivatedNotification,0) == 0) {
        [(id)self performSelectorOnMainThread:@selector(appFocused:) withObject:(id)element waitUntilDone:NO];
    } else if (CFStringCompare(notification,kAXFocusedWindowChangedNotification,0) == 0) {
        [(id)self performSelectorOnMainThread:@selector(windowFocused:) withObject:(id)element waitUntilDone:NO];
    }
}

static void windowObserver(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *self)
{
    [(id)self performSelectorOnMainThread:@selector(windowDestroyed:) withObject:(id)element waitUntilDone:NO];
}

static CGSWorkspace getCurrentSpace() {
    // For some reason the simple CGSGetWorkspace does not seem to work anymore
    // so this function uses AXUIElementCopyAttributeValue, which returns
    // only windows on the current workspace, and then uses CGSGetWindowWorkspace
    // to get a valid workspace identifier
    CFArrayRef windows;
    AXUIElementRef w;
    CGWindowID cgWindowId;
    AXError err;
    CGSWorkspace workspace = -1;
    int i;

    NSWorkspace* ws = [NSWorkspace sharedWorkspace];
    NSArray* apps = [ws launchedApplications];
    int app_count = [apps count];

    for (i=0;i<app_count;i++) {
        NSDictionary* appDict = [apps objectAtIndex:i];
        pid_t pid = [[appDict objectForKey:@"NSApplicationProcessIdentifier"] intValue];
        AXUIElementRef appRef = AXUIElementCreateApplication(pid);
        AXUIElementCopyAttributeValue(
            appRef, kAXWindowsAttribute, (CFTypeRef *)&windows
        );
        if (windows != NULL)
        {
            if (CFArrayGetCount(windows) > 0)
            {
                w = (AXUIElementRef)CFArrayGetValueAtIndex(windows, 0);
                err = _AXUIElementGetWindow(w, &cgWindowId);
                if (err != 0) {
                    NSLog(@"------> Error getting CGWindowID! in CURRENTSPACE");
                }
                CGError err = CGSGetWindowWorkspace(_CGSDefaultConnection(), cgWindowId, &workspace);
                if (err != 0) {
                    NSLog(@"----> Error getting workspace for window! in CURRENTSPACE");
                }
                break;
            }
        }
    }
    return workspace;
}

static void spaceChange(int data1, int data2, int data3, void* userParameter)
{
    CGSWorkspace workspace = getCurrentSpace();
    NSLog(@"---> SPACE CHANGED to %i, posting notification", workspace);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXSpaceChanged" object:[NSNumber numberWithInt:workspace]];
}

- (id)init
{
    self = [super init];
    if (self) {
        self.queue = [NSOperationQueue new];
        CGError err = CGSRegisterConnectionNotifyProc(_CGSDefaultConnection(), spaceChange, CGSWorkspaceChangedEvent, NULL);
        if (err != 0) {
            NSLog(@"Error setting space change notification");
        }
    }

    return self;
}

- (NSRect)screenSize {
    NSRect screen_size = [[NSScreen mainScreen] frame];
    return screen_size;
}

- (CGSWorkspace)currentSpace {
    return getCurrentSpace();
}

#define kCGSDebugOptionNormal 0
#define kCGSDebugOptionNoShadows 16384
- (void)toggleShadows:(BOOL)value {
    CGSSetDebugOptions(value ? kCGSDebugOptionNormal : kCGSDebugOptionNoShadows);
}

- (NSArray*)apps {
    NSWorkspace* ws = [NSWorkspace sharedWorkspace];
    NSArray* apps = [ws launchedApplications];
    int app_count = [apps count];

    NSMutableArray* result = [NSMutableArray arrayWithCapacity:app_count];
    int i;
    for (i=0;i<app_count;i++) {
        NSDictionary* appDict = [apps objectAtIndex:i];
        QSXApp* app = [self initAppObject:appDict];
        [result addObject:app];
        [app release];
    }

    /* Register for application launch notifications */
    [[ws notificationCenter] addObserver:self
                               selector:@selector(applicationLaunched:)
                                   name:NSWorkspaceDidLaunchApplicationNotification
                                 object:ws];
    /* Register for application termination notifications */
    [[ws notificationCenter] addObserver:self
                               selector:@selector(applicationTerminated:)
                                   name:NSWorkspaceDidTerminateApplicationNotification
                                 object:ws];

    [self setRunningApps:result];
    return result;
}

- (QSXApp*)initAppObject:(NSDictionary*)appDict
{
    QSXApp* app;
    NSString* identifier = [appDict objectForKey:@"NSApplicationBundleIdentifier"];
    NSString* name = [appDict objectForKey:@"NSApplicationName"];
    pid_t pid = [[appDict objectForKey:@"NSApplicationProcessIdentifier"] intValue];
    AXUIElementRef appRef = AXUIElementCreateApplication(pid);

    // create the app object
    app = [[NSClassFromString(@"App") alloc] init];
    app._identifier = identifier;
    app._name = name;
    app._pid = pid;
    app.appRef = appRef;
    [self fillWindowListOfApp:app];
    [self setObserverForApp:app];
    CFRelease(appRef);
    return app;
}

- (void)applicationLaunched:(NSNotification *)notification
{
    NSDictionary* info = [notification userInfo];
    QSXApp* app = [self initAppObject:info];
    [self.runningApps addObject:app];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXNewApp" object:app];
    [app release];
}

- (void)applicationTerminated:(NSNotification *)notification
{
    NSDictionary* info = [notification userInfo];
    NSString* identifier = [info objectForKey:@"NSApplicationBundleIdentifier"];
    QSXApp* theApp = nil;
    for (QSXApp* app in self.runningApps)
    {
        if ([app._identifier isEqualToString:identifier]) {
            theApp = app;
            break;
        }
    }

    if (theApp != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXAppDestroyed" object:theApp];
        [self.runningApps removeObject:theApp];
    }
}

- (void)setObserverForApp:(QSXApp*)app {
    pid_t pid = app._pid;
    AXUIElementRef appRef = app.appRef;
    AXObserverRef observer;
    AXObserverCreate(pid, appObserver, &observer);
    /* Register for the application activated notification */
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       AXObserverGetRunLoopSource(observer),
                       kCFRunLoopDefaultMode);
    AXObserverAddNotification(observer, appRef, kAXWindowCreatedNotification, self);
    AXObserverAddNotification(observer, appRef, kAXFocusedWindowChangedNotification, self);
    AXObserverAddNotification(observer, appRef, kAXApplicationActivatedNotification, self);
    app.windowCreatedObserver = observer;
    CFRelease(observer);
}

- (void)setObserverForWindow:(QSXWindow*)window {
    pid_t pid = window._app._pid;
    AXUIElementRef appRef = window._app.appRef;
    AXObserverRef observer;
    AXObserverCreate(pid, windowObserver, &observer);
    /* Register for the application activated notification */
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       AXObserverGetRunLoopSource(observer),
                       kCFRunLoopDefaultMode);
    AXObserverAddNotification(observer, appRef, kAXUIElementDestroyedNotification, self);
    window.destroyedObserver = observer;
    CFRelease(observer);
}

- (void)windowCreated:(AXUIElementRef)element {
    CFStringRef subrole;
    AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, (CFTypeRef *)&subrole);
    if (![(NSString*)subrole isEqualToString:@"AXStandardWindow"]) {
        //only treat standard windows
        return;
    }
    QSXApp* app = [self appForWindowElem:element];
    QSXWindow* window = [self initWindowObject:element];
    window._app = app;
    window._subrole = (NSString*)subrole;
    [self setObserverForWindow:window];
    [app._windows addObject:window];
    [window release];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXNewWindow" object:window];
}

- (void)appFocused:(AXUIElementRef)element {
    AXUIElementRef w;
    AXUIElementCopyAttributeValue(element, (CFStringRef)NSAccessibilityFocusedWindowAttribute, (CFTypeRef *)&w);
    QSXApp* app = [self appForWindowElem:element];
    QSXWindow* window = [self windowForWindowElem:w inApp:app];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXWindowFocusedExternal" object:window];
}

- (void)windowFocused:(AXUIElementRef)element {
    QSXApp* app = [self appForWindowElem:element];
    QSXWindow* window = [self windowForWindowElem:element inApp:app];
    if (window == nil) {
        //only treat standard windows
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXWindowFocusedExternal" object:window];
}


- (void)windowDestroyed:(AXUIElementRef)element {
    QSXApp* app = [self appForWindowElem:element];
    QSXWindow* window = [self windowForWindowElem:element inApp:app];
    // NSLog(@"stuff");
    if (window == nil) {
        //only treat standard windows
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXWindowDestroyed" object:window];
    AXObserverRemoveNotification(window.destroyedObserver, window.windowRef, kAXUIElementDestroyedNotification);
    [app._windows removeObject:window];
}

- (QSXApp*)appForWindowElem:(AXUIElementRef)window_elem
{
    pid_t pid;
    AXUIElementGetPid(window_elem, &pid);
    for (QSXApp* app in runningApps) {
        if (app._pid == pid) {
            return app;
        }
    }
    return nil;
}

- (QSXWindow*)windowForWindowElem:(AXUIElementRef)window_elem inApp:(QSXApp*)app
{
    for (QSXWindow* win in app._windows) {
        if (CFEqual(win.windowRef, window_elem)) {
            return win;
        }
    }
    return nil;
}

- (void)fillWindowListOfApp:(QSXApp*)app{
    CFArrayRef windows;
    AXUIElementRef appRef = app.appRef;
    AXUIElementCopyAttributeValue(
                                  appRef, kAXWindowsAttribute, (CFTypeRef *)&windows
                                  );
    if (windows != NULL)
    {
        // NSLog(@"filling window list for app %@ count %i", app._name, CFArrayGetCount(windows));
        if (CFArrayGetCount(windows) > 0)
        {
            AXUIElementRef w;
            int i;
            for (i=0; i<CFArrayGetCount(windows);i++)
            {
                w = (AXUIElementRef)CFArrayGetValueAtIndex(windows,i);
                QSXWindow* windowObject = [self initWindowObject:w];
                windowObject._app = app;
                [self setObserverForWindow:windowObject];
                [app._windows addObject:windowObject];
                [windowObject release];
            }
        }
        CFRelease(windows);
    }
}

- (QSXWindow*)initWindowObject:(AXUIElementRef)w
{
    AXValueRef temp;
    CGSize windowSize;
    CGPoint windowPosition;

    CFStringRef windowTitle;
    /* Get the title of the window */
    AXUIElementCopyAttributeValue(
        w, kAXTitleAttribute, (CFTypeRef *)&windowTitle);
    if (windowTitle==NULL)
        windowTitle = CFSTR("");
    CFStringRef subrole;
    AXUIElementCopyAttributeValue(
        w, kAXSubroleAttribute, (CFTypeRef *)&subrole);
    if (subrole==NULL)
        subrole = CFSTR("None");
    /* Get the window size and position */
    AXUIElementCopyAttributeValue(
        w, kAXSizeAttribute, (CFTypeRef *)&temp);
    AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);
    CFRelease(temp);
    AXUIElementCopyAttributeValue(
        w, kAXPositionAttribute, (CFTypeRef *)&temp);
    AXValueGetValue(temp, kAXValueCGPointType, &windowPosition);
    CFRelease(temp);

    CGWindowID cgWindowId;
    AXError err = _AXUIElementGetWindow(w, &cgWindowId);
    if (err != 0) {
        NSLog(@"------> Error getting CGWindowID!");
    }

    QSXWindow* windowObject = [[NSClassFromString(@"Window") alloc] init];
    windowObject._title = (NSString *)windowTitle;
    windowObject._subrole = (NSString *)subrole;
    windowObject._size = NSSizeFromCGSize(windowSize);
    windowObject._position = NSPointFromCGPoint(windowPosition);
    windowObject.cgWindowID = cgWindowId;
    windowObject.windowRef = w;
    return windowObject;
}

#pragma mark Singleton Methods
+ (id)sharedManager {
    @synchronized(self) {
        if(sharedWindowManager == nil)
            sharedWindowManager = [[super allocWithZone:NULL] init];
    }
    return sharedWindowManager;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedManager] retain];
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return UINT_MAX; //denotes an object that cannot be released
}
- (oneway void)release {
    // never release
}
- (id)autorelease {
    return self;
}
- (void)dealloc
{
    [super dealloc];
}

@end
