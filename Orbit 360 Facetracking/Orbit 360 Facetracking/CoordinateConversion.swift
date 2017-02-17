//
//  CameraToMotorSpace.swift
//  Orbit 360 Facetracking
//
//  Created by Emi on 17/02/2017.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation

protocol CoordinateConversion {
    func convert(p: Point) -> Point
}

class IdentityCoordinateConversion : CoordinateConversion {
    func convert(p: Point) -> Point {
        return p
    }
}

class CameraToUnitSpaceCoordinateConversion : CoordinateConversion {
    let cameraWidth: Float
    let cameraHeight: Float
    let aspect: Float
    
    init(cameraWidth: Float, cameraHeight: Float, aspect: Float) {
        self.cameraWidth = cameraWidth
        self.cameraHeight = cameraHeight
        self.aspect = aspect
    }
    
    func convert(camera: Point) -> Point {
        return Point(x: camera.x / cameraWidth - 0.5,
                     y: ((camera.y / cameraHeight) - 0.5) * aspect)
    }
}

class UnitToMotorSpaceCoordinateConversion : CoordinateConversion {
    let unitFocalLength: Float
    
    init(unitFocalLength: Float) {
        self.unitFocalLength = unitFocalLength
    }
    
    func convert(unit: Point) -> Point {
        return Point(x: atan2(unit.x, unitFocalLength),
                     y: atan2(unit.y, unitFocalLength))
    }
}


class MotorSpaceToStepsConversion  : CoordinateConversion {
    let fullStepsX: Float
    let fullStepsY: Float
    
    init(fullStepsX: Float, fullStepsY: Float) {
        self.fullStepsX = fullStepsX
        self.fullStepsY = fullStepsY
    }
    
    func convert(rads: Point) -> Point {
        let unit = rads / Float(2.0 * M_PI)
        return Point(x: unit.x * fullStepsX,
                     y: unit.y * fullStepsY)
    }
}
