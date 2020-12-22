//
//  VPXEncoder2.m
//  VPX
//
//  Created by Morten Bertz on 7/18/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "VPXEncoder2.h"
#import <Accelerate/Accelerate.h>


#import <libVPX/vpx/vpx_encoder.h>
#import <libVPX/vpx/vpx_codec.h>
#import <libVPX/vpx/vp8cx.h>
#import <libVPX/vpx/tools_common.h>
#import <WebM/mkvmuxer.hpp>
#import <WebM/mkvwriter.hpp>

static const char *exec_name;

@implementation VPXEncoder2{
    
    vpx_codec_ctx_t codec;
    vpx_codec_ctx_t codec_alpha;
  

    int frame_count;
    int keyframe_interval;
    
    double elapsedTimeInSec;

    NSURL *outURL;
    CGSize _outputSize;
    NSUInteger _frameRate;
    mkvmuxer::MkvWriter mkvWriter;
    mkvmuxer::Segment _muxer_segment;
    
}



-(instancetype)initWithURL:(NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha{
    return [self initWithURL:url framerate:rate size:size preserveAlpha:alpha encoder:VPXEncoderTypeVP8];
}

-(instancetype)initWithURL:(NSURL *)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha encoder:(VPXEncoderType)encoder{
    self=[super init];
    if (self) {
        outURL=url;
        self.preserveAlpha=alpha;
        _outputSize=size;
        _frameRate=rate;
        self.encoderType=encoder;
    }
    return self;
}



-(void)configureEncoder{
    elapsedTimeInSec=0;
    
    vpx_codec_enc_cfg_t cfg;
    keyframe_interval=10;
    frame_count=0;
    vpx_codec_err_t res;
    VpxVideoInfo info = {0};
    
    const VpxInterface *encoder = NULL;
    const int fps = (int)_frameRate;        // TODO(dkovalev) add command line argument
    const int bitrate = 20000;   // kbit/s TODO(dkovalev) add command line argument
    
    switch (self.encoderType) {
        case VPXEncoderTypeVP8:
             encoder = get_vpx_encoder_by_name("vp8");
            break;
        case VPXEncoderTypeVP9:
            encoder = get_vpx_encoder_by_name("vp9");
            break;
        default:
            NSLog(@"No Valid decoder selected");
            abort();
            break;
    }
   
    
    info.codec_fourcc = encoder->fourcc;
    info.frame_width = _outputSize.width;
    info.frame_height = _outputSize.height;
    info.time_base.numerator = 1;
    info.time_base.denominator = fps;
    
    res = vpx_codec_enc_config_default(encoder->codec_interface(), &cfg, 0);
    if (res){
        die_codec(&codec, "Failed to get default codec config.");
    }
    
    cfg.g_w = info.frame_width;
    cfg.g_h = info.frame_height;
    cfg.g_timebase.num = 1;
    cfg.g_timebase.den = 1000;
    cfg.rc_target_bitrate = bitrate;
    cfg.g_error_resilient =  0;
    
    
    if (!mkvWriter.Open(outURL.fileSystemRepresentation)) {
        fprintf(stderr, "\n Error while opening output file.\n");
        
    }
    if (!_muxer_segment.Init(&mkvWriter)) {
        fprintf(stderr, "\n Could not initialize muxer segment!\n");
        
    }
    uint64_t vid_track= _muxer_segment.AddVideoTrack(_outputSize.width, _outputSize.height, 1);
    mkvmuxer::VideoTrack* const video =
    static_cast<mkvmuxer::VideoTrack*>(_muxer_segment.GetTrackByNumber(vid_track));
    
    if (vpx_codec_enc_init(&codec, encoder->codec_interface(), &cfg, 0)){
        die_codec(&codec, "Failed to initialize encoder");
    }
    
    if (!video) {
        fprintf(stderr, "\n Could not get video track.\n");
        //return 0;
    }
    video->set_codec_id(mkvmuxer::Tracks::kVp8CodecId);
    
    if (self.preserveAlpha) {
        video->SetAlphaMode(1);
        video->set_max_block_additional_id(1);
        
        if (vpx_codec_enc_init(&codec_alpha, encoder->codec_interface(), &cfg, 0)){
            die_codec(&codec, "Failed to initialize encoder");
        }
        
    }
}




-(void)addFrame:(CGImageRef)frame atTime:(NSTimeInterval)time{
    
    if (codec.name == NULL) {
        [self configureEncoder];
    }
    
    unsigned int maxDimension=(unsigned int)MAX(CGImageGetWidth(frame), CGImageGetHeight(frame));
    unsigned int v=maxDimension; // compute the next highest power of 2 of 32-bit v http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2Float
    
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    
    if (self.preserveAlpha) {
        
        uint8_t *resizedBuffer=(uint8_t*)calloc(v*v*4, 1);
        
        CGContextRef context=CGBitmapContextCreate(resizedBuffer, v, v, CGImageGetBitsPerComponent(frame), v*4, colorSpace, kCGImageAlphaPremultipliedLast);
        CGContextSetFillColorWithColor(context, self.backgroundColor);
        
        if (self.backgroundColor) {
            CGContextFillRect(context, CGRectMake(0, 0, v, v));
            CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(frame), CGImageGetHeight(frame)), frame);
        }

        uint8_t *YUV=(uint8_t*)calloc(v*v*2, 1);
        uint8_t *alpha=(uint8_t*)calloc(v*v*2, 1);
        RGBA888ToYuv420p(YUV, alpha, resizedBuffer, v, v);
        
        if (self.backgroundColor) {
            uint8_t *alphaBuffer=(uint8_t*)calloc(v*v*4, 1);
            CGContextRef alphaContext=CGBitmapContextCreate(alphaBuffer, v, v, CGImageGetBitsPerComponent(frame), v*4, colorSpace, kCGImageAlphaPremultipliedLast);
            CGContextDrawImage(alphaContext, CGRectMake(0, 0, CGImageGetWidth(frame), CGImageGetHeight(frame)), frame);
            uint8_t *dummy=(uint8_t*)calloc(v*v*2, 1);
            RGBA888ToYuv420p(dummy, alpha, alphaBuffer, v, v);
            free(dummy);
            free(alphaBuffer);
            CGContextRelease(alphaContext);
        }

        //this could be done more elegantly and les computationally intensive, but overall the drawing is a miniscule parrt of the computational load during encoding.

        vpx_image_t *image=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, v, v, v, YUV);
        vpx_image_t *image_alpha=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, v, v, v, alpha);
        vpx_img_set_rect(image, 0, v-(unsigned int)CGImageGetHeight(frame), (unsigned int)CGImageGetWidth(frame), (unsigned int)CGImageGetHeight(frame));
        vpx_img_set_rect(image_alpha, 0, v-(unsigned int)CGImageGetHeight(frame), (unsigned int)CGImageGetWidth(frame), (unsigned int)CGImageGetHeight(frame));
        
        int flags = 0;
        if (keyframe_interval > 0 && frame_count % keyframe_interval == 0){
            flags |= VPX_EFLAG_FORCE_KF;
        }
        
        encode_frameAlpha(&codec, image, &codec_alpha, image_alpha, frame_count++, elapsedTimeInSec ,flags, &(_muxer_segment));
        elapsedTimeInSec+=time;
       
        vpx_img_free(image);
        vpx_img_free(image_alpha);
        free(resizedBuffer);
        free(YUV);
        free(alpha);
        CGContextRelease(context);
    }
    else{
        //this is a bit of a hackish way to get around the fact that VP8 wants images that have dimensions (and an alignment) of a power of 2
        
        CGContextRef context=CGBitmapContextCreate(NULL, v, v, CGImageGetBitsPerComponent(frame), 0, colorSpace, kCGImageAlphaPremultipliedLast);
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
        
        vImage_Buffer dest;
        err= vImageBuffer_Init(&dest, CGImageGetHeight(resized), CGImageGetWidth(resized), 24, kvImagePrintDiagnosticsToConsole);
        if (err!=kvImageNoError) {
            NSLog(@"conversion generation error %zd",err);
        }
        const CGFloat *components=CGColorGetComponents(self.backgroundColor);
        size_t numberOfComponents=CGColorGetNumberOfComponents(self.backgroundColor);
        Pixel_8888 bg={255,255,255,255};
        
        for (NSUInteger i=0; i<numberOfComponents; i++) {
            bg[i]=components[i]*255;
        }

        if(numberOfComponents<4){
            bg[3]=255;
        }
   
        err=vImageFlatten_RGBA8888ToRGB888(&buffer, &dest,bg, YES, 0); //not sure is premultiplied is always true
        if (err!=kvImageNoError) {
            NSLog(@"conversion generation error %zd",err);
        }
        free(buffer.data);
        uint8_t *YUV=(uint8_t*)calloc(sizeof(uint8_t), CGImageGetWidth(resized)*CGImageGetHeight(resized)*2);
        Bitmap2Yuv420p_calc2(YUV, (uint8_t*)dest.data, CGImageGetWidth(resized), CGImageGetHeight(resized));
        free(dest.data);
        
        
        vpx_image_t *image=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, v, v, v, YUV);
        //alignment has to be a power of 2
        vpx_img_set_rect(image, 0, v-(unsigned int)CGImageGetHeight(frame), (unsigned int)CGImageGetWidth(frame), (unsigned int)CGImageGetHeight(frame));
        
        
        int flags = 0;
        if (keyframe_interval > 0 && frame_count % keyframe_interval == 0){
            flags |= VPX_EFLAG_FORCE_KF;
        }
        encode_frame(&codec, image, frame_count++, elapsedTimeInSec,flags,&(_muxer_segment));
        elapsedTimeInSec+=time;
        vpx_img_free(image);
        free(YUV);
        CGImageRelease(resized);

    }
    
    frame_count+=1;
    CGColorSpaceRelease(colorSpace);
}







