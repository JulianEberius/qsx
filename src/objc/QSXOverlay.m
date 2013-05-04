#import "QSXOverlay.h"

NSString* const OVERLAY_MODE = @"overlay_mode";
NSString* const BORDERS_MODE = @"borders_mode";

@interface QSXOverlayView (private)
- (void)clear;
- (void)addRectangle:(NSRect)rect;
- (void)addSecondaryRectangle:(NSRect)rect;
- (void)addActiveBorder:(NSRect)rect;
- (void)addBorder:(NSRect)rect;
- (void)addArrowFrom:(NSPoint)start to:(NSPoint)end;
- (void)addDebugArrowFrom:(NSPoint)start to:(NSPoint)end;
@end

@implementation QSXOverlay
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
                     mode:(NSString*)mode
{
    id win=[super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag];
    if ([mode isEqualToString:OVERLAY_MODE]) {
        [win setIgnoresMouseEvents:NO];
        [win setLevel:NSFloatingWindowLevel];
    } else if ([mode isEqualToString:BORDERS_MODE]) {
        [win setIgnoresMouseEvents:YES];
        // [win setLevel:NSNormalWindowLevel];
        [win setLevel:NSFloatingWindowLevel];
    }
    [win setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
    [win setOpaque:NO];
    [win setHasShadow: NO];
    [win setContentView:[[[QSXOverlayView alloc] initWithFrame:contentRect] autorelease]];
    // [win setAcceptsMouseMovedEvents:YES];
    return win;
}

- (void)addRectangle:(NSRect)rect
{
    [(QSXOverlayView*)[self contentView] addRectangle:rect];
}
- (void)addSecondaryRectangle:(NSRect)rect
{
    [(QSXOverlayView*)[self contentView] addSecondaryRectangle:rect];
}
- (void)addActiveBorder:(NSRect)rect
{
    [(QSXOverlayView*)[self contentView] addActiveBorder:rect];
}
- (void)addBorder:(NSRect)rect
{
    [(QSXOverlayView*)[self contentView] addBorder:rect];
}
- (void)addArrowFrom:(NSPoint)start to:(NSPoint)end
{
    [(QSXOverlayView*)[self contentView] addArrowFrom:start to:end];
}
- (void)addDebugArrowFrom:(NSPoint)start to:(NSPoint)end
{
    [(QSXOverlayView*)[self contentView] addArrowFrom:start to:end];
}

- (void)setDebugEnabled:(BOOL)debug
{
    [(QSXOverlayView*)[self contentView] setDebugEnabled:debug];
}

- (void)clear
{
    [(QSXOverlayView*)[self contentView] clear];
}

-(void)dealloc
{
    [super dealloc];
}
@end

@implementation QSXOverlayView

@synthesize rectangles;
@synthesize secondaryRectangles;
@synthesize activeBorders;
@synthesize borders;
@synthesize arrows;
@synthesize debugArrows;
@synthesize debugEnabled;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.rectangles = [NSMutableArray arrayWithCapacity:1];
        self.secondaryRectangles = [NSMutableArray arrayWithCapacity:1];
        self.activeBorders = [NSMutableArray arrayWithCapacity:10];
        self.borders = [NSMutableArray arrayWithCapacity:10];
        self.arrows = [NSMutableArray arrayWithCapacity:10];
        self.debugArrows = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // draw box
    // [[NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:0.15] set];
    // [NSBezierPath setDefaultLineWidth:5];
    // [self fillRectangles:self.rectangles];

    // [[NSColor colorWithCalibratedRed:0.2 green:0 blue:0 alpha:0.15] set];
    // [NSBezierPath setDefaultLineWidth:0];
    // [self fillRectangles:self.secondaryRectangles];

    [[NSColor colorWithCalibratedRed:0.7 green:0.7 blue:0.7 alpha:1.0] set];
    [NSBezierPath setDefaultLineWidth:2];
    [self strokeRectangles:self.activeBorders];

    [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.4] set];
    [NSBezierPath setDefaultLineWidth:2];
    [self fillRectangles:self.borders];

    [self drawArrows:self.arrows];

    if (self.debugEnabled)
    {
        [self drawArrows:self.debugArrows];
    }
}

- (void)fillRectangles:(NSArray *)drawRectangles {
    for (NSValue* val in drawRectangles) {
        NSRect rect = [val rectValue];
        [NSBezierPath fillRect:rect];
    }
}

- (void)strokeRectangles:(NSArray *)drawRectangles {
    for (NSValue* val in drawRectangles) {
        NSRect rect = [val rectValue];
        // [NSBezierPath fillRect:rect];
        [NSBezierPath strokeRect:rect];
    }
}

- (void)drawArrows:(NSArray *)drawArrows {
    [NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
    [[NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:0.6] set];
    [NSBezierPath setDefaultLineWidth:3];
    int idx;
    for (idx=0; idx<[drawArrows count]; idx=idx+2) {
        NSPoint start = [[drawArrows objectAtIndex:idx] pointValue];
        NSPoint end = [[drawArrows objectAtIndex:idx+1] pointValue];
        [NSBezierPath strokeLineFromPoint:start toPoint:end];
    }
}

- (void)mouseDown:(NSEvent *)event
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXMouseLeftDown" object:event];
}

- (void)mouseUp:(NSEvent *)event
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXMouseLeftUp" object:event];
}

- (void)rightMouseDragged:(NSEvent *)event
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXMouseRightDrag" object:event];
}

- (void)mouseDragged:(NSEvent *)event
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXMouseLeftDrag" object:event];
}

// - (void)mouseMoved:(NSEvent *)event
// {
//     NSLog(@"MOUSE MOVED %d %d", event.absoluteX, event.absoluteY);
//     // [[NSNotificationCenter defaultCenter] postNotificationName:@"QSXMouseLeftDrag" object:event];
// }

- (void)addRectangle:(NSRect)rect
{
    [self.rectangles addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)addSecondaryRectangle:(NSRect)rect
{
    [self.secondaryRectangles addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)addActiveBorder:(NSRect)rect
{
    // rect.origin.x -= 1;
    // rect.size.height += 2;
    [self.activeBorders addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)addBorder:(NSRect)rect
{
    // rect.origin.x -= 1;
    // rect.origin.y -= 1;
    // rect.size.width += 2;
    // rect.size.height += 2;
    [self.borders addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)addArrowFrom:(NSPoint)start to:(NSPoint)end
{
    [self.arrows addObject:[NSValue valueWithPoint:start]];
    [self.arrows addObject:[NSValue valueWithPoint:end]];
    [self setNeedsDisplay:YES];
}

- (void)addDebugArrowFrom:(NSPoint)start to:(NSPoint)end
{
    [self.debugArrows addObject:[NSValue valueWithPoint:start]];
    [self.debugArrows addObject:[NSValue valueWithPoint:end]];
    [self setNeedsDisplay:YES];
}

- (void)clear
{
    [self.rectangles removeAllObjects];
    [self.secondaryRectangles removeAllObjects];
    [self.activeBorders removeAllObjects];
    [self.arrows removeAllObjects];
    [self.borders removeAllObjects];
    [self.debugArrows removeAllObjects];
    [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)dealloc
{
    // NSLog(@"view dealloc!!");
    self.rectangles = nil;
    self.secondaryRectangles = nil;
    self.activeBorders = nil;
    self.borders = nil;
    self.arrows = nil;
    self.debugArrows = nil;
    [super dealloc];
}
@end
