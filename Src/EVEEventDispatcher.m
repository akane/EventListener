//
// This file is part of EventListener
//
// Created by JC on 4/6/14.
// For the full copyright and license information, please view the LICENSE
// file that was distributed with this source code
//

#import "EVEEventDispatcher.h"
#import "EVEEvent.h"
#import "EVEEventListener.h"
#import "EVEEventListenerSelector.h"
#import "EVEOrderedList.h"

#import <UIKit/UIKit.h>

// Private API
@interface EVEEventDispatcher ()
@property(nonatomic, weak)id<EVEEventDispatcher>   target;

@property(nonatomic, strong)NSMutableDictionary    *listeners_;
@end

@implementation EVEEventDispatcher

#pragma mark - Ctor/Dtor

+ (instancetype)new:(id<EVEEventDispatcher>)target {
   return [self eventDispatcher:target];
}

+ (instancetype)eventDispatcher:(id<EVEEventDispatcher>)target {
   return [[self.class alloc] init:target];
}

- (instancetype)init:(id<EVEEventDispatcher>)target {
   if (!(self = [super init]))
      return nil;

   self.target = target ?: self;

   return self;
}

#pragma mark - Public methods

- (void)addEventListener:(NSString *)type listener:(SEL)selector {
   [self addEventListener:type listener:selector useCapture:NO];
}

- (void)addEventListener:(NSString *)type listener:(SEL)selector useCapture:(BOOL)useCapture {
   [self addEventListener:type listener:selector useCapture:useCapture priority:0];
}

- (void)addEventListener:(NSString *)type listener:(SEL)selector useCapture:(BOOL)useCapture priority:(NSUInteger)priority {
   id<EVEEventListener> listener = [[EVEEventListenerSelector alloc] initWithSelector:selector];
   EVEOrderedList *listeners = [self _listenersContainer:type];

   listener.priority = priority;
   listener.useCapture = useCapture;

   // EVEOrderedList will take care of avoiding duplicates
   // and keep listeners ordered by priority
   [listeners add:listener];
}

- (void)removeEventListener:(NSString *)type listener:(SEL)selector {
   [self removeEventListener:type listener:selector useCapture:NO];
}

- (void)removeEventListener:(NSString *)type listener:(SEL)selector useCapture:(BOOL)useCapture {
   id<EVEEventListener> listener = [[EVEEventListenerSelector alloc] initWithSelector:selector];
   EVEOrderedList *listeners = [self _listenersContainer:type];

   listener.useCapture = useCapture;

   [listeners remove:listener];
}

- (id<EVEEventDispatcher>)nextDispatcher {
   return nil;
}

- (void)dispatchEvent:(EVEEvent *)event {
   NSArray *dispatchChain = [self _dispatchChain];

   // Capturing or bubbling event already being handled: just execute listeners
   if (event.eventPhase != EVEEventPhaseNone)
      return [self _handleEvent:event];

   [event setValue:self.target forKey:@"target"];

   // Capture Phase
   // Browse chain from top to bottom
   [event setValue:@(EVEEventPhaseCapturing) forKey:@"eventPhase"];
   for (id<EVEEventDispatcher> dispatcher in dispatchChain) {
      [dispatcher dispatchEvent:event];
   }

   [event setValue:@(EVEEventPhaseTarget) forKey:@"eventPhase"];
   [self _handleEvent:event];

   // Bubbling Phase
   // Browse chain from bottom to top
   [event setValue:@(EVEEventPhaseBubbling) forKey:@"eventPhase"];
   for (id<EVEEventDispatcher> dispatcher in [dispatchChain reverseObjectEnumerator]) {
      [dispatcher dispatchEvent:event];
   }

   [event setValue:@(EVEEventPhaseNone) forKey:@"eventPhase"];
   [event setValue:nil forKey:@"target"];
}

#pragma mark - Protected methods

- (void)_handleEvent:(EVEEvent *)event {
   EVEOrderedList *listeners = [self _listenersContainer:event.type];

   for (id<EVEEventListener> listener in listeners)
      [listener handleEvent:event];
}

- (NSArray *)_dispatchChain {
   NSMutableArray *chain = [NSMutableArray new];

   for (id<EVEEventDispatcher> dispatcher = [self.target nextDispatcher]; dispatcher != nil; dispatcher = [dispatcher nextDispatcher])
      [chain insertObject:dispatcher atIndex:0];

   return chain;
}

#pragma mark - Private methods

- (EVEOrderedList *)_listenersContainer:(NSString *)type {
   EVEOrderedList *container = self.listeners_[type];

   if (!container)
   {
      container = [EVEOrderedList orderedListWithComparator:^NSComparisonResult(id<EVEEventListener> obj1, id<EVEEventListener> obj2)
                   {
                      return obj1.priority <= obj2.priority ? NSOrderedAscending : NSOrderedDescending;
                   }
                                                  duplicate:NO];
      self.listeners_[type] = container;
   }

   return container;
}

@end
