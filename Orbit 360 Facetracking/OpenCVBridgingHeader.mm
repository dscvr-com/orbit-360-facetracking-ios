//
//  OpenCVBridgingHeader.m
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 24.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <string>
#include "opencv2/objdetect.hpp"
#include "opencv2/imgproc.hpp"
#include "Orbit 360 Facetracking-Bridging-Header.h"

using namespace std;
using namespace cv;

string face_cascade_name = "haarcascade_frontalface_alt.xml";
CascadeClassifier face_cascade;

//CGRect detectFaces () {
//    
//    
//    return
//}