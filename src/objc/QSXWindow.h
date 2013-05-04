//
//  Window.h
//  QSX
//
//  Created by Julian Eberius on 01.05.11.
//  Copyright 2011 none. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGSPrivate.h"

@interface QSXApp : NSObject {
 @private
    NSString* _identifier;
    NSString* _name;
    NSMutableArray* _windows;
    pid_t _pid;
    AXUIElementRef appRef;
    AXObserverRef windowCreatedObserver;
}
@property(nonatomic,copy) NSString* _identifier;
@property(nonatomic,copy) NSString* _name;
@property(nonatomic,retain) NSMutableArray* _windows;
@property(nonatomic,assign) pid_t _pid;
@property(nonatomic,retain) __attribute__((NSObject)) AXUIElementRef appRef;
@property(nonatomic,retain) __attribute__((NSObject)) AXObserverRef windowCreatedObserver;

- (void)setAccessibilityFlag:(NSString*)flag toValue:(BOOL)value;

@end


@interface QSXWindow : NSObject {
@private
    QSXApp* _app;
    NSString* _title;
    NSString* _subrole;
    NSSize _size;
    NSPoint _position;
    CGWindowID cgWindowID;
    AXUIElementRef windowRef;
    AXObserverRef destroyedObserver;
    AXObserverRef focusedObserver;
    NSOperation* currentResizeCheckOperation;
}
@property(nonatomic,assign) QSXApp* _app;
@property(nonatomic,copy) NSString* _title;
@property(nonatomic,copy) NSString* _subrole;
@property(nonatomic,assign) NSSize _size;
@property(nonatomic,assign) NSPoint _position;
@property(nonatomic,assign) CGWindowID cgWindowID;
@property(nonatomic,retain) __attribute__((NSObject)) AXUIElementRef windowRef;
@property(nonatomic,retain) __attribute__((NSObject)) AXObserverRef destroyedObserver;
@property(nonatomic,retain) __attribute__((NSObject)) AXObserverRef focusedObserver;
@property(assign) NSOperation* currentResizeCheckOperation;

- (void)moveByX:(NSInteger)x Y:(NSInteger) y;
- (void)moveToX:(NSInteger)x Y:(NSInteger) y;
- (void)resizeByWidth:(NSInteger)width height:(NSInteger)height;
- (void)resizeToWidth:(NSInteger)width height:(NSInteger)height;
- (BOOL)focusWindow;
- (bool)accessibilityFlag:(NSString*)flag;
- (void)setAccessibilityFlag:(NSString*)flag toValue:(BOOL)value;
- (CGSWorkspace)windowSpace;
@end


// some windows don't resize correctly (e.g. MacVim, Terminal)
// However, they do resize correctly when resized "one by one",
// i.e. in steps of one pixel.
// Asynchronously check, and resize step by step in this case.
@interface AsyncCheckResizeOperation : NSOperation {
    QSXWindow* window;
    CGSize targetSize;
}
@property(assign) QSXWindow* window;
@property CGSize targetSize;

-(id)initWithQSXWindow:(QSXWindow *)window andTargetSize:(CGSize)theTargetSize;
@end

