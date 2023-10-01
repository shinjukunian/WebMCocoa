//
//  VPXEncoder2.h
//  VPX
//
//  Created by Morten Bertz on 7/18/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSUInteger, VPXEncoderType){
    VPXEncoderTypeVP8,
    VPXEncoderTypeVP9,
};


@interface VPXEncoder2 : NSObject

@property BOOL preserveAlpha;
@property (nullable) CGColorRef backgroundColor;
@property VPXEncoderType encoderType;

+(nonnull NSString*)version;

-(nonnull instancetype)initWithURL:(nonnull NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha;
-(nonnull instancetype)initWithURL:(nonnull NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha encoder:(VPXEncoderType)encoder;

-(void)addFrame:(nonnull CGImageRef)frame atTime:(NSTimeInterval)time;
-(void)finalizeWithCompletion:(void(^_Nonnull)(BOOL success))completion;



@end
