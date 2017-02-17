//
//  Control.swift
//  Orbit 360 Facetracking
//
//  Created by Emi on 17/02/2017.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation

protocol Control {
    associatedtype State: SummableMultipliableFloat
    func push(input: State) -> State
}

struct PControl<T where T: SummableMultipliableFloat> : Control {
    let p: Float
    
    init(p: Float) {
        self.p = p
    }
    
    func push(input: T) -> T {
        return input * p
    }
}