-(void)finalizeWithCompletion:(void(^)(BOOL success))completion{
    
    if (self.preserveAlpha) {
        while (encode_frameAlpha(&codec, NULL, &codec_alpha, NULL, -1, 0 ,0, &(_muxer_segment))) {};
    }
    else{
        while (encode_frame(&codec, NULL, -1,0, 0, &(_muxer_segment))) {};
    }
    
    
    
    if (vpx_codec_destroy(&codec))
        die_codec(&codec, "Failed to destroy codec.");

    if (self.preserveAlpha) {
        if (vpx_codec_destroy(&codec_alpha))
            die_codec(&codec, "Failed to destroy codec.");
    }
    
    if (!_muxer_segment.Finalize())
        fprintf(stderr, "Finalization of segment failed.\n");
    mkvWriter.Close();

    if (self.backgroundColor) {
        //CGColorRelease(self.backgroundColor);
    }
    completion(YES);
    
}









static int encode_frameAlpha(vpx_codec_ctx_t *codec,
                             vpx_image_t *img,
                             vpx_codec_ctx_t *codec_alpha,
                             vpx_image_t *img_alpha,
                             int frame_index,
                             double presentationTime,
                             int flags,
                             mkvmuxer::Segment *segment) {

    int got_pkts = 0;
    vpx_codec_iter_t iter = NULL;
    vpx_codec_iter_t iter_alpha = NULL;
    const vpx_codec_cx_pkt_t *pkt = NULL;
    const vpx_codec_cx_pkt_t *pkt_alpha = NULL;
     vpx_codec_err_t res = vpx_codec_encode(codec, img, frame_index, 1,
                                                 flags, VPX_DL_BEST_QUALITY);
    if (res != VPX_CODEC_OK)
        die_codec(codec, "Failed to encode frame");
    res = vpx_codec_encode(codec_alpha, img_alpha, frame_index, 1,
                                                 flags, VPX_DL_BEST_QUALITY);
    
    if (res != VPX_CODEC_OK)
        die_codec(codec, "Failed to encode frame");
    
    while ((pkt = vpx_codec_get_cx_data(codec, &iter)) != NULL && (pkt_alpha = vpx_codec_get_cx_data(codec_alpha, &iter_alpha))) {
        got_pkts = 1;
        
        if (pkt->kind == VPX_CODEC_CX_FRAME_PKT) {
            
            uint64_t pts=(uint64_t)(presentationTime*1e9);
            const int keyframe = (pkt->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
            BOOL success= segment->AddFrameWithAdditional((const uint8_t*)pkt->data.frame.buf,
                                                  pkt->data.frame.sz,
                                                  (const uint8_t*)pkt_alpha->data.frame.buf,
                                                  pkt_alpha->data.frame.sz,
                                                  1, 1,
                                                  pts,
            keyframe);
            
           
            if (!success) {
                die_codec(codec, "Failed to write compressed frame");
            }
            //            printf(keyframe ? "K" : ".");
            //            fflush(stdout);
        }
    }
    
    return got_pkts;

}



static int encode_frame(vpx_codec_ctx_t *codec,
                         vpx_image_t *img,
                         int frame_index,
                         double presentationTime,
                         int flags,
                         mkvmuxer::Segment *segment) {
    int got_pkts = 0;
    vpx_codec_iter_t iter = NULL;
    
    const vpx_codec_cx_pkt_t *pkt = NULL;
   
    vpx_codec_err_t res = vpx_codec_encode(codec, img, frame_index, 1,
                                           flags, VPX_DL_GOOD_QUALITY);
    if (res != VPX_CODEC_OK)
        die_codec(codec, "Failed to encode frame");
    
    
    while ((pkt = vpx_codec_get_cx_data(codec, &iter)) != NULL) {
        got_pkts = 1;
        
        if (pkt->kind == VPX_CODEC_CX_FRAME_PKT) {
             uint64_t pts=(uint64_t)(presentationTime*1e9);
             const int keyframe = (pkt->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
            BOOL success= segment->AddFrame((const uint8_t*)pkt->data.frame.buf, pkt->data.frame.sz, 1, pts, keyframe);
            
            
            if (!success) {
                die_codec(codec, "Failed to write compressed frame");
            }
            //            printf(keyframe ? "K" : ".");
            //            fflush(stdout);
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




void RGBA888ToYuv420p(uint8_t *yuvOut,uint8_t *alpha, uint8_t *rgba, size_t width, size_t height)
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
                uint8_t r = rgba[4 * i];
                uint8_t g = rgba[4 * i + 1];
                uint8_t b = rgba[4 * i + 2];
                uint8_t a = rgba[4 * i + 3];
                
                alpha[i]=a;
                yuvOut[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
                
                yuvOut[upos++] = ((-38*r + -74*g + 112*b) >> 8) + 128;
                yuvOut[vpos++] = ((112*r + -94*g + -18*b) >> 8) + 128;
                
                r = rgba[4 * i];
                g = rgba[4 * i + 1];
                b = rgba[4 * i + 2];
                a = rgba[4 * i + 3];
                
                alpha[i]=a;
                yuvOut[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
            }
        }
        else
        {
            for( size_t x = 0; x < width; x += 1 )
            {
                uint8_t r = rgba[4 * i];
                uint8_t g = rgba[4 * i + 1];
                uint8_t b = rgba[4 * i + 2];
                uint8_t a = rgba[4 * i + 3];
                
                alpha[i]=a;
                yuvOut[i++] = ((66*r + 129*g + 25*b) >> 8) + 16;
                
                
                
            }
        }
    }
}


@end
