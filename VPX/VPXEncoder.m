//
//  VPXEncoder.m
//  VPX
//
//  Created by Morten Bertz on 7/13/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "VPXEncoder.h"
#include "vpx/vpx_encoder.h"
#import <Accelerate/Accelerate.h>
#include "./tools_common.h"
#include "./video_writer.h"


static const char *exec_name;

@implementation VPXEncoder{
    vpx_codec_ctx_t codec;
    VpxVideoWriter *writer;
    int frame_count;
    int keyframe_interval;
    
}

-(instancetype)initWithURL:(NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size{
    self=[super init];
    if (self) {
        
        writer=NULL;
        vpx_codec_enc_cfg_t cfg;
        keyframe_interval=0;
        frame_count=0;
        vpx_codec_err_t res;
        VpxVideoInfo info = {0};
        
        const VpxInterface *encoder = NULL;
        const int fps = (int)rate;        // TODO(dkovalev) add command line argument
        const int bitrate = 200;   // kbit/s TODO(dkovalev) add command line argument
       
        encoder = get_vpx_encoder_by_name("vp8");
        
        info.codec_fourcc = encoder->fourcc;
        info.frame_width = size.width;
        info.frame_height = size.height;
        info.time_base.numerator = 1;
        info.time_base.denominator = fps;
//        if (!vpx_img_alloc(&raw, VPX_IMG_FMT_I420, info.frame_width,
//                           info.frame_height, 1)) {
//            die("Failed to allocate image.");
//        }
        res = vpx_codec_enc_config_default(encoder->codec_interface(), &cfg, 0);
        if (res){
            die_codec(&codec, "Failed to get default codec config.");
        }
        
        cfg.g_w = info.frame_width;
        cfg.g_h = info.frame_height;
        cfg.g_timebase.num = info.time_base.numerator;
        cfg.g_timebase.den = info.time_base.denominator;
        cfg.rc_target_bitrate = bitrate;
        cfg.g_error_resilient =  0;
        writer = vpx_video_writer_open(url.fileSystemRepresentation, kContainerIVF, &info);
        if (vpx_codec_enc_init(&codec, encoder->codec_interface(), &cfg, 0)){
            die_codec(&codec, "Failed to initialize encoder");
        }
    }
    return self;
}




-(void)addFrame:(CGImageRef)frame atTime:(NSTimeInterval)time{
    
    
    unsigned int maxDimension=MAX(CGImageGetWidth(frame), CGImageGetHeight(frame));
    
    unsigned int v=maxDimension; // compute the next highest power of 2 of 32-bit v http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2Float
    
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    
    //this is a bit of a hackish way to get around the fact that VP8 wants images that have dimensions (and an alignment) of a power of 2
    
    CGContextRef context=CGBitmapContextCreate(NULL, v, v, CGImageGetBitsPerComponent(frame), 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(frame), CGImageGetHeight(frame)), frame);
    CGImageRef resized=CGBitmapContextCreateImage(context);
    CGContextRelease(context);

    
    vImage_CGImageFormat format;
    format.bitsPerComponent=(uint32_t)CGImageGetBitsPerComponent(resized);
    format.bitsPerPixel=(uint32_t)CGImageGetBitsPerPixel(resized);
    format.colorSpace=NULL;
    format.bitmapInfo=CGImageGetBitmapInfo(resized);
    format.version=0;
    format.decode=NULL;
    vImage_Buffer buffer;
    
    vImage_Error imageError=vImageBuffer_InitWithCGImage(&buffer, &format, NULL, resized, kvImagePrintDiagnosticsToConsole);

    if (imageError!=kvImageNoError) {
        NSLog(@"image error %zd",imageError);
    }

    
    
    
    
    vImage_Error err;
//    vImage_Buffer destY;
//    err= vImageBuffer_Init(&destY, CGImageGetHeight(frame), CGImageGetWidth(frame), 8, kvImagePrintDiagnosticsToConsole);
//    if (err!=kvImageNoError) {
//        NSLog(@"conversion generation error %zd",err);
//    }
//    vImage_Buffer destCb;
//    err= vImageBuffer_Init(&destCb, CGImageGetHeight(frame), CGImageGetWidth(frame), 8, kvImagePrintDiagnosticsToConsole);
//    if (err!=kvImageNoError) {
//        NSLog(@"conversion generation error %zd",err);
//    }
//    vImage_Buffer destCr;
//    err= vImageBuffer_Init(&destCr, CGImageGetHeight(frame), CGImageGetWidth(frame), 8, kvImagePrintDiagnosticsToConsole);
//    if (err!=kvImageNoError) {
//        NSLog(@"conversion generation error %zd",err);
//    }
//    
//    
//    //vImage_Flags flags = kvImageNoFlags;
//    vImage_YpCbCrPixelRange pixelRange;
//    vImage_ARGBToYpCbCr outInfo;
//    
//    pixelRange.Yp_bias         =   16;     // encoding for Y' = 0.0
//    pixelRange.CbCr_bias       =  128;     // encoding for CbCr = 0.0
//    pixelRange.YpRangeMax      =  235;     // encoding for Y'= 1.0
//    pixelRange.CbCrRangeMax    =  240;     // encoding for CbCr = 0.5
//    pixelRange.YpMax           =  255;     // a clamping limit above which the value is not allowed to go. 255 is fastest. Use pixelRange.YpRangeMax if you don't want Y' > 1.
//    pixelRange.YpMin           =    0;     // a clamping limit below which the value is not allowed to go. 0 is fastest. Use pixelRange.Yp_bias if you don't want Y' < 0.
//    pixelRange.CbCrMax         =  255;     // a clamping limit above which the value is not allowed to go. 255 is fastest.  Use pixelRange.CbCrRangeMax, if you don't want CbCr > 0.5
//    pixelRange.CbCrMin         =    0;     // a clamping limit above which the value is not allowed to go. 0 is fastest.  Use (2*pixelRange.CbCr_bias - pixelRange.CbCrRangeMax), if you don't want CbCr < -0.5
//    
//    err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage420Yp8_Cb8_Cr8, 0);
//    if (err!=kvImageNoError) {
//        NSLog(@"conversion generation error %zd",err);
//    }
//    uint8_t map[4]={1,2,3,0};
//    err=vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&buffer, &destY, &destCb, &destCr, &outInfo, map, 0);
//    if (err!=kvImageNoError) {
//        NSLog(@"conversion generation error %zd",err);
//    }
//    
//    vpx_image_t *image=vpx_img_alloc(NULL, VPX_IMG_FMT_I420, (uint)CGImageGetWidth(frame), (uint)CGImageGetHeight(frame), (uint)destY.rowBytes);
//    image->planes[VPX_PLANE_Y]=destY.data;
//    image->planes[VPX_PLANE_U]=destCr.data;
//    image->planes[VPX_PLANE_V]=destCb.data;
//    image->stride[VPX_PLANE_Y]=CGImageGetWidth(frame);
//    image->stride[VPX_PLANE_U]=CGImageGetWidth(frame)/2;
//    image->stride[VPX_PLANE_V]=CGImageGetWidth(frame)/2;
    
    
    
    
    
    
    
    vImage_Buffer dest;
    err= vImageBuffer_Init(&dest, CGImageGetHeight(resized), CGImageGetWidth(resized), 24, kvImagePrintDiagnosticsToConsole);
    if (err!=kvImageNoError) {
        NSLog(@"conversion generation error %zd",err);
    }
    
//    dest.height=CGImageGetHeight(frame);
//    dest.width=CGImageGetWidth(frame);
//    dest.rowBytes=3*dest.width;
//    dest.data=calloc(dest.width*dest.height*3, 1);

    Pixel_8888 bg={255,255,255,255};
    err=vImageFlatten_RGBA8888ToRGB888(&buffer, &dest,bg, YES, 0); //not sure is premultiplied is always true 
    if (err!=kvImageNoError) {
        NSLog(@"conversion generation error %zd",err);
    }
    free(buffer.data);
    uint8_t *YUV=calloc(sizeof(uint8_t), CGImageGetWidth(resized)*CGImageGetHeight(resized)*2);
    Bitmap2Yuv420p_calc2(YUV, dest.data, CGImageGetWidth(resized), CGImageGetHeight(resized));
    free(dest.data);
    
    vpx_image_t *image=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, (uint)CGImageGetWidth(resized), (uint)CGImageGetHeight(resized), CGImageGetWidth(resized), YUV);
    //alignment has to be a power of 2
    vpx_img_set_rect(image, 0, CGImageGetHeight(resized)-CGImageGetHeight(frame), CGImageGetWidth(frame), CGImageGetHeight(frame));
    
    
    
    int flags = 0;
    if (keyframe_interval > 0 && frame_count % keyframe_interval == 0){
        flags |= VPX_EFLAG_FORCE_KF;
    }
    encode_frame(&codec, image, frame_count++, flags, writer);
    vpx_img_free(image);
    free(YUV);
    CGImageRelease(resized);
    
    
}


