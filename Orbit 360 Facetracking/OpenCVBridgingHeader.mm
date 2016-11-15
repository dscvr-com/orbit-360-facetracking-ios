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
//#include <iostream>

using namespace std;
using namespace cv;

NSString* filePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
//string face_cascade_name = "haarcascade_frontalface_alt.xml";
const char *face_cascade_name = [filePath UTF8String];
CascadeClassifier face_cascade;

@implementation FaceDetection

-(id)init {
    self = [super init];
    face_cascade.load(face_cascade_name);
    return self;
};

-(CGRect)detectFaces:(void*)buffer: (UInt32) width: (UInt32) height {
    
    std::vector<cv::Rect> faces;
    
    Mat frame_gray(height, width, CV_8UC1);
    //loadTimer.Tick("## Allocate Mat");
    cv::cvtColor(
                 cv::Mat(height, width, CV_8UC4, buffer),
                 frame_gray,
                 cv::COLOR_RGBA2GRAY);

    int scale = 1;

    while(frame_gray.cols > 240 && frame_gray.rows > 240) {
        pyrDown(frame_gray, frame_gray);
        scale *= 2;
    }

    equalizeHist(frame_gray, frame_gray);

    transpose(frame_gray, frame_gray);
    flip(frame_gray, frame_gray,1); //transpose+flip(1)=CW
    
    //-- Detect faces
    face_cascade.detectMultiScale( frame_gray, faces, 1.1, 2, 0|CASCADE_SCALE_IMAGE, cv::Size(30, 30) );
    //cout << faces[0].width << " " << faces[0].height <<endl;
    // return first rect in "faces"
    
    CGRect rectangle = CGRectMake(0,0,0,0);
    if(faces.size() > 0) {
        rectangle = CGRectMake(faces[0].x * scale, faces[0].y * scale, faces[0].width * scale, faces[0].height * scale);
    }
    return rectangle;
}

@end





