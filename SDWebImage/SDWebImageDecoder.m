/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * Created by james <https://github.com/mystcolor> on 9/28/11.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDecoder.h"

#define DECOMPRESSED_IMAGE_KEY @"decompressedImage"
#define DECODE_INFO_KEY @"decodeInfo"

#define IMAGE_KEY @"image"
#define DELEGATE_KEY @"delegate"
#define USER_INFO_KEY @"userInfo"

@implementation SDWebImageDecoder
static SDWebImageDecoder *sharedInstance;

- (void)notifyDelegateOnMainThreadWithInfo:(NSDictionary *)dict
{
    SDWIRetain(dict);
    NSDictionary *decodeInfo = [dict objectForKey:DECODE_INFO_KEY];
    UIImage *decodedImage = [dict objectForKey:DECOMPRESSED_IMAGE_KEY];

    id <SDWebImageDecoderDelegate> delegate = [decodeInfo objectForKey:DELEGATE_KEY];
    NSDictionary *userInfo = [decodeInfo objectForKey:USER_INFO_KEY];

    [delegate imageDecoder:self didFinishDecodingImage:decodedImage userInfo:userInfo];
    SDWIRelease(dict);
}

- (void)decodeImageWithInfo:(NSDictionary *)decodeInfo
{
    UIImage *image = [decodeInfo objectForKey:IMAGE_KEY];

    UIImage *decompressedImage = [UIImage decodedImageWithImage:image];
    if (!decompressedImage)
    {
        // If really have any error occurs, we use the original image at this moment
        decompressedImage = image;
    }

    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          decompressedImage, DECOMPRESSED_IMAGE_KEY,
                          decodeInfo, DECODE_INFO_KEY, nil];

    [self performSelectorOnMainThread:@selector(notifyDelegateOnMainThreadWithInfo:) withObject:dict waitUntilDone:NO];
}

- (id)init
{
    if ((self = [super init]))
    {
        // Initialization code here.
        imageDecodingQueue = [[NSOperationQueue alloc] init];
    }

    return self;
}

- (void)decodeImage:(UIImage *)image withDelegate:(id<SDWebImageDecoderDelegate>)delegate userInfo:(NSDictionary *)info
{
    NSDictionary *decodeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                image, IMAGE_KEY,
                                delegate, DELEGATE_KEY,
                                info, USER_INFO_KEY, nil];

    NSOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(decodeImageWithInfo:) object:decodeInfo];
    [imageDecodingQueue addOperation:operation];
    SDWIRelease(operation);
}

- (void)dealloc
{
    SDWISafeRelease(imageDecodingQueue);
    SDWISuperDealoc;
}

+ (SDWebImageDecoder *)sharedImageDecoder
{
    if (!sharedInstance)
    {
        sharedInstance = [[SDWebImageDecoder alloc] init];
    }
    return sharedInstance;
}

@end


@implementation UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image
{
	// b.bojko@bigspaceship.com:
	// fixed "unsupported parameter combination" errors
	// by replacing this code with example from (essentially just
	// always use 4 bytes for argb instead of rgb occasionally)
	// http://ioscodesnippet.tumblr.com/post/10924101444/force-decompressing-uiimage-in-background-to-achieve
	
    CGImageRef imageRef = image.CGImage;
    // System only supports RGB, set explicitly and prevent context error
    // if the downloaded image is not the supported format
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGImageGetWidth(imageRef),
                                                 CGImageGetHeight(imageRef),
                                                 8,
                                                 // width * 4 will be enough because are in ARGB format, don't read from the image
                                                 CGImageGetWidth(imageRef) * 4,
                                                 colorSpace,
                                                 // kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
                                                 // makes system don't need to do extra conversion when displayed.
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
	
    if ( ! context) {
        return nil;
    }
    
    CGRect rect = (CGRect){CGPointZero, {CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)}};
    CGContextDrawImage(context, rect, imageRef);
    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    UIImage *decompressedImage = [[UIImage alloc] initWithCGImage:decompressedImageRef];
    CGImageRelease(decompressedImageRef);
//    return [decompressedImage autorelease];
    return SDWIReturnAutoreleased(decompressedImage);
}

@end
