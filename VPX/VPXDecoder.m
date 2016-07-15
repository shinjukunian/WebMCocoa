//
//  VPXDecoder.m
//  VPX
//
//  Created by Morten Bertz on 7/15/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "VPXDecoder.h"
#include "vpx/vpx_decoder.h"

#include "tools_common.h"
#include "video_reader.h"
#include "vpx_config.h"



@implementation VPXDecoder{
    VpxVideoReader *_reader;
    const VpxInterface *_decoder;
    vpx_codec_ctx_t _codec;
    NSMutableArray *_bufferArray;
    CMTime _currentTime;
    const VpxVideoInfo *_info;
    CMTime _frameRate;

}


-(nullable instancetype)initWithURL:(nonnull NSURL*)url{
    self=[super init];
    if (self) {
        _reader=vpx_video_reader_open(url.fileSystemRepresentation);
        if (_reader==NULL) {
            return nil;
        }
        _bufferArray=[NSMutableArray new];
        _currentTime=kCMTimeZero;
        
       _info=vpx_video_reader_get_info(_reader);
        _decoder = get_vpx_decoder_by_fourcc(_info->codec_fourcc);
        _frameRate=CMTimeMake(_info->time_base.denominator, _info->time_base.numerator);
        
        if (vpx_codec_dec_init(&_codec, _decoder->codec_interface(), NULL, 0)){
            die_codec(&_codec, "Failed to initialize decoder.");
        }
//        int i=0;
//        printf("Using %s\n", vpx_codec_iface_name(_decoder->codec_interface()));
//        while (vpx_video_reader_read_frame(_reader)) {
//            vpx_codec_iter_t iter = NULL;
//            vpx_image_t *img = NULL;
//            size_t frame_size = 0;
//            
//            const unsigned char *frame = vpx_video_reader_get_frame(_reader,
//                                                                    &frame_size);
//            if (vpx_codec_decode(&_codec, frame, (unsigned int)frame_size, NULL, 0))
//                die_codec(&_codec, "Failed to decode frame.");
//            
//            while ((img = vpx_codec_get_frame(&_codec, &iter)) != NULL) {
//                i++;
//                NSLog(@"decoding %i",i);
//            }
//        }
    }
    return self;
}

-(CMSampleBufferRef)nextFrame{
    if (_bufferArray.count>0) {
        CMSampleBufferRef frame=(__bridge CMSampleBufferRef)(_bufferArray.firstObject);
        [_bufferArray removeObjectAtIndex:0];
        return frame;
    }
    else{
        vpx_video_reader_read_frame(_reader);
        vpx_codec_iter_t iter = NULL;
        vpx_image_t *img = NULL;
        size_t frame_size = 0;
        const unsigned char *frame = vpx_video_reader_get_frame(_reader,
                                                                &frame_size);
        if (vpx_codec_decode(&_codec, frame, (unsigned int)frame_size, NULL, 0))
            die_codec(&_codec, "Failed to decode frame.");
        
        while ((img = vpx_codec_get_frame(&_codec, &iter)) != NULL) {
            CMSampleBufferRef CMframe=[self sampleBufferFromImage:img];
            if (CMframe){
                [_bufferArray addObject:(__bridge id _Nonnull)(CMframe)];
            }
        }
        if (_bufferArray.count>0) {
            CMSampleBufferRef CMframe=(__bridge CMSampleBufferRef)(_bufferArray.firstObject);
            [_bufferArray removeObjectAtIndex:0];
            return CMframe;

        }
    }
    
    return nil;
}


-(CMSampleBufferRef)sampleBufferFromImage:(vpx_image_t*)image{
    CVPixelBufferRef pixelBuffer;
    void *planes[3]={image->planes[VPX_PLANE_Y],image->planes[VPX_PLANE_U],image->planes[VPX_PLANE_V]};
    size_t storageWidth=image->w;
    size_t storageHeight=image->h;
    size_t widths[3]={storageWidth,storageWidth/2,storageWidth/2};
    size_t heights[3]={storageHeight,storageHeight/2,storageHeight/2};
    size_t bytesPerRow[3]={image->stride[VPX_PLANE_Y],image->stride[VPX_PLANE_U],image->stride[VPX_PLANE_V]};
    NSDictionary *options=@{(NSString*)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8Planar)};
    
    CVReturn retVal=CVPixelBufferCreateWithPlanarBytes(NULL, image->w, image->h, kCVPixelFormatType_420YpCbCr8Planar, NULL, 0, 3, planes, widths, heights, bytesPerRow, pixelBufferReleaseCallBack, image, (__bridge CFDictionaryRef _Nullable)(options), &pixelBuffer);
    
    CMSampleBufferRef sample;
    CMVideoFormatDescriptionRef desc;
    CMVideoCodecType codecType=CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    OSStatus formatStauts=CMVideoFormatDescriptionCreate(kCFAllocatorDefault, codecType, (int)storageWidth, (int)storageHeight, (__bridge CFDictionaryRef _Nullable)(@{}), &desc);
    CMSampleTimingInfo timing;
    timing.duration=_frameRate;
    timing.decodeTimeStamp=kCMTimeInvalid;
    timing.presentationTimeStamp=_currentTime;
    _currentTime=CMTimeAdd(timing.presentationTimeStamp, timing.duration);
    OSStatus status=CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, YES, NULL, NULL, desc, &timing, &sample);
    

    return sample;
    
}

void pixelBufferReleaseCallBack (void *releaseRefCon, const void *dataPtr, size_t dataSize, size_t numberOfPlanes, const void * _Nullable planeAddresses[]){
    
}




-(void)close{
    vpx_codec_destroy(&(_codec));
    vpx_video_reader_close(_reader);
    [_bufferArray removeAllObjects];
    
}









@end
