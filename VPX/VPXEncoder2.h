//
//  VPXEncoder2.h
//  VPX
//
//  Created by Morten Bertz on 7/18/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VPXEncoder2 : NSObject



@property BOOL preserveAlpha;

-(instancetype)initWithURL:(NSURL*)url framerate:(NSUInteger)rate size:(CGSize)size preserveAlpha:(BOOL)alpha;


-(void)addFrame:(CGImageRef)frame atTime:(NSTimeInterval)time;
-(void)finalizeWithCompletion:(void(^)(BOOL success))completion;



@end
