//
//  SeededGenerator.swift
//  TerraGen
//
//  Created by Dominik Horn on 8/18/19.
//  Copyright © 2019 Dominik Horn. All rights reserved.
//

import GameplayKit

// Credit to RPatel99 https://stackoverflow.com/questions/54821659/swift-4-2-seeding-a-random-number-generator
class SeededGenerator: RandomNumberGenerator {
    let seed: UInt64
    private let generator: GKMersenneTwisterRandomSource
    
    convenience init() {
        self.init(seed: 0)
    }
    
    init(seed: UInt64) {
        self.seed = seed
        generator = GKMersenneTwisterRandomSource(seed: seed)
    }
    
    func next<T>(upperBound: T) -> T where T : FixedWidthInteger, T : UnsignedInteger {
        return T(abs(generator.nextInt(upperBound: Int(upperBound))))
    }
    
    func next<T>() -> T where T : FixedWidthInteger, T : UnsignedInteger {
        return T(abs(generator.nextInt()))
    }
}
