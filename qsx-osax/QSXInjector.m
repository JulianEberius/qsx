#import <objc/objc-class.h>
#import <Cocoa/Cocoa.h>

/*
    This method is (partially) taken from Jonathan 'Wolf' Rentzsch's JRSwizzle,
    which is released under the MIT License. It can be found in the file MIT_LICENSE
*/


static bool swizzling_done = NO;
static NSMutableDictionary *dimmingWindows = NULL;

bool jr_swizzleMethod(Class clazz, SEL origSel_, SEL altSel_) {
    Method origMethod = class_getInstanceMethod(clazz, origSel_);
    if (!origMethod) {
        return NO;
    }
    Method altMethod = class_getInstanceMethod(clazz, altSel_);
    if (!altMethod) {
        return NO;
    }

    class_addMethod(clazz, origSel_,
                    class_getMethodImplementation(clazz, origSel_),
                    method_getTypeEncoding(origMethod));
    class_addMethod(clazz, altSel_,
                    class_getMethodImplementation(clazz, altSel_),
                    method_getTypeEncoding(altMethod));
    method_exchangeImplementations(
                                   class_getInstanceMethod(clazz, origSel_),
                                   class_getInstanceMethod(clazz, altSel_));
    return YES;
}

@interface QSXInteralOverlayWindow: NSWindow
@end

@implementation QSXInteralOverlayWindow: NSWindow
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
    id win=[super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    [win setIgnoresMouseEvents:YES];
    [win setLevel:NSFloatingWindowLevel];
    [win setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
    [win setOpaque:NO];
    [win setHasShadow: NO];
    return win;
}
@end

@interface NSApplication (QSX)
- (void)QSX_accessibilitySetValue:(id)value forAttribute:(NSString *)attribute;
- (BOOL)QSX_accessibilityIsAttributeSettable:(NSString *)attribute;
// TODO: special addition for Skim.app, should be moved to plugin later
- (void)QSX_noOp:(id)value;
@end

@implementation NSApplication (QSX)
- (BOOL)QSX_accessibilityIsAttributeSettable:(NSString *)attribute
{
    BOOL result;
    if ([attribute isEqualToString:@"QSXHideMenuAndDock"]) {
            result = true;
    } else {
        result = [self QSX_accessibilityIsAttributeSettable:attribute];
    }
    return result;
}

- (void)QSX_accessibilitySetValue:(id)value forAttribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"QSXHideMenuAndDock"]) {
        if ([value boolValue])
            [NSApp setPresentationOptions:(NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideMenuBar)];
        else
            [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    } else {
        [self QSX_accessibilitySetValue:value forAttribute:attribute];
    }
}
- (void)QSX_noOp:(id)value {
    return;
}
@end

@interface NSWindow (makeStatic)
- (void)QSX_zoom:(id)sender;
- (void)QSX_miniaturize:(id)sender;
- (BOOL)QSX_canBecomeKeyWindow;
- (BOOL)QSX_canBecomeMainWindow;
- (void)QSX_makeStatic:(bool)disable;
- (void)QSX_makeStaticBorderless:(bool)disable;
- (void)QSX_hideButtons:(bool)hide;
- (void)QSX_chrome_hideButtons:(bool)hide;
- (void)QSX_accessibilitySetValue:(id)value forAttribute:(NSString *)attribute;
- (BOOL)QSX_accessibilityIsAttributeSettable:(NSString *)attribute;
- (id)QSX_accessibilityAttributeValue:(NSString *)attribute;
- (void)QSX_setLionFullscreenEnabled:(bool)enabled;
- (bool)QSX_isLionFullscreenEnabled;
@end

@implementation NSWindow (makeStatic)
- (void)QSX_zoom:(id)sender {}
- (void)QSX_miniaturize:(id)sender {}
- (BOOL)QSX_canBecomeKeyWindow { return YES; }
- (BOOL)QSX_canBecomeMainWindow { return YES; }

-(void)QSX_makeStaticBorderless:(bool)disable
{
    // normal case
    if (disable) {
        [self setStyleMask:NSFullScreenWindowMask];
        NSRect frame = [self frame];
        frame.size.height += 22;
        [self setFrame:frame display:YES animate:NO];
    } else {
        [self setStyleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask];
        NSRect frame = [self frame];
        frame.size.height -= 22;
        [self setFrame:frame display:YES animate:NO];
    }
}

