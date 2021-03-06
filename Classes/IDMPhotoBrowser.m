//
//  IDMPhotoBrowser.m
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "IDMPhotoBrowser.h"
#import "IDMZoomingScrollView.h"

#import "pop/POP.h"

#ifndef IDMPhotoBrowserLocalizedStrings
#define IDMPhotoBrowserLocalizedStrings(key) \
NSLocalizedStringFromTableInBundle((key), nil, [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"IDMPBLocalizations" ofType:@"bundle"]], nil)
#endif

// Private
@interface IDMPhotoBrowser () {
    // Data
    NSMutableArray *_photos;
    
    // Views
    UIScrollView *_pagingScrollView;
    
    // Gesture
    UIPanGestureRecognizer *_panGesture;
    
    // Paging
    NSMutableSet *_visiblePages, *_recycledPages;
    NSUInteger _pageIndexBeforeRotation;
    NSUInteger _currentPageIndex;
    
    //NavigationBar
    UINavigationBar *_navigationBar;
    UINavigationItem *_navigationItem;
    UIBarButtonItem *_doneButton;
    UIBarButtonItem *_actionButton;
    
    // Toolbar
    UIToolbar *_toolbar;
    UIBarButtonItem *_downloadButton;
    UIBarButtonItem *_imageListButton;
    UIBarButtonItem *_counterButton;
    UILabel *_counterLabel;
    
    //PhotoListView
    IDMPhotoSideListView* _photosListView;
    
    // Actions
    UIActionSheet *_actionsSheet;
    
    // Control
    NSTimer *_controlVisibilityTimer;
    
    // Appearance
    //UIStatusBarStyle _previousStatusBarStyle;
    BOOL _statusBarOriginallyHidden;
    
    // Present
    UIView *_senderViewForAnimation;
    
    // Misc
    BOOL _performingLayout;
    BOOL _rotating;
    BOOL _viewIsActive; // active as in it's in the view heirarchy
    BOOL _autoHide;
    NSInteger _initalPageIndex;
    
    BOOL _isdraggingPhoto;
    
    CGRect _senderViewOriginalFrame;
    //UIImage *_backgroundScreenshot;
    
    UIWindow *_applicationWindow;
    
    // iOS 7
    UIViewController *_applicationTopViewController;
    int _previousModalPresentationStyle;
}

// Private Properties
@property (nonatomic, strong) UIActionSheet *actionsSheet;
@property (nonatomic, strong) UIActivityViewController *activityViewController;

// Private Methods

// Layout
- (void)performLayout;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (IDMZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index;
- (IDMZoomingScrollView *)pageDisplayingPhoto:(id<IDMPhoto>)photo;
- (IDMZoomingScrollView *)dequeueRecycledPage;
- (void)configurePage:(IDMZoomingScrollView *)page forIndex:(NSUInteger)index;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;
- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionView:(IDMCaptionView *)captionView atIndex:(NSUInteger)index;

// Toolbar
- (void)updateToolbar;

// Navigation
- (void)jumpToPageAtIndex:(NSUInteger)index;
- (void)gotoPreviousPage;
- (void)gotoNextPage;

// Controls
- (void)cancelControlHiding;
//- (void)hideControlsAfterDelay;
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent;
- (void)toggleControls;
- (BOOL)areControlsHidden;

// Data
- (NSUInteger)numberOfPhotos;
- (id<IDMPhoto>)photoAtIndex:(NSUInteger)index;
- (UIImage *)imageForPhoto:(id<IDMPhoto>)photo;
- (void)loadAdjacentPhotosIfNecessary:(id<IDMPhoto>)photo;
- (void)releaseAllUnderlyingPhotos;

@end

// IDMPhotoBrowser
@implementation IDMPhotoBrowser

#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        // Defaults
        self.hidesBottomBarWhenPushed = YES;
        _currentPageIndex = 0;
        _performingLayout = NO; // Reset on view did appear
        _rotating = NO;
        _viewIsActive = NO;
        _visiblePages = [NSMutableSet new];
        _recycledPages = [NSMutableSet new];
        _photos = [NSMutableArray new];
        
        _initalPageIndex = 0;
        _autoHide = YES;
        
        _displayNavigationBar = YES;
        _displayActionButton = YES;
        _displayToolbar = YES;
        _displayCounterLabel = YES;
        _displayDownloadButton = YES;
        _displayImageListButton = YES;
        
        _forceHideStatusBar = NO;
        _usePopAnimation = NO;
        _disableVerticalSwipe = NO;
        
        _useWhiteBackgroundColor = NO;
        _leftArrowImage = _rightArrowImage = _leftArrowSelectedImage = _rightArrowSelectedImage = nil;
        
        _arrowButtonsChangePhotosAnimated = YES;
        
        _backgroundScaleFactor = 1.0;
        _animationDuration = 0.28;
        _senderViewForAnimation = nil;
        _scaleImage = nil;
        
        _isdraggingPhoto = NO;
        
        if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)])
            self.automaticallyAdjustsScrollViewInsets = NO;
        
        _applicationWindow = [[[UIApplication sharedApplication] delegate] window];
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
        {
            self.modalPresentationStyle = UIModalPresentationCustom;
            self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        }
        else
        {
            _applicationTopViewController = [self topviewController];
            _previousModalPresentationStyle = _applicationTopViewController.modalPresentationStyle;
            _applicationTopViewController.modalPresentationStyle = UIModalPresentationCurrentContext;
            self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        }
        
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        // Listen for IDMPhoto notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleIDMPhotoLoadingDidEndNotification:)
                                                     name:IDMPhoto_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray {
    if ((self = [self init])) {
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
    }
    return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray {
    if ((self = [self init])) {
        NSArray *photosArray = [IDMPhoto photosWithURLs:photoURLsArray];
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
    }
    return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
        NSArray *photosArray = [IDMPhoto photosWithURLs:photoURLsArray];
        _photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
    }
    return self;
}

