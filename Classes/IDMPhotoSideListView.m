
//
//  IDMPhotoSideList.m
//  PhotoBrowserDemo
//
//  Created by mac on 15/2/13.
//
//

#import "IDMPhotoSideListView.h"

static CGFloat const kImagePaddingY = 10;
static CGFloat const kImageMarginSide = 5;

@implementation IDMPhotoSideListView
- (void)setIsShow:(BOOL)isShow
{
    if (_isShow == isShow) {
        return;
    }
    
    _isShow = isShow;
    [UIView animateWithDuration:0.3 animations:^{
        if (_isShow) {
            self.frame = CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds) - self.bounds.size.width, 0, self.bounds.size.width, self.bounds.size.height);
        }
        else {
            self.frame = CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds), 0, self.bounds.size.width, self.bounds.size.height);
        }
    }];
}

- (instancetype)initWithPhotos:(NSArray*)photos placeholderRate:(CGFloat)placeholderRate
{
    self = [super initWithFrame:CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds), 0, 100, CGRectGetHeight([UIScreen mainScreen].bounds))];
    if (self) {
        self.barStyle = UIBarStyleBlack;
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        [self addSubview:self.scrollView];
        self.photos = photos;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleIDMPhotoLoadingDidEndNotification:)
                                                     name:IDMPhoto_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
        CGSize imageSize = CGSizeMake(self.bounds.size.width - 2 * kImageMarginSide, (self.bounds.size.width - 2 * kImageMarginSide) / placeholderRate);
        self.scrollView.contentSize = CGSizeMake(0, photos.count * imageSize.height + (photos.count + 1) * kImagePaddingY);
        if (self.scrollView.contentSize.height <= self.bounds.size.height) {
            self.scrollView.contentSize = CGSizeMake(0, self.bounds.size.height + 1);
        }
        for (NSInteger i = 0; i < photos.count; i++) {
            IDMPhoto* currentPhoto = photos[i];
            UIButton* btn = [[UIButton alloc] initWithFrame:CGRectMake(kImageMarginSide, (i + 1) * kImagePaddingY + i * imageSize.height, imageSize.width, imageSize.height)];
            btn.tag = i + 1;
            btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
            if ([currentPhoto underlyingImage]) {
                [btn setImage:currentPhoto.underlyingImage forState:UIControlStateNormal];
            } else {
                UIActivityIndicatorView* activityView = [[UIActivityIndicatorView alloc] initWithFrame:btn.bounds];
                activityView.tag = 1000;
                [btn addSubview:activityView];
                [activityView startAnimating];
                [currentPhoto loadUnderlyingImageAndNotify];
            }
            [btn addTarget:self action:@selector(imageBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [self.scrollView addSubview:btn];
        }
    }
    return self;
}

- (instancetype)initWithImages:(NSArray*)imageList placeholderRate:(CGFloat)placeholderRate
{
    self = [self initWithFrame:CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds), 0, 100, CGRectGetHeight([UIScreen mainScreen].bounds))];
    if (self) {
        self.barStyle = UIBarStyleBlack;
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        [self addSubview:self.scrollView];
        CGSize imageSize = CGSizeMake(self.bounds.size.width - 2 * kImageMarginSide, placeholderRate / (self.bounds.size.width - 2 * kImageMarginSide));
        self.scrollView.contentSize = CGSizeMake(0, imageList.count * imageSize.height + (imageList.count + 1) * kImagePaddingY);
        for (NSInteger i = 0; i < imageList.count; i++) {
            UIButton* btn = [[UIButton alloc] initWithFrame:CGRectMake(kImageMarginSide, (i + 1) * kImagePaddingY + i * imageSize.height, imageSize.width, imageSize.height)];
            btn.tag = i + 1;
            btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
            UIImage* currentImg = imageList[i];
            [btn setImage:currentImg forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(imageBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
        }
    }
    return self;
}

- (instancetype)initWithImageURLs:(NSArray*)imageURLList placeholderRate:(CGFloat)placeholderRate
{
    self = [self initWithFrame:CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds), 0, 100, CGRectGetHeight([UIScreen mainScreen].bounds))];
    if (self) {
        self.barStyle = UIBarStyleBlack;
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        [self addSubview:self.scrollView];
        CGSize imageSize = CGSizeMake(self.bounds.size.width - 2 * kImageMarginSide, placeholderRate / (self.bounds.size.width - 2 * kImageMarginSide));
        self.scrollView.contentSize = CGSizeMake(0, imageURLList.count * imageSize.height + (imageURLList.count + 1) * kImagePaddingY);
        for (NSInteger i = 0; i < imageURLList.count; i++) {
            NSURL* imageURL = imageURLList[i];
            UIButton* btn = [[UIButton alloc] initWithFrame:CGRectMake(kImageMarginSide, (i + 1) * kImagePaddingY + i * imageSize.height, imageSize.width, imageSize.height)];
            btn.tag = i + 1;
            btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
            UIImage* currentImg = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
            [btn setImage:currentImg forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(imageBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
        }
    }
    return self;
}

- (void)setNeedsLayout
{
    [super setNeedsLayout];
    if (_isShow) {
        self.frame = CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds) - self.bounds.size.width, 0, self.bounds.size.width, self.bounds.size.height);
    }
    else {
        self.frame = CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds), 0, self.bounds.size.width, self.bounds.size.height);
    }
    self.scrollView.frame = self.bounds;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)imageBtnClick:(UIButton*)sender
{
    if ([sender imageForState:UIControlStateNormal]) {
        if ([self.imageDelegate respondsToSelector:@selector(imageBtnClick:)]) {
            [self.imageDelegate imageBtnClick:sender.tag - 1];
        }
    }
}


#pragma mark - IDMPhoto Loading Notification
- (void)handleIDMPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <IDMPhoto> photo = [notification object];
    NSInteger index = [self.photos indexOfObject:photo] + 1;
    UIButton* currentBtn = (UIButton*)[self viewWithTag:index];
    if ([photo underlyingImage]) {
        // Successful load
        [[currentBtn viewWithTag:1000] removeFromSuperview];
        [currentBtn setImage:[photo underlyingImage] forState:UIControlStateNormal];
    } else {
        // Failed to load
    }
}
@end
