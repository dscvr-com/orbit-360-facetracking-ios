//
//  FaceDetect.mm
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 05.12.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>
#include "opencv2/objdetect.hpp"
#include "opencv2/imgproc.hpp"

#include "FaceDetection.h"
#include "AsyncStream.hpp"

using namespace std;
using namespace cv;

const NSString* filePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
//string face_cascade_name = "haarcascade_frontalface_alt.xml";
const char *face_cascade_name = [filePath UTF8String];

@interface FaceDetection() {
    std::function<NSMutableArray*(Mat)> fun; //(&Detect);
    AsyncStream<Mat, NSMutableArray*>* worker; //(fun, [NSMutableArray new]);
    CascadeClassifier face_cascade;
} @end

@implementation FaceDetection
-(id)init {
    self = [super init];
    fun = [self](Mat input) { return [self Detect: input]; };
    worker = new AsyncStream<Mat, NSMutableArray*>(fun, [NSMutableArray new]);
    face_cascade.load(face_cascade_name);
    return self;
};


-(NSMutableArray*)detectFaces:(void*)buffer: (UInt32) width: (UInt32) height {

    Mat frame_gray(height, width, CV_8UC1);
    cv::cvtColor(
                 cv::Mat(height, width, CV_8UC4, buffer),
                 frame_gray,
                 cv::COLOR_RGBA2GRAY);

    worker->Push(frame_gray);
    return worker->Result();
}

-(NSMutableArray*) Detect:(Mat) input {
    // detect faces, return rects
    std::vector<cv::Rect> faces;

    int scale = 1;
    while(input.cols > 240 && input.rows > 240) {
        pyrDown(input, input);
        scale *= 2;
    }

    equalizeHist(input, input);
    transpose(input, input);
    flip(input, input,1); //transpose+flip(1)=CW

    face_cascade.detectMultiScale( input, faces, 1.1, 2, 0|CASCADE_SCALE_IMAGE, cv::Size(30, 30) );

    NSMutableArray* array = [NSMutableArray new];
    if(faces.size() > 0) {
        for (int i = 0; i < faces.size(); i++) {

            [array addObject:[NSValue valueWithCGRect:CGRectMake(faces[i].x * scale, faces[i].y * scale, faces[i].width * scale, faces[i].height * scale)]];
        }
    }
    return array;
};

-(void) dealloc {
    delete worker;
}

@end
