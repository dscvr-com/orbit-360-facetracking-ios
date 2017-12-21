//
//  IntExtension.swift
//  Orbit 360
//
//  Created by Philipp Meyer on 23.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation

public extension Int {
    func format(f: String) -> String {
        return String(format: "%\(f)d", self)
    }
}