- (void)dealloc {
    _pagingScrollView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllUnderlyingPhotos];
}

- (void)releaseAllUnderlyingPhotos {
    for (id p in _photos) { if (p != [NSNull null]) [p unloadUnderlyingImage]; } // Release photos
}

- (void)didReceiveMemoryWarning {
    // Release any cached data, images, etc that aren't in use.
    [self releaseAllUnderlyingPhotos];
    [_recycledPages removeAllObjects];
    
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - Pan Gesture

- (void)panGestureRecognized:(id)sender {
    // Initial Setup
    IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    
    static float firstX, firstY;
    
    float viewHeight = scrollView.frame.size.height;
    float viewHalfHeight = viewHeight/2;
    
    CGPoint translatedPoint = [(UIPanGestureRecognizer*)sender translationInView:self.view];
    
    // Gesture Began
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateBegan) {
        [self setControlsHidden:YES animated:YES permanent:YES];
        
        firstX = [scrollView center].x;
        firstY = [scrollView center].y;
        
        _senderViewForAnimation.hidden = (_currentPageIndex == _initalPageIndex);
        
        _isdraggingPhoto = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    translatedPoint = CGPointMake(firstX, firstY+translatedPoint.y);
    [scrollView setCenter:translatedPoint];
    
    float newY = scrollView.center.y - viewHalfHeight;
    float newAlpha = 1 - abs(newY)/viewHeight; //abs(newY)/viewHeight * 1.8;
    
    self.view.opaque = YES;
    
    self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:newAlpha];
    
    // Gesture Ended
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
        if(scrollView.center.y > viewHalfHeight+40 || scrollView.center.y < viewHalfHeight-40) // Automatic Dismiss View
        {
            if (_senderViewForAnimation && _currentPageIndex == _initalPageIndex) {
                [self performCloseAnimationWithScrollView:scrollView];
                return;
            }
            
            CGFloat finalX = firstX, finalY;
            
            CGFloat windowsHeigt = [_applicationWindow frame].size.height;
            
            if(scrollView.center.y > viewHalfHeight+30) // swipe down
                finalY = windowsHeigt*2;
            else // swipe up
                finalY = -viewHalfHeight;
            
            CGFloat animationDuration = 0.35;
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
            [UIView commitAnimations];
            
            [self performSelector:@selector(doneButtonPressed:) withObject:self afterDelay:animationDuration];
        }
        else // Continue Showing View
        {
            _isdraggingPhoto = NO;
            [self setNeedsStatusBarAppearanceUpdate];
            
            self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];
            
            CGFloat velocityY = (.35*[(UIPanGestureRecognizer*)sender velocityInView:self.view].y);
            
            CGFloat finalX = firstX;
            CGFloat finalY = viewHalfHeight;
            
            CGFloat animationDuration = (ABS(velocityY)*.0002)+.2;
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            [UIView commitAnimations];
        }
    }
}