-(void)QSX_makeStatic:(bool)disable
{
    // CGFloat increment = disable ? MAXFLOAT : 1.0;
    // [self setResizeIncrements:NSMakeSize(increment, increment)];
    [self setShowsResizeIndicator:!disable];
    [self setMovable:!disable];
    [self QSX_hideButtons:disable];
}
-(void)QSX_hideButtons:(bool)hide
{
    [[self standardWindowButton:NSWindowZoomButton] setHidden:hide];
    [[self standardWindowButton:NSWindowCloseButton] setHidden:hide];
    [[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:hide];
}
-(void)QSX_setLionFullscreenEnabled:(bool)enabled {
    if (enabled) {
        [self setCollectionBehavior:[self collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    } else {
        [self setCollectionBehavior:[self collectionBehavior] & ~NSWindowCollectionBehaviorFullScreenPrimary];
    }
}
-(bool)QSX_isLionFullscreenEnabled {
    return (bool)([self collectionBehavior] & NSWindowCollectionBehaviorFullScreenPrimary);
}
- (void)QSX_chrome_hideButtons:(bool)hide
{
    NSButton* btn;
    object_getInstanceVariable(self, "closeButton_", (void *)&btn);
    [btn setHidden:hide];
    object_getInstanceVariable(self, "miniaturizeButton_", (void *)&btn);
    [btn setHidden:hide];
    object_getInstanceVariable(self, "zoomButton_", (void *)&btn);
    [btn setHidden:hide];
}

- (void)QSX_accessibilitySetValue:(id)value forAttribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"AXSize"]) {
        NSSize newSize = [value sizeValue];
        NSSize oldSize = [self frame].size;
        NSRect newFrame;
        newFrame.size = newSize;
        newFrame.origin = [self frame].origin;
        newFrame.origin.y += oldSize.height - newSize.height;
        [self setFrame:newFrame display:YES animate:NO];
    } else if ([attribute isEqualToString:@"QSXStatic"]) {
        [self QSX_makeStatic:[value boolValue]];
    } else if ([attribute isEqualToString:@"QSXStaticBorderless"]) {
        [self QSX_makeStaticBorderless:[value boolValue]];
    } else if ([attribute isEqualToString:@"QSXSetLionFullscreenEnabled"]) {
        [self QSX_setLionFullscreenEnabled:[value boolValue]];
    } else if ([attribute isEqualToString:@"QSXDimmedWindow"]) {
        NSNumber *windowNumber = [NSNumber numberWithLong:[self windowNumber]];
        NSLog(@"setting %@ to %@ kinda accessing it %@", windowNumber, value, dimmingWindows);
        NSWindow *dimmer = [dimmingWindows objectForKey:windowNumber];

        if ([value boolValue]) {
            if (dimmer == nil) {
                dimmer = [[QSXInteralOverlayWindow alloc]
                    initWithContentRect:[self frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
                [dimmingWindows setObject:dimmer forKey:windowNumber];
                [self addChildWindow:dimmer ordered:NSWindowAbove];
                NSLog(@"creating new one %@", dimmingWindows);
            }
        }
        else {
            if (dimmer != nil) {
               [self removeChildWindow:dimmer];
               [dimmer close];
               [dimmingWindows removeObjectForKey:windowNumber];
               NSLog(@"removed one %@", dimmingWindows);
            }
        }
    } else {
        [self QSX_accessibilitySetValue:value forAttribute:attribute];
    }
}

- (BOOL)QSX_accessibilityIsAttributeSettable:(NSString *)attribute
{
    BOOL result;
    if (([attribute isEqualToString:@"AXSize"])
        || ([attribute isEqualToString:@"QSXStatic"])
        || ([attribute isEqualToString:@"QSXStaticBorderless"])
        || ([attribute isEqualToString:@"QSXSetLionFullscreenEnabled"])
        || ([attribute isEqualToString:@"QSXDimmedWindow"])
        || ([attribute isEqualToString:@"QSXHighlighted"])) {
            result = true;
    } else {
        result = [self QSX_accessibilityIsAttributeSettable:attribute];
    }
    return result;
}
- (id)QSX_accessibilityAttributeValue:(NSString *)attribute {
    id result = NULL;
    if ([attribute isEqualToString:@"QSXIsLionFullscreenEnabled"]) {
        if ([self QSX_isLionFullscreenEnabled]) {
            result = [NSNumber numberWithBool:YES];
        } else {
            result = [NSNumber numberWithBool:NO];
        }
    } else {
        result = [self QSX_accessibilityAttributeValue:attribute];
    }
    return result;
}
@end

/*
    STATIC METHODS
*/

void swizzleZoomAndMiniaturize()
{
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(miniaturize:),
                     @selector(QSX_miniaturize:));
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(zoom:),
                     @selector(QSX_zoom:));
}

void swizzleCanBecomeMainAndKeyWindow()
{
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(canBecomeMainWindow),
                     @selector(QSX_canBecomeMainWindow));
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(canBecomeKeyWindow),
                     @selector(QSX_canBecomeKeyWindow));
}

void swizzleAccessibilityMethods()
{
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(accessibilitySetValue:forAttribute:),
                     @selector(QSX_accessibilitySetValue:forAttribute:)
                     );
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(accessibilityIsAttributeSettable:),
                     @selector(QSX_accessibilityIsAttributeSettable:)
                     );
    jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(accessibilityAttributeValue:),
                     @selector(QSX_accessibilityAttributeValue:)
                     );
    jr_swizzleMethod(
                     NSClassFromString(@"NSApplication"),
                     @selector(accessibilitySetValue:forAttribute:),
                     @selector(QSX_accessibilitySetValue:forAttribute:)
                     );
    jr_swizzleMethod(
                     NSClassFromString(@"NSApplication"),
                     @selector(accessibilityIsAttributeSettable:),
                     @selector(QSX_accessibilityIsAttributeSettable:)
                     );
}

OSErr InjectQSX(const AppleEvent *ev, AppleEvent *reply, long refcon) {

    if (swizzling_done)
        return noErr;

    swizzleAccessibilityMethods();
    swizzleZoomAndMiniaturize();
    swizzleCanBecomeMainAndKeyWindow();

    dimmingWindows = [[NSMutableDictionary alloc] init];

    NSLog(@"i created a cool dictionary %@", dimmingWindows);

    // treat special cases, should be moved later (using a plugin architecture)
    NSString* bundleName = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleName isEqualToString:@"com.google.Chrome"]) {
        jr_swizzleMethod(
                     NSClassFromString(@"NSWindow"),
                     @selector(QSX_hideButtons:),
                     @selector(QSX_chrome_hideButtons:)
                     );
    } else if ([bundleName isEqualToString:@"net.sourceforge.skim-app.skim"]) {
        jr_swizzleMethod(
                     NSClassFromString(@"SKApplication"),
                     @selector(updatePresentationOptionsForWindow:),
                     @selector(QSX_noOp:)
                     );
    }
    swizzling_done = YES;
    return noErr;
}
