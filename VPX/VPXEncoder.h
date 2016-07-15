//
//  VPXEncoder.h
//  VPX
//
//  Created by Morten Bertz on 7/13/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VPXEncoder : NSObject
-(instancetype)initWithURL:(NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size;
-(void)addFrame:(CGImageRef)frame atTime:(NSTimeInterval)time;
-(void)finalizeWithCompletion:(void(^)(BOOL success))completion;
@end