#pragma mark - Animation

- (UIImage*)rotateImageToCurrentOrientation:(UIImage*)image
{
    if(UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
    {
        UIImageOrientation orientation = ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft) ?UIImageOrientationLeft : UIImageOrientationRight;
        
        UIImage *rotatedImage = [[UIImage alloc] initWithCGImage:image.CGImage
                                                           scale:1.0
                                                     orientation:orientation];
        
        image = rotatedImage;
    }
    
    return image;
}

- (void)performPresentAnimation {
    self.view.alpha = 0.0f;
    
    UIImage *imageFromView = _scaleImage ? _scaleImage : [self getImageFromView:_senderViewForAnimation];
    imageFromView = [self rotateImageToCurrentOrientation:imageFromView];
    
    _senderViewOriginalFrame = [_senderViewForAnimation.superview convertRect:_senderViewForAnimation.frame toView:nil];
    
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenBound.size.width;
    CGFloat screenHeight = screenBound.size.height;
    
    UIView *fadeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, screenHeight)];
    fadeView.backgroundColor = [UIColor clearColor];
    [_applicationWindow addSubview:fadeView];
    
    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = _senderViewOriginalFrame;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode = UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor) ? 1 : 0 alpha:1];
    [_applicationWindow addSubview:resizableImageView];
    _senderViewForAnimation.hidden = YES;
    
    void (^completion)() = ^() {
        self.view.alpha = 1.0f;
        resizableImageView.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor) ? 1 : 0 alpha:1];
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
    };
    
    [UIView animateWithDuration:_animationDuration animations:^{
        fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
    } completion:nil];
    
    float scaleFactor = (imageFromView ? imageFromView.size.width : screenWidth) / screenWidth;
    CGRect finalImageViewFrame = CGRectMake(0, (screenHeight/2)-((imageFromView.size.height / scaleFactor)/2), screenWidth, imageFromView.size.height / scaleFactor);
    
    if(_usePopAnimation)
    {
        [self animateView:resizableImageView
                  toFrame:finalImageViewFrame
               completion:completion];
    }
    else
    {
        [UIView animateWithDuration:_animationDuration animations:^{
            resizableImageView.layer.frame = finalImageViewFrame;
        } completion:^(BOOL finished) {
            completion();
        }];
    }
}

- (void)performCloseAnimationWithScrollView:(IDMZoomingScrollView*)scrollView {
    float fadeAlpha = 1 - abs(scrollView.frame.origin.y)/scrollView.frame.size.height;
    
    UIImage *imageFromView = [scrollView.photo underlyingImage];
    
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenBound.size.width;
    CGFloat screenHeight = screenBound.size.height;
    
    float scaleFactor = imageFromView.size.width / screenWidth;
    
    UIView *fadeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, screenHeight)];
    fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
    fadeView.alpha = fadeAlpha;
    [_applicationWindow addSubview:fadeView];
    
    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = (imageFromView) ? CGRectMake(0, (screenHeight/2)-((imageFromView.size.height / scaleFactor)/2)+scrollView.frame.origin.y, screenWidth, imageFromView.size.height / scaleFactor) : CGRectZero;
    resizableImageView.contentMode = UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor clearColor];
    resizableImageView.clipsToBounds = YES;
    [_applicationWindow addSubview:resizableImageView];
    self.view.hidden = YES;
    
    void (^completion)() = ^() {
        _senderViewForAnimation.hidden = NO;
        _senderViewForAnimation = nil;
        _scaleImage = nil;
        
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
        
        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:YES];
    };
    
    [UIView animateWithDuration:_animationDuration animations:^{
        fadeView.alpha = 0;
        self.view.backgroundColor = [UIColor clearColor];
    } completion:nil];
    
    if(_usePopAnimation)
    {
        [self animateView:resizableImageView
                  toFrame:_senderViewOriginalFrame
               completion:completion];
    }
    else
    {
        [UIView animateWithDuration:_animationDuration animations:^{
            resizableImageView.layer.frame = _senderViewOriginalFrame;
        } completion:^(BOOL finished) {
            completion();
        }];
    }
}

#pragma mark - Genaral

- (void)prepareForClosePhotoBrowser {
    // Gesture
    [_applicationWindow removeGestureRecognizer:_panGesture];
    
    _autoHide = NO;
    
    // Controls
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
}

- (void)dismissPhotoBrowserAnimated:(BOOL)animated {
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self dismissViewControllerAnimated:animated completion:^{
        if ([_delegate respondsToSelector:@selector(photoBrowser:didDismissAtPageIndex:)])
            [_delegate photoBrowser:self didDismissAtPageIndex:_currentPageIndex];
        
        if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0"))
        {
            _applicationTopViewController.modalPresentationStyle = _previousModalPresentationStyle;
        }
    }];
}

- (UIButton*)customToolbarButtonImage:(UIImage*)image imageSelected:(UIImage*)selectedImage action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:image forState:UIControlStateNormal];
    [button setBackgroundImage:selectedImage forState:UIControlStateDisabled];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setContentMode:UIViewContentModeCenter];
    [button setFrame:CGRectMake(0,0, image.size.width, image.size.height)];
    return button;
}

- (UIImage*)getImageFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 2);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIViewController *)topviewController
{
    UIViewController *topviewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topviewController.presentedViewController) {
        topviewController = topviewController.presentedViewController;
    }
    
    return topviewController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    // Transition animation
    [self performPresentAnimation];
    
    // View
    self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];
    
    self.view.clipsToBounds = YES;
    
    // Setup paging scrolling view
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    _pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
    _pagingScrollView.pagingEnabled = YES;
    _pagingScrollView.delegate = self;
    _pagingScrollView.showsHorizontalScrollIndicator = NO;
    _pagingScrollView.showsVerticalScrollIndicator = NO;
    _pagingScrollView.backgroundColor = [UIColor clearColor];
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    [self.view addSubview:_pagingScrollView];
    
    //NavigationBar
    _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 64)];
    _navigationBar.tintColor = [UIColor whiteColor];
    _navigationBar.clipsToBounds = YES;
    [_navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, 2000, 44);
    gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0 alpha:0.8] CGColor], (id)[[UIColor colorWithWhite:0 alpha:0.0] CGColor], nil];
    [_navigationBar.layer insertSublayer:gradient atIndex:0];
    _navigationItem = [[UINavigationItem alloc] init];
    _navigationBar.items = @[_navigationItem];
    _doneButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/btn_common_white_back"] style:0 target:self action:@selector(doneButtonPressed:)];
    _doneButton.imageInsets = UIEdgeInsetsMake(0, -11, 0, 0);
    _navigationItem.leftBarButtonItem = _doneButton;
    _actionButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/btn_photo_share"]
                                       landscapeImagePhone:nil
                                                     style:0
                                                    target:self
                                                    action:@selector(actionButtonPressed:)];
    
    // Toolbar
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) - 44, CGRectGetWidth(self.view.bounds), 44)];
    _toolbar.tintColor = [UIColor whiteColor];
    _toolbar.backgroundColor = [UIColor clearColor];
    _toolbar.clipsToBounds = YES;
    [_toolbar setBackgroundImage:[UIImage new]
              forToolbarPosition:UIToolbarPositionAny
                      barMetrics:UIBarMetricsDefault];
    _downloadButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/btn_photo_download"]
                                         landscapeImagePhone:nil
                                                       style:0
                                                      target:self
                                                      action:@selector(downloadButtonPressed:)];
    UIButton* btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 40)];
    [btn setImage:[UIImage imageNamed:@"IDMPhotoBrowser.bundle/images/btn_photo_show_album.png"] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(imageListButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    _imageListButton = [[UIBarButtonItem alloc] initWithCustomView:btn];
    
    // Counter Label
    _counterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 40)];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.backgroundColor = [UIColor clearColor];
    _counterLabel.font = [UIFont fontWithName:@"Helvetica" size:17];
    if(_useWhiteBackgroundColor == NO) {
        _counterLabel.textColor = [UIColor whiteColor];
        _counterLabel.shadowColor = [UIColor darkTextColor];
        _counterLabel.shadowOffset = CGSizeMake(0, 1);
    }
    else {
        _counterLabel.textColor = [UIColor blackColor];
    }
    // Counter Button
    _counterButton = [[UIBarButtonItem alloc] initWithCustomView:_counterLabel];
    
    // Gesture
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    [_panGesture setMinimumNumberOfTouches:1];
    [_panGesture setMaximumNumberOfTouches:1];
    
    // Super
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    // Update
    [self reloadData];
    
    // Super
    [super viewWillAppear:animated];
    
    // Status Bar
    _statusBarOriginallyHidden = [UIApplication sharedApplication].statusBarHidden;
    
    // Update UI
    //[self hideControlsAfterDelay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return _useWhiteBackgroundColor ? 1 : 0;
}

- (BOOL)prefersStatusBarHidden {
    if(_forceHideStatusBar) {
        return YES;
    }
    
    if(_isdraggingPhoto) {
        if(_statusBarOriginallyHidden) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        return [self areControlsHidden];
    }
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
    CGFloat navigationBarHeight = 64;
    CGFloat toolBarHeight = 44;
    if (CGRectGetWidth([UIScreen mainScreen].bounds) > CGRectGetHeight([UIScreen mainScreen].bounds)) {
        navigationBarHeight = 32;
        toolBarHeight = 32;
    }
    
    // Flag
    _performingLayout = YES;
    
    // NavigationBar
    _navigationBar.frame = CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), navigationBarHeight);
    
    // ToolBar
    _toolbar.frame = CGRectMake(0, self.view.bounds.size.height - 44, CGRectGetWidth([UIScreen mainScreen].bounds), toolBarHeight);
    
    // IDMPhotoSideListView
    [_photosListView setNeedsLayout];
    
    // Remember index
    NSUInteger indexPriorToLayout = _currentPageIndex;
    
    // Get paging scroll view frame to determine if anything needs changing
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
    // Frame needs changing
    _pagingScrollView.frame = pagingScrollViewFrame;
    
    // Recalculate contentSize based on current orientation
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    
    // Adjust frames and configuration of each visible page
    for (IDMZoomingScrollView *page in _visiblePages) {
        NSUInteger index = PAGE_INDEX(page);
        page.frame = [self frameForPageAtIndex:index];
        page.captionView.frame = [self frameForCaptionView:page.captionView atIndex:index];
        [page setMaxMinZoomScalesForCurrentBounds];
    }
    
    // Adjust contentOffset to preserve page location based on values collected prior to location
    _pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
    [self didStartViewingPageAtIndex:_currentPageIndex]; // initial
    
    // Reset
    _currentPageIndex = indexPriorToLayout;
    _performingLayout = NO;
    
    // Super
    [super viewWillLayoutSubviews];
}

- (void)performLayout {
    // Setup
    _performingLayout = YES;
    
    // Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    //NavigationBar
    if (_displayNavigationBar && !self.navigationController.navigationBar) {
        [self.view addSubview:_navigationBar];
    }
    if (_displayActionButton && !self.navigationController.navigationBar) {
        _navigationItem.rightBarButtonItem = _actionButton;
    }
    
    // Toolbar
    if (_displayToolbar) {
        [self.view addSubview:_toolbar];
    } else {
        [_toolbar removeFromSuperview];
    }
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:self action:nil];
    NSMutableArray *items = [NSMutableArray new];
    if (_displayCounterLabel) {
        [items addObject:_counterButton];
    }
    [items addObject:flexSpace];
    if (_displayDownloadButton) {
        [items addObject:_downloadButton];
    }
    [items addObject:flexSpace];
    if(_displayImageListButton) {
        [items addObject:_imageListButton];
        _photosListView = [[IDMPhotoSideListView alloc] initWithPhotos:_photos placeholderRate:16.0 / 9.0];
        _photosListView.frame = CGRectMake(self.view.bounds.size.width, 0, _photosListView.bounds.size.width, _photosListView.bounds.size.height);
        _photosListView.imageDelegate = self;
        [self.view addSubview:_photosListView];
    }
    
    [_toolbar setItems:items];
    [self updateToolbar];
    
    // Content offset
    _pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;
    
    if(! _disableVerticalSwipe)
        [self.view addGestureRecognizer:_panGesture];
}

#pragma mark - Data

- (void)reloadData {
    // Get data
    [self releaseAllUnderlyingPhotos];
    
    // Update
    [self performLayout];
    
    // Layout
    [self.view setNeedsLayout];
}

- (NSUInteger)numberOfPhotos {
    return _photos.count;
}

- (id<IDMPhoto>)photoAtIndex:(NSUInteger)index {
    return _photos[index];
}

- (IDMCaptionView *)captionViewForPhotoAtIndex:(NSUInteger)index {
    IDMCaptionView *captionView = nil;
    if ([_delegate respondsToSelector:@selector(photoBrowser:captionViewForPhotoAtIndex:)]) {
        captionView = [_delegate photoBrowser:self captionViewForPhotoAtIndex:index];
    } else {
        id <IDMPhoto> photo = [self photoAtIndex:index];
        if ([photo respondsToSelector:@selector(caption)]) {
            if ([photo caption]) captionView = [[IDMCaptionView alloc] initWithPhoto:photo];
        }
    }
    captionView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha
    
    return captionView;
}

- (UIImage *)imageForPhoto:(id<IDMPhoto>)photo {
    if (photo) {
        // Get image or obtain in background
        if ([photo underlyingImage]) {
            return [photo underlyingImage];
        } else {
            [photo loadUnderlyingImageAndNotify];
        }
    }
    
    return nil;
}

- (void)loadAdjacentPhotosIfNecessary:(id<IDMPhoto>)photo {
    IDMZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = PAGE_INDEX(page);
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                id <IDMPhoto> photo = [self photoAtIndex:pageIndex-1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    IDMLog(@"Pre-loading image at index %i", pageIndex-1);
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                id <IDMPhoto> photo = [self photoAtIndex:pageIndex+1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    IDMLog(@"Pre-loading image at index %i", pageIndex+1);
                }
            }
        }
    }
}

#pragma mark - IDMPhoto Loading Notification

- (void)handleIDMPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <IDMPhoto> photo = [notification object];
    IDMZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        if ([photo underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        } else {
            // Failed to load
            [page displayImageFailure];
        }
    }
}

#pragma mark - Paging

- (void)tilePages {
    // Calculate which pages should be visible
    // Ignore padding as paging bounces encroach on that
    // and lead to false page loads
    CGRect visibleBounds = _pagingScrollView.bounds;
    NSInteger iFirstIndex = (NSInteger) floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
    NSInteger iLastIndex  = (NSInteger) floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;
    
    // Recycle no longer needed pages
    NSInteger pageIndex;
    for (IDMZoomingScrollView *page in _visiblePages) {
        pageIndex = PAGE_INDEX(page);
        if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
            [_recycledPages addObject:page];
            [page prepareForReuse];
            [page removeFromSuperview];
            IDMLog(@"Removed page at index %i", PAGE_INDEX(page));
        }
    }
    [_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];
    
    // Add missing pages
    for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
        if (![self isDisplayingPageForIndex:index]) {
            // Add new page
            IDMZoomingScrollView *page;
            page = [[IDMZoomingScrollView alloc] initWithPhotoBrowser:self];
            page.backgroundColor = [UIColor clearColor];
            page.opaque = YES;
            
            [self configurePage:page forIndex:index];
            [_visiblePages addObject:page];
            [_pagingScrollView addSubview:page];
            IDMLog(@"Added page at index %i", index);
            
            // Add caption
            IDMCaptionView *captionView = [self captionViewForPhotoAtIndex:index];
            captionView.frame = [self frameForCaptionView:captionView atIndex:index];
            [_pagingScrollView addSubview:captionView];
            page.captionView = captionView;
        }
    }
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
    for (IDMZoomingScrollView *page in _visiblePages)
        if (PAGE_INDEX(page) == index) return YES;
    return NO;
}

- (IDMZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
    IDMZoomingScrollView *thePage = nil;
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (PAGE_INDEX(page) == index) {
            thePage = page; break;
        }
    }
    return thePage;
}

- (IDMZoomingScrollView *)pageDisplayingPhoto:(id<IDMPhoto>)photo {
    IDMZoomingScrollView *thePage = nil;
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (page.photo == photo) {
            thePage = page; break;
        }
    }
    return thePage;
}

- (void)configurePage:(IDMZoomingScrollView *)page forIndex:(NSUInteger)index {
    page.frame = [self frameForPageAtIndex:index];
    page.tag = PAGE_INDEX_TAG_OFFSET + index;
    page.photo = [self photoAtIndex:index];
    
    __block __weak IDMPhoto *photo = (IDMPhoto*)page.photo;
    __weak IDMZoomingScrollView* weakPage = page;
    photo.progressUpdateBlock = ^(CGFloat progress){
        [weakPage setProgress:progress forPhoto:photo];
    };
}

- (IDMZoomingScrollView *)dequeueRecycledPage {
    IDMZoomingScrollView *page = [_recycledPages anyObject];
    if (page) {
        [_recycledPages removeObject:page];
    }
    return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    id <IDMPhoto> currentPhoto = [self photoAtIndex:index];
    if ([currentPhoto underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentPhotosIfNecessary:currentPhoto];
    }
    if ([_delegate respondsToSelector:@selector(photoBrowser:didShowPhotoAtIndex:)]) {
        [_delegate photoBrowser:self didShowPhotoAtIndex:index];
    }
}

