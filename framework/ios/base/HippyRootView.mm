/*!
 * iOS SDK
 *
 * Tencent is pleased to support the open source community by making
 * Hippy available.
 *
 * Copyright (C) 2019 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "HippyRootView.h"
#import <objc/runtime.h>

#import "HippyAssert.h"
#import "HippyEventDispatcher.h"
#import "HippyKeyCommands.h"
#import "NativeRenderLog.h"
#import "NativeRenderImpl.h"
#import "NativeRenderUtils.h"
#import "NativeRenderView.h"
#import "UIView+NativeRender.h"
#import "HippyBundleURLProvider.h"
#include "scope.h"
#include "footstone/hippy_value.h"
#include "NativeRenderDomNodeUtils.h"

NSString *const HippyContentDidAppearNotification = @"HippyContentDidAppearNotification";

NSNumber *AllocRootViewTag() {
    static NSString * const token = @"allocateRootTag";
    @synchronized (token) {
        static NSUInteger rootTag = 0;
        return @(rootTag += 10);
    }
}

@interface HippyRootContentView : NativeRenderView <NativeRenderInvalidating> {
    NSUInteger _cost;
}

@property (nonatomic, readonly) BOOL contentHasAppeared;

- (instancetype)initWithFrame:(CGRect)frame
                 componentTag:(NSNumber *)componentTag NS_DESIGNATED_INITIALIZER;

- (void)removeAllSubviews;

@end

@interface HippyRootView () {
    HippyRootContentView *_contentView;
}

@property (readwrite, nonatomic, assign) CGSize intrinsicSize;

@end

@implementation HippyRootView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_contentDidAppear:) name:HippyContentDidAppearNotification
                                                   object:nil];
        _contentView = [[HippyRootContentView alloc] initWithFrame:self.bounds componentTag:self.componentTag];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_contentView];
    }
    return self;
}

- (UIViewController *)nativeRenderViewController {
    return _hippyViewController ?: [super nativeRenderViewController];
}

- (void)setLoadingView:(UIView *)loadingView {
    _loadingView = loadingView;
    if (!_contentView.contentHasAppeared) {
        [self showLoadingView];
    }
}

- (void)showLoadingView {
    if (_loadingView && !_contentView.contentHasAppeared) {
        _loadingView.hidden = NO;
        [self addSubview:_loadingView];
    }
}

- (void)_contentDidAppear:(NSNotification *)n {
    if (_loadingView.superview == self && _contentView.contentHasAppeared) {
        if (_loadingViewFadeDuration > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_loadingViewFadeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView transitionWithView:self duration:self->_loadingViewFadeDuration options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self->_loadingView.hidden = YES;
                    }
                    completion:^(__unused BOOL finished) {
                        [self->_loadingView removeFromSuperview];
                    }];
            });
        } else {
            _loadingView.hidden = YES;
            [_loadingView removeFromSuperview];
        }
    }
    [self contentDidAppear:[n.userInfo[@"cost"] longLongValue]];
}

- (NSNumber *)componentTag {
    HippyAssertMainQueue();
    if (!super.componentTag) {
        self.componentTag = AllocRootViewTag();
    }
    return super.componentTag;
}

- (void)contentDidAppear:(__unused NSUInteger)cost {
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _contentView.frame = self.bounds;
    _loadingView.center = (CGPoint) { CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) };
}

- (void)contentViewInvalidated {
    [_contentView removeAllSubviews];
    [self showLoadingView];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_contentView invalidate];
    NativeRenderLogInfo(@"[Hippy_OC_Log][Life_Circle],HippyRootView dealloc %p", self);
}

@end

@implementation HippyRootContentView

- (instancetype)initWithFrame:(CGRect)frame
                 componentTag:(NSNumber *)componentTag {
    self = [super initWithFrame:frame];
    if (self) {
        self.componentTag = componentTag;
        _cost = 0;
    }
    return self;
}

HIPPY_NOT_IMPLEMENTED(-(instancetype)initWithFrame : (CGRect)frame)
HIPPY_NOT_IMPLEMENTED(-(instancetype)initWithCoder : (nonnull NSCoder *)aDecoder)

- (void)insertNativeRenderSubview:(UIView *)subview atIndex:(NSInteger)atIndex {
    [super insertNativeRenderSubview:subview atIndex:atIndex];
    _cost = CACurrentMediaTime() * 1000.f;
    NSUInteger cost = _cost;
    if (!_contentHasAppeared) {
        _contentHasAppeared = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:HippyContentDidAppearNotification object:nil userInfo:@{
            @"cost": @(cost)
        }];
    }
}

- (void)setFrame:(CGRect)frame {
    super.frame = frame;
    if (self.componentTag) {
    }
}

- (void)removeAllSubviews {
    [self resetNativeRenderSubviews];
}

- (void)invalidate {
    [self removeAllSubviews];
}

@end