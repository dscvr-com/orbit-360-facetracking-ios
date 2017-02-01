
//
//  Tracker.m
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 05.12.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "opencv2/video/tracking.hpp"
#include "Tracker.h"

using namespace cv;
using namespace std;

float transistionMat[] = {
     1, 0, 1, 0,
     0, 1, 0, 1,
     0, 0, 1, 0,
     0, 0, 0, 1
};

@interface Tracker() {
    KalmanFilter filter;
} @end

@implementation Tracker

-(id) init: (float)x :(float) y {
    self = [super init];
    filter = KalmanFilter(4, 2, 0);
    filter.transitionMatrix = Mat(4, 4, CV_32F, transistionMat);
    filter.statePre.at<float>(0) = x;
    filter.statePre.at<float>(1) = y;
    filter.statePre.at<float>(2) = 0;
    filter.statePre.at<float>(3) = 0;
    setIdentity(filter.measurementMatrix);
    setIdentity(filter.processNoiseCov, Scalar::all(1e-6));
    setIdentity(filter.measurementNoiseCov, Scalar::all(1e-1));
    setIdentity(filter.errorCovPost, Scalar::all(.1));
    return self;
};

-(TrackerState) predict {
    
    Mat estimate = filter.predict();

    TrackerState res;
    res.x = estimate.at<float>(0);
    res.y = estimate.at<float>(1);
    res.vx = estimate.at<float>(2);
    res.vy = estimate.at<float>(3);

    return res;
}

-(TrackerState) correct: (float)x :(float) y {
    Mat measurement(2, 1, CV_32F);
    measurement.at<float>(0) = x;
    measurement.at<float>(1) = y;
    
    Mat estimate = filter.correct(measurement);
    
    TrackerState res;
    res.x = estimate.at<float>(0);
    res.y = estimate.at<float>(1);
    res.vx = estimate.at<float>(2);
    res.vy = estimate.at<float>(3);
    
    return res;
}
@end