#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.view.bounds;
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
    CGFloat pageWidth = _pagingScrollView.bounds.size.width;
    CGFloat newOffset = index * pageWidth;
    return CGPointMake(newOffset, 0);
}

- (BOOL)isLandscape:(UIInterfaceOrientation)orientation
{
    return UIInterfaceOrientationIsLandscape(orientation);
}


- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation {
    CGRect screenBound = self.view.bounds;
    CGFloat screenWidth = screenBound.size.width;
    
    // if ([self isLandscape:orientation]) screenWidth = screenBound.size.height;
    
    return CGRectMake(screenWidth - 75, 30, 55, 26);
}

- (CGRect)frameForCaptionView:(IDMCaptionView *)captionView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    
    CGSize captionSize = [captionView sizeThatFits:CGSizeMake(pageFrame.size.width, 0)];
    CGRect captionFrame = CGRectMake(pageFrame.origin.x, pageFrame.size.height - captionSize.height - (_toolbar.superview?_toolbar.frame.size.height:0), pageFrame.size.width, captionSize.height);
    
    return captionFrame;
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView  {
    // Checks
    if (!_viewIsActive || _performingLayout || _rotating) return;
    
    // Tile pages
    [self tilePages];
    
    // Calculate current page
    CGRect visibleBounds = _pagingScrollView.bounds;
    NSInteger index = (NSInteger) (floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
    if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
    NSUInteger previousCurrentPage = _currentPageIndex;
    _currentPageIndex = index;
    if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
        
        if(_arrowButtonsChangePhotosAnimated) [self updateToolbar];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // Hide controls when dragging begins
    _photosListView.isShow = NO;
    //[self setControlsHidden:YES animated:YES permanent:NO];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    // Update toolbar when page changes
    if(! _arrowButtonsChangePhotosAnimated) [self updateToolbar];
}

#pragma mark - Toolbar

- (void)updateToolbar {
    // Counter
    if ([self numberOfPhotos] > 1) {
        _counterLabel.text = [NSString stringWithFormat:@"%zd %@ %zd", _currentPageIndex+1, IDMPhotoBrowserLocalizedStrings(@"of"), [self numberOfPhotos]];
    } else {
        _counterLabel.text = nil;
    }
}

- (void)jumpToPageAtIndex:(NSUInteger)index {
    // Change page
    if (index < [self numberOfPhotos]) {
        CGRect pageFrame = [self frameForPageAtIndex:index];
        
        if(_arrowButtonsChangePhotosAnimated)
        {
            [_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:YES];
        }
        else
        {
            _pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);
            [self updateToolbar];
        }
    }
    
    // Update timer to give more time
    //[self hideControlsAfterDelay];
}

- (void)gotoPreviousPage { [self jumpToPageAtIndex:_currentPageIndex-1]; }
- (void)gotoNextPage     { [self jumpToPageAtIndex:_currentPageIndex+1]; }

#pragma mark - Control Hiding / Showing

// If permanent then we don't set timers to hide again
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent {
    // Cancel any timers
    [self cancelControlHiding];
    
    if (hidden) {
        if (_photosListView.isShow) {
            _photosListView.isShow = NO;
            return;
        }
    }
    
    // Captions
    NSMutableSet *captionViews = [[NSMutableSet alloc] initWithCapacity:_visiblePages.count];
    for (IDMZoomingScrollView *page in _visiblePages) {
        if (page.captionView) [captionViews addObject:page.captionView];
    }
    
    // Hide/show bars
    [UIView animateWithDuration:(animated ? 0.1 : 0) animations:^(void) {
        CGFloat alpha = hidden ? 0 : 1;
        [self.navigationController.navigationBar setAlpha:alpha];
        [_toolbar setAlpha:alpha];
        [_navigationBar setAlpha:alpha];
        for (UIView *v in captionViews) v.alpha = alpha;
    } completion:^(BOOL finished) {}];
    
    // Control hiding timer
    // Will cancel existing timer but only begin hiding if they are visible
    //if (!permanent) [self hideControlsAfterDelay];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)cancelControlHiding {
    // If a timer exists then cancel and release
    if (_controlVisibilityTimer) {
        [_controlVisibilityTimer invalidate];
        _controlVisibilityTimer = nil;
    }
}

