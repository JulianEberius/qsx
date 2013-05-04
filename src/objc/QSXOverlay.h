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
                    defer:(BOOL)flag
                     mode:(NSString*)mode;
- (void)clear;
- (void)addRectangle:(NSRect)rect;
- (void)addSecondaryRectangle:(NSRect)rect;
- (void)addActiveBorder:(NSRect)rect;
- (void)addBorder:(NSRect)rect;
- (void)addArrowFrom:(NSPoint)start to:(NSPoint)end;
- (void)addDebugArrowFrom:(NSPoint)start to:(NSPoint)end;
- (void)setDebugEnabled:(BOOL)debug;
@end

@interface QSXOverlayView: NSView
{
    NSMutableArray* rectangles;
    NSMutableArray* secondaryRectangles;
    NSMutableArray* activeBorders;
    NSMutableArray* borders;
    NSMutableArray* arrows;
    NSMutableArray* debugArrows;
    BOOL debugEnabled;
}
@property(retain) NSMutableArray* rectangles;
@property(retain) NSMutableArray* secondaryRectangles;
@property(retain) NSMutableArray* activeBorders;
@property(retain) NSMutableArray* borders;
@property(retain) NSMutableArray* arrows;
@property(retain) NSMutableArray* debugArrows;
@property(readwrite) BOOL debugEnabled;
@end
