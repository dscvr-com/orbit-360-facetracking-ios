//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>
#include <CoreGraphics/CGGeometry.h>

@interface FaceDetection : NSObject
-(id)init;
-(NSMutableArray*)detectFaces:(void*)buffer: (UInt32) width: (UInt32) height;
@end
