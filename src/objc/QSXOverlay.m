#import "QSXOverlay.h"

@interface QSXOverlayView (private)
- (void)clear;
- (void)addActiveBorder:(NSRect)rect;
- (void)addBorder:(NSRect)rect;
@end

@implementation QSXOverlay
- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag
{
    id win=[super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag];
    [win setIgnoresMouseEvents:YES];
    [win setLevel:NSFloatingWindowLevel];
    [win setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
    [win setOpaque:NO];
    [win setHasShadow: NO];
    NSRect viewRect = NSMakeRect(0, 0, contentRect.size.width, contentRect.size.height);
    [win setContentView:[[[QSXOverlayView alloc] initWithFrame:viewRect] autorelease]];
    return win;
}


- (void)addActiveBorder:(NSRect)rect
{
    NSRect sframe = [[self screen] frame];
    rect.origin.x -= sframe.origin.x;
    // rect.origin.y -= sframe.origin.y;
    [(QSXOverlayView*)[self contentView] addActiveBorder:rect];
}
- (void)addBorder:(NSRect)rect
{
    NSRect sframe = [[self screen] frame];
    rect.origin.x -= sframe.origin.x;
    // rect.origin.y -= sframe.origin.y;
    [(QSXOverlayView*)[self contentView] addBorder:rect];
}
- (void)flashMessage:(NSString*)msg
{
    [(QSXOverlayView*)[self contentView] setMsg:msg];
    [(QSXOverlayView*)[self contentView] setNeedsDisplay:YES];

    // uses GCD and block-synatx to clear the flash message, wow!
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [(QSXOverlayView*)[self contentView] setMsg:NULL];
        [(QSXOverlayView*)[self contentView] setNeedsDisplay:YES];
    });
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

@synthesize activeBorders;
@synthesize borders;
@synthesize debugEnabled;
@synthesize msg;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.activeBorders = [NSMutableArray arrayWithCapacity:10];
        self.borders = [NSMutableArray arrayWithCapacity:10];
        self.debugEnabled = NO;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedRed:0.7 green:0.7 blue:0.7 alpha:1.0] set];
    [NSBezierPath setDefaultLineWidth:2];
    [self strokeRectangles:self.activeBorders];

    [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.5] set];
    [NSBezierPath setDefaultLineWidth:2];
    [self fillRectangles:self.borders];

    if (self.msg != NULL) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica" size:26], NSFontAttributeName,[NSColor redColor], NSForegroundColorAttributeName, nil];

        [self.msg drawAtPoint:NSMakePoint(20, 20) withAttributes:attributes];
    }
    if (self.debugEnabled)
    {
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
        [NSBezierPath strokeRect:rect];
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

- (void)addActiveBorder:(NSRect)rect
{
    [self.activeBorders addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)addBorder:(NSRect)rect
{
    [self.borders addObject:[NSValue valueWithRect:rect]];
    [self setNeedsDisplay:YES];
}

- (void)clear
{
    [self.activeBorders removeAllObjects];
    [self.borders removeAllObjects];
    [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)dealloc
{
    // NSLog(@"view dealloc!!");
    self.activeBorders = nil;
    self.borders = nil;
    [super dealloc];
}
@end
