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
#include "AsyncStream.hpp"
//#include <iostream>

using namespace std;
using namespace cv;

NSString* filePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
//string face_cascade_name = "haarcascade_frontalface_alt.xml";
const char *face_cascade_name = [filePath UTF8String];
CascadeClassifier face_cascade;

CGRect Detect(Mat input) {
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

    CGRect rectangle = CGRectMake(0,0,0,0);
    if(faces.size() > 0) {
        rectangle = CGRectMake(faces[0].x * scale, faces[0].y * scale, faces[0].width * scale, faces[0].height * scale);
    }
    return rectangle;

};

auto fun = std::function<CGRect(Mat)>(&Detect);
AsyncStream<Mat, CGRect> worker(fun);

@implementation FaceDetection

-(id)init {
    self = [super init];
    face_cascade.load(face_cascade_name);
    return self;
};


-(CGRect)detectFaces:(void*)buffer: (UInt32) width: (UInt32) height {

    Mat frame_gray(height, width, CV_8UC1);
    cv::cvtColor(
                 cv::Mat(height, width, CV_8UC4, buffer),
                 frame_gray,
                 cv::COLOR_RGBA2GRAY);

    worker.Push(frame_gray);
    return worker.Result();
}

@end