// Enable/disable control visiblity timer
//- (void)hideControlsAfterDelay {
//    // return;
//    
//    if (![self areControlsHidden]) {
//        [self cancelControlHiding];
//        _controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
//    }
//}

- (BOOL)areControlsHidden { return (_toolbar.alpha == 0); }
- (void)hideControls      { if(_autoHide) [self setControlsHidden:YES animated:YES permanent:NO]; }
- (void)toggleControls    { [self setControlsHidden:![self areControlsHidden] animated:YES permanent:NO]; }


#pragma mark - Properties

- (void)setInitialPageIndex:(NSUInteger)index {
    // Validate
    if (index >= [self numberOfPhotos]) index = [self numberOfPhotos]-1;
    _initalPageIndex = index;
    _currentPageIndex = index;
    if ([self isViewLoaded]) {
        [self jumpToPageAtIndex:index];
        if (!_viewIsActive) [self tilePages]; // Force tiling if view is not visible
    }
}

#pragma mark - Buttons

- (void)doneButtonPressed:(id)sender {
    if (_senderViewForAnimation && _currentPageIndex == _initalPageIndex) {
        IDMZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
        [self performCloseAnimationWithScrollView:scrollView];
    }
    else {
        _senderViewForAnimation.hidden = NO;
        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:YES];
    }
}

- (void)downloadButtonPressed:(id)sender {
    id <IDMPhoto> photo = [self photoAtIndex:_currentPageIndex];
    if ([self.delegate respondsToSelector:@selector(image:didFinishSavingWithError:contextInfo:)]) {
        UIImageWriteToSavedPhotosAlbum(photo.underlyingImage, self.delegate, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    }
}

- (void)imageListButtonPressed {
    _photosListView.isShow = YES;
}

- (void)actionButtonPressed:(id)sender {
    id <IDMPhoto> photo = [self photoAtIndex:_currentPageIndex];
    
    if ([self numberOfPhotos] > 0 && [photo underlyingImage]) {
        if(!_actionButtonTitles)
        {
            // Activity view
            NSMutableArray *activityItems = [NSMutableArray arrayWithObject:[photo underlyingImage]];
            if (photo.caption) [activityItems addObject:photo.caption];
            
            self.activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            
            __typeof__(self) __weak selfBlock = self;
            [self.activityViewController setCompletionHandler:^(NSString *activityType, BOOL completed) {
                //[selfBlock hideControlsAfterDelay];
                [selfBlock hideControls];
                selfBlock.activityViewController = nil;
            }];
            
            [self presentViewController:self.activityViewController animated:YES completion:nil];
        }
        else
        {
            // Action sheet
            self.actionsSheet = [UIActionSheet new];
            self.actionsSheet.delegate = self;
            for(NSString *action in _actionButtonTitles) {
                [self.actionsSheet addButtonWithTitle:action];
            }
            
            self.actionsSheet.cancelButtonIndex = [self.actionsSheet addButtonWithTitle:IDMPhotoBrowserLocalizedStrings(@"Cancel")];
            self.actionsSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [_actionsSheet showFromBarButtonItem:sender animated:YES];
            } else {
                [_actionsSheet showInView:self.view];
            }
        }
        
        // Keep controls hidden
        [self setControlsHidden:NO animated:YES permanent:YES];
    }
}

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (actionSheet == _actionsSheet) {
        self.actionsSheet = nil;
        
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            if ([_delegate respondsToSelector:@selector(photoBrowser:didDismissActionSheetWithButtonIndex:photoIndex:)]) {
                [_delegate photoBrowser:self didDismissActionSheetWithButtonIndex:buttonIndex photoIndex:_currentPageIndex];
                return;
            }
        }
    }
    
    //[self hideControlsAfterDelay]; // Continue as normal...
    [self hideControls];
}


- (void)imageBtnClick:(NSInteger)index
{
    CGRect pageFrame = [self frameForPageAtIndex:index];
    _pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);
}

#pragma mark - pop Animation

- (void)animateView:(UIView *)view toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
    [animation setSpringBounciness:0];
    //[animation setDynamicsMass:1];
    [animation setToValue:[NSValue valueWithCGRect:frame]];
    [view pop_addAnimation:animation forKey:nil];
    
    if (completion)
    {
        [animation setCompletionBlock:^(POPAnimation *animation, BOOL finished) {
            completion();
        }];
    }
}

@end
