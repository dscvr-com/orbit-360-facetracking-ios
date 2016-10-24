//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>
#include <CoreGraphics/CGGeometry.h>

@interface Alignment : NSObject
-(id)init;
-(CGRect)detectFaces;
@end