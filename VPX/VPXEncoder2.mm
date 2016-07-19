//
//  VPXEncoder2.m
//  VPX
//
//  Created by Morten Bertz on 7/18/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "VPXEncoder2.h"
#import <Accelerate/Accelerate.h>

#include "mkvparser.hpp"
#include "mkvreader.hpp"

#include "mkvmuxer.hpp"
#include "mkvmuxerutil.hpp"
#include "mkvwriter.hpp"

#include "vpx/vpx_encoder.h"
#include "./tools_common.h"
#include "video_writer.h"

static const char *exec_name;

@implementation VPXEncoder2{
    
    vpx_codec_ctx_t codec;
    vpx_codec_ctx_t codec_alpha;
    VpxVideoWriter *writer;

    int frame_count;
    int keyframe_interval;
    
    NSURL *tempVideo;
    NSURL *tempAlpha;
    NSURL *outURL;
    
    mkvmuxer::MkvWriter mkvWriter;
    mkvmuxer::Segment _muxer_segment;
    
}





-(instancetype)initWithURL:(NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha{
    self=[super init];
    if (self) {
        
        outURL=url;
        self.preserveAlpha=alpha;
        tempVideo=[[NSURL fileURLWithPath:NSTemporaryDirectory()]URLByAppendingPathComponent:@"video.out"];
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
        
        
        if (self.preserveAlpha) {
//            tempAlpha=[[NSURL fileURLWithPath:NSTemporaryDirectory()]URLByAppendingPathComponent:@"alpha.out"];


           
            if (!mkvWriter.Open(outURL.fileSystemRepresentation)) {
                fprintf(stderr, "\n Error while opening output file.\n");
                
            }
            if (!_muxer_segment.Init(&mkvWriter)) {
                fprintf(stderr, "\n Could not initialize muxer segment!\n");
                
            }
            uint64_t vid_track= _muxer_segment.AddVideoTrack(size.width, size.height, 1);
            mkvmuxer::VideoTrack* const video =
            static_cast<mkvmuxer::VideoTrack*>(
                                               _muxer_segment.GetTrackByNumber(vid_track));
            if (!video) {
                fprintf(stderr, "\n Could not get video track.\n");
                
            }
            video->set_codec_id(mkvmuxer::Tracks::kVp8CodecId);
            video->SetAlphaMode(1);
            video->set_max_block_additional_id(1);
            if (vpx_codec_enc_init(&codec, encoder->codec_interface(), &cfg, 0)){
                die_codec(&codec, "Failed to initialize encoder");
            }
            if (vpx_codec_enc_init(&codec_alpha, encoder->codec_interface(), &cfg, 0)){
                die_codec(&codec, "Failed to initialize encoder");
            }
            
        }
        else{
            writer = vpx_video_writer_open(tempVideo.fileSystemRepresentation, kContainerIVF, &info);
            if (vpx_codec_enc_init(&codec, encoder->codec_interface(), &cfg, 0)){
                die_codec(&codec, "Failed to initialize encoder");
            }
        }
        
        
        

        
        
    }
    return self;
}


-(void)addFrame:(CGImageRef)frame atTime:(NSTimeInterval)time{
    
    unsigned int maxDimension=(unsigned int)MAX(CGImageGetWidth(frame), CGImageGetHeight(frame));
    
    unsigned int v=maxDimension; // compute the next highest power of 2 of 32-bit v http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2Float
    
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    
    if (self.preserveAlpha) {
        
        uint8_t *resizedBuffer=(uint8_t*)calloc(v*v*4, 1);
        
        CGContextRef context=CGBitmapContextCreate(resizedBuffer, v, v, CGImageGetBitsPerComponent(frame), v*4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
//        CGContextSetRGBFillColor(context, 1, 0, 0, 0.5);
//        CGContextFillRect(context, CGRectMake(0, 0, v, v));
        
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(frame), CGImageGetHeight(frame)), frame);
        
        uint8_t *YUV=(uint8_t*)calloc(v*v*2, 1);
        uint8_t *alpha=(uint8_t*)calloc(v*v*2, 1);
        RGBA888ToYuv420p(YUV, alpha, resizedBuffer, v, v);
        vpx_image_t *image=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, v, v, v, YUV);
        vpx_image_t *image_alpha=vpx_img_wrap(NULL, VPX_IMG_FMT_I420, v, v, v, alpha);
        vpx_img_set_rect(image, 0, v-(unsigned int)CGImageGetHeight(frame), (unsigned int)CGImageGetWidth(frame), (unsigned int)CGImageGetHeight(frame));
         vpx_img_set_rect(image_alpha, 0, v-(unsigned int)CGImageGetHeight(frame), (unsigned int)CGImageGetWidth(frame), (unsigned int)CGImageGetHeight(frame));
        
        int flags = 0;
        if (keyframe_interval > 0 && frame_count % keyframe_interval == 0){
            flags |= VPX_EFLAG_FORCE_KF;
        }
        
        encode_frameAlpha(&codec, image, &codec_alpha, image_alpha, frame_count++, flags, &(_muxer_segment));
        
       
        vpx_img_free(image);
        
       
        vpx_img_free(image_alpha);
        free(resizedBuffer);
        free(YUV);
        free(alpha);
        CGContextRelease(context);
    }
    else{
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
        
        vImage_Buffer dest;
        err= vImageBuffer_Init(&dest, CGImageGetHeight(resized), CGImageGetWidth(resized), 24, kvImagePrintDiagnosticsToConsole);
        if (err!=kvImageNoError) {
            NSLog(@"conversion generation error %zd",err);
        }
        Pixel_8888 bg={255,255,255,255};
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
        encode_frame2(&codec, image, frame_count++, flags, writer);
        vpx_img_free(image);
        free(YUV);

    }
}







-(void)finalizeWithCompletion:(void(^)(BOOL success))completion{
    
    
    
    
    while (encode_frame2(&codec, NULL, -1, 0, writer)) {};
    //    vpx_img_free(&raw);
    if (vpx_codec_destroy(&codec))
        die_codec(&codec, "Failed to destroy codec.");
    vpx_video_writer_close(writer);
    
    
    if (self.preserveAlpha) {
        if (!_muxer_segment.Finalize())
            fprintf(stderr, "Finalization of segment failed.\n");
        mkvWriter.Close();

    }
    else{
        NSError *error;
        if (![[NSFileManager defaultManager]moveItemAtURL:tempVideo toURL:outURL error:&error]){
            NSLog(@"%@",error);
        }
    }
    
    completion(YES);
    
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



static int encode_frameAlpha(vpx_codec_ctx_t *codec,
                             vpx_image_t *img,
                             vpx_codec_ctx_t *codec_alpha,
                             vpx_image_t *img_alpha,
                             int frame_index,
                             int flags,
                             mkvmuxer::Segment *segment) {

    int got_pkts = 0;
    vpx_codec_iter_t iter = NULL;
    vpx_codec_iter_t iter_alpha = NULL;
    const vpx_codec_cx_pkt_t *pkt = NULL;
    const vpx_codec_cx_pkt_t *pkt_alpha = NULL;
     vpx_codec_err_t res = vpx_codec_encode(codec, img, frame_index, 1,
                                                 flags, VPX_DL_GOOD_QUALITY);
    if (res != VPX_CODEC_OK)
        die_codec(codec, "Failed to encode frame");
    res = vpx_codec_encode(codec_alpha, img_alpha, frame_index, 1,
                                                 flags, VPX_DL_GOOD_QUALITY);
    
    if (res != VPX_CODEC_OK)
        die_codec(codec, "Failed to encode frame");
    
    while ((pkt = vpx_codec_get_cx_data(codec, &iter)) != NULL && (pkt_alpha = vpx_codec_get_cx_data(codec_alpha, &iter_alpha))) {
        got_pkts = 1;
        
        if (pkt->kind == VPX_CODEC_CX_FRAME_PKT) {
            
            
           BOOL success= segment->AddFrameWithAdditional((const uint8_t*)pkt->data.frame.buf,
                                                  pkt->data.frame.sz,
                                                  (const uint8_t*)pkt_alpha->data.frame.buf,
                                                  pkt_alpha->data.frame.sz,
                                                  1, 1,
                                                  pkt->data.frame.pts*1e8,
            NO);
            
           
            if (!success) {
                die_codec(codec, "Failed to write compressed frame");
            }
            //            printf(keyframe ? "K" : ".");
            //            fflush(stdout);
        }
    }
    
    return got_pkts;

}



static int encode_frame2(vpx_codec_ctx_t *codec,
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
            
            
            int success = vpx_video_writer_write_frame(writer, (const uint8_t*)pkt->data.frame.buf,pkt->data.frame.sz,pkt->data.frame.pts);
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




//bool Cleanup(mkvmuxer::MkvWriter* writer,
//             mkvparser::MkvReader* reader,
//             mkvparser::MkvReader* reader_alpha,
//             mkvmuxer::Segment* muxer_segment,
//             mkvparser::Segment** parser_segment,
//             mkvparser::Segment** parser_segment_alpha) {
//    if (!muxer_segment->Finalize())
//        fprintf(stderr, "Finalization of segment failed.\n");
//    delete *parser_segment;
//    delete *parser_segment_alpha;
//    writer->Close();
//    reader->Close();
//    reader_alpha->Close();
//    if (remove("video.in") || remove("video.out") ||
//        remove("alpha.in") || remove("alpha.out")) {
//        fprintf(stderr, "\n Error while removing temp files.\n");
//        return false;
//    }
//    return true;
//}
//
//
//bool WriteTrack(mkvparser::MkvReader* reader,
//                mkvparser::MkvReader* reader_alpha,
//                mkvmuxer::Segment* muxer_segment,
//                mkvparser::Segment** parser_segment,
//                mkvparser::Segment** parser_segment_alpha,
//                std::string codec) {
//    long long pos = 0;
//    mkvparser::EBMLHeader ebml_header;
//    ebml_header.Parse(reader, pos);
//    long long pos_alpha = 0;
//    mkvparser::EBMLHeader ebml_header_alpha;
//    ebml_header_alpha.Parse(reader_alpha, pos_alpha);
//    long long ret = mkvparser::Segment::CreateInstance(reader,
//                                                       pos,
//                                                       *parser_segment);
//    if (ret) {
//        fprintf(stderr, "\n Segment::CreateInstance() failed.");
//        return false;
//    }
//    ret = mkvparser::Segment::CreateInstance(reader_alpha,
//                                             pos_alpha,
//                                             *parser_segment_alpha);
//    if (ret) {
//        fprintf(stderr, "\n Segment::CreateInstance() failed.");
//        return false;
//    }
//    ret = (*parser_segment)->Load();
//    if (ret < 0) {
//        fprintf(stderr, "\n Segment::Load() failed.");
//        return false;
//    }
//    ret = (*parser_segment_alpha)->Load();
//    if (ret < 0) {
//        fprintf(stderr, "\n Segment::Load() failed.");
//        return false;
//    }
//    const mkvparser::SegmentInfo* const segment_info =
//    (*parser_segment)->GetInfo();
//    const long long timeCodeScale = segment_info->GetTimeCodeScale();
//    muxer_segment->set_mode(mkvmuxer::Segment::kFile);
//    mkvmuxer::SegmentInfo* const info = muxer_segment->GetSegmentInfo();
//    info->set_timecode_scale(timeCodeScale);
//    info->set_writing_app("alpha_encoder");
//    const mkvparser::Tracks* const parser_tracks = (*parser_segment)->GetTracks();
//    uint64 vid_track = 0;  // no track added
//    const mkvparser::Track* const parser_track =
//    parser_tracks->GetTrackByIndex(0);
//    if (!parser_track)
//        return false;
//    const mkvparser::VideoTrack* const pVideoTrack =
//    static_cast<const mkvparser::VideoTrack*>(parser_track);
//    const char* const track_name = pVideoTrack->GetNameAsUTF8();
//    const long long width =  pVideoTrack->GetWidth();
//    const long long height = pVideoTrack->GetHeight();
//    // Add the video track to the muxer
//    vid_track = muxer_segment->AddVideoTrack(static_cast<int>(width),
//                                             static_cast<int>(height),
//                                             1);
//    if (!vid_track) {
//        fprintf(stderr, "\n Could not add video track.\n");
//        return false;
//    }
//    mkvmuxer::VideoTrack* const video =
//    static_cast<mkvmuxer::VideoTrack*>(
//                                       muxer_segment->GetTrackByNumber(vid_track));
//    if (!video) {
//        fprintf(stderr, "\n Could not get video track.\n");
//        return false;
//    }
//    video->set_codec_id((codec == "vp9") ?
//                        mkvmuxer::Tracks::kVp9CodecId : mkvmuxer::Tracks::kVp8CodecId);
//    if (track_name)
//        video->set_name(track_name);
//    video->SetAlphaMode(1);
//    video->set_max_block_additional_id(1);
//    return true;
//}
//
//
//
//
//bool WriteClusters(mkvparser::MkvReader* reader,
//                   mkvparser::MkvReader* reader_alpha,
//                   mkvmuxer::Segment* muxer_segment,
//                   mkvparser::Segment* parser_segment,
//                   mkvparser::Segment* parser_segment_alpha) {
//    uint8* data = NULL;
//    int data_len = 0;
//    uint8* additional = NULL;
//    int additional_len = 0;
//    const mkvparser::Cluster* cluster = parser_segment->GetFirst();
//    const mkvparser::Cluster* cluster_alpha = parser_segment_alpha->GetFirst();
//    while (cluster != NULL && !cluster->EOS() &&
//           cluster_alpha != NULL && !cluster_alpha->EOS()) {
//        const mkvparser::BlockEntry* block_entry;
//        long status = cluster->GetFirst(block_entry);
//        if (status) {
//            fprintf(stderr, "\n Could not get first block of cluster.\n");
//            return false;
//        }
//        const mkvparser::BlockEntry* block_entry_alpha;
//        status = cluster_alpha->GetFirst(block_entry_alpha);
//        if (status) {
//            fprintf(stderr, "\n Could not get first block of cluster.\n");
//            return false;
//        }
//        while (block_entry != NULL && !block_entry->EOS() &&
//               block_entry_alpha != NULL && !block_entry_alpha->EOS()) {
//            const mkvparser::Block* const block = block_entry->GetBlock();
//            const mkvparser::Block* const block_alpha =
//            block_entry_alpha->GetBlock();
//            const long long time_ns = block->GetTime(cluster);
//            const int frame_count = block->GetFrameCount();
//            const bool is_key = block->IsKey();
//            for (int i = 0; i < frame_count; ++i) {
//                // TODO(vigneshv): Handle altref frames
//                const mkvparser::Block::Frame& frame = block->GetFrame(i);
//                const mkvparser::Block::Frame& frame_alpha = block_alpha->GetFrame(i);
//                if (frame.len > data_len) {
//                    data = static_cast<uint8*>(realloc(data, sizeof(uint8) * frame.len));
//                    if (!data)
//                        return false;
//                    data_len = frame.len;
//                }
//                if (frame_alpha.len > additional_len) {
//                    additional = static_cast<uint8*>(
//                                                     realloc(additional, sizeof(uint8) * frame_alpha.len));
//                    if (!additional)
//                        return false;
//                    additional_len = frame_alpha.len;
//                }
//                if (frame.Read(reader, data))
//                    return false;
//                if (frame_alpha.Read(reader_alpha, additional))
//                    return false;
//                if (!muxer_segment->AddFrameWithAdditional(data,
//                                                           frame.len,
//                                                           additional,
//                                                           frame_alpha.len,
//                                                           1, 1,
//                                                           time_ns,
//                                                           is_key)) {
//                    fprintf(stderr, "\n Could not add frame.\n");
//                    return false;
//                }
//            }
//            status = cluster->GetNext(block_entry, block_entry);
//            if (status) {
//                fprintf(stderr, "\n Could not get next block of cluster.\n");
//                return false;
//            }
//            status = cluster_alpha->GetNext(block_entry_alpha, block_entry_alpha);
//            if (status) {
//                fprintf(stderr, "\n Could not get next block of cluster.\n");
//                return false;
//            }
//        }
//        cluster = parser_segment->GetNext(cluster);
//        cluster_alpha = parser_segment_alpha->GetNext(cluster_alpha);
//    }
//    free(data);
//    free(additional);
//    return true;
//}









@end
