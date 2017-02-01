//
//  Tracker.h
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 05.12.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

#ifndef Tracker_h
#define Tracker_h

struct TrackerState {
    float x;
    float y;
    float vx;
    float vy;
};

@interface Tracker : NSObject
    - (id) init: (float)x :(float) y;
    - (struct TrackerState) predict: (float)cx :(float) cy: (float)dt;
    - (struct TrackerState) correct: (float)x :(float) y: (float)dt;
@end

#endif /* Tracker_h */
