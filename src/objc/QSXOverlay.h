#import <Cocoa/Cocoa.h>

extern NSString* const OVERLAY_MODE;
extern NSString* const BORDERS_MODE;

//TODO: REFACTOR DRAWING CODE, DATA STRUCTURES EVERYTHING
@interface QSXOverlay : NSWindow
{
}
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag;
- (void)clear;
- (void)addActiveBorder:(NSRect)rect;
- (void)addBorder:(NSRect)rect;
- (void)setDebugEnabled:(BOOL)debug;
- (void)flashMessage:(NSString*)msg;
@end

@interface QSXOverlayView: NSView
{
    NSMutableArray* activeBorders;
    NSMutableArray* borders;
    NSString* msg;
    BOOL debugEnabled;
}
@property(retain) NSMutableArray* activeBorders;
@property(retain) NSMutableArray* borders;
@property(retain) NSString* msg;
@property(readwrite) BOOL debugEnabled;
@end
