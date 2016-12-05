//
//  FaceDetect.h
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 05.12.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

#ifndef FaceDetect_h
#define FaceDetect_h

#import <Foundation/Foundation.h>
#include <CoreGraphics/CGGeometry.h>

@interface FaceDetection : NSObject
-(id)init;
-(NSMutableArray*)detectFaces:(void*)buffer: (UInt32) width: (UInt32) height;
@end


#endif /* FaceDetect_h */
