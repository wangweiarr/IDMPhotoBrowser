//
//  IDMPhotoSideList.h
//  PhotoBrowserDemo
//
//  Created by mac on 15/2/13.
//
//

#import <UIKit/UIKit.h>
#import "IDMPhoto.h"
@protocol IDMPhotoSideListDelegate <NSObject>
@required
- (void)imageBtnClick:(NSInteger)index;
@end

@interface IDMPhotoSideListView : UIToolbar
@property (weak, nonatomic) id<IDMPhotoSideListDelegate> imageDelegate;
@property (strong, nonatomic) UIScrollView* scrollView;
@property (strong, nonatomic) NSArray* photos;
@property (nonatomic) BOOL isShow;

- (instancetype)initWithPhotos:(NSArray*)photos placeholderRate:(CGFloat)placeholderRate;
- (instancetype)initWithImages:(NSArray*)imageList placeholderRate:(CGFloat)placeholderRate;
- (instancetype)initWithImageURLs:(NSArray*)imageURLList placeholderRate:(CGFloat)placeholderRate;
@end