-(void)finalizeWithCompletion:(void(^)(BOOL success))completion{
    
    while (encode_frame(&codec, NULL, -1, 0, writer)) {};
    
    
//    vpx_img_free(&raw);
    if (vpx_codec_destroy(&codec))
    die_codec(&codec, "Failed to destroy codec.");
    vpx_video_writer_close(writer);
    completion(YES);
    
}

//thanks to http://stackoverflow.com/questions/9465815/rgb-to-yuv420-algorithm-efficiency
//could probably be done using vImage as well, but would require memCopy and the the exact output format is poorly documented.

void Bitmap2Yuv420p_calc2(uint8_t *destination, uint8_t *rgb, size_t width, size_t height)
{
    size_t image_size = width * height;
    size_t upos = image_size;
    size_t vpos = upos + upos / 4;
    size_t i = 0;
    
    for( size_t line = 0; line < height; ++line )
    {
        if( !(line % 2) )
        {
            for( size_t x = 0; x < width; x += 2 )
            {
                uint8_t r = rgb[3 * i];
                uint8_t g = rgb[3 * i + 1];
                uint8_t b = rgb[3 * i + 2];
                
                destination[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
                
                destination[upos++] = ((-38*r + -74*g + 112*b) >> 8) + 128;
                destination[vpos++] = ((112*r + -94*g + -18*b) >> 8) + 128;
                
                r = rgb[3 * i];
                g = rgb[3 * i + 1];
                b = rgb[3 * i + 2];
                
                destination[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
            }
        }
        else
        {
            for( size_t x = 0; x < width; x += 1 )
            {
                uint8_t r = rgb[3 * i];
                uint8_t g = rgb[3 * i + 1];
                uint8_t b = rgb[3 * i + 2];
                
                destination[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
            }
        }
    }
}



static int encode_frame(vpx_codec_ctx_t *codec,
                        vpx_image_t *img,
                        int frame_index,
                        int flags,
                        VpxVideoWriter *writer) {
    int got_pkts = 0;
    vpx_codec_iter_t iter = NULL;
    const vpx_codec_cx_pkt_t *pkt = NULL;
    const vpx_codec_err_t res = vpx_codec_encode(codec, img, frame_index, 1,
                                                 flags, VPX_DL_GOOD_QUALITY);
    if (res != VPX_CODEC_OK)
    die_codec(codec, "Failed to encode frame");
    
    while ((pkt = vpx_codec_get_cx_data(codec, &iter)) != NULL) {
        got_pkts = 1;
        
        if (pkt->kind == VPX_CODEC_CX_FRAME_PKT) {
            const int keyframe = (pkt->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
            if (!vpx_video_writer_write_frame(writer,
                                              pkt->data.frame.buf,
                                              pkt->data.frame.sz,
                                              pkt->data.frame.pts)) {
                die_codec(codec, "Failed to write compressed frame");
            }
            printf(keyframe ? "K" : ".");
            fflush(stdout);
        }
    }
    
    return got_pkts;
}



void usage_exit(void) {
    fprintf(stderr,
            "Usage: %s <codec> <width> <height> <infile> <outfile> "
            "<keyframe-interval> [<error-resilient>]\nSee comments in "
            "simple_encoder.c for more information.\n",
            exec_name);
    exit(EXIT_FAILURE);
}

@end
