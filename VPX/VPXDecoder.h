//
//  VPXDecoder.h
//  VPX
//
//  Created by Morten Bertz on 7/15/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreMedia/CoreMedia.h>


@interface VPXDecoder : NSObject

-(nullable instancetype)initWithURL:(nonnull NSURL*)url;

-(nullable CMSampleBufferRef)nextFrame; 

-(void)close;



@end
