//
//  SimplexNoise.swift
//  TerraGen
//
//  Created by Dominik Horn on 8/18/19.
//  Copyright © 2019 Dominik Horn. All rights reserved.
//

import Foundation
import simd

/**
 * Implementation of Simplex Noise generation
 *
 * Credit to: https://gist.github.com/KdotJPG/b1270127455a94ac5d19
 */
class SimplexNoise {
    private let stretchConstant2D: Double = -0.211324865405187 // (1.0 / sqrt(2.0 + 1.0) - 1.0) / 2.0
    private let squishConstant2D: Double = 0.366025403784439 // (sqrt(2.0 + 1.0) - 1.0) / 2.0
    private let normConstant2D: Double = 41.0
    /*Gradients for 2D. They approximate the directions to vertices of an octagon from the center */
    private let gradients2D: [Double] = [
        5,  2,    2,  5,
        -5,  2,   -2,  5,
        5, -2,    2, -5,
        -5, -2,   -2, -5,
    ];
    
    
    // Permutation lookup table (used for pseudo random gradient assignment)
    var perm: [Int]
    init(seed: UInt64 = 1) {
        perm = []
        var generator = SeededGenerator(seed: seed)
        for i in 0..<256 {
            perm.append(i)
        }
        perm.shuffle(using: &generator)
    }
    
    private func extrapolate2D(x0 xsb: Int, y0 ysb: Int, x1 dx: Double, y1 dy: Double) -> Double {
        let index: Int = perm[(perm[xsb & 0xFF] + ysb) & 0xFF] & 0x0E
        return gradients2D[index] * dx + gradients2D[index + 1] * dy
    }
    
    private func fastFloor(_ val: Double) -> Int {
        let int = Int(val)
        return val < Double(int) ? int - 1 : int
    }
    
    /**
     Calculates 2D Simplex noise at given coordinates x and y
     
     - Parameter x: horizontal position
     - Parameter y: vertical position
    */
    public func noise2D(x xin: Double, y yin: Double, featureSize: Double = 100.0) -> Double {
        let x: Double = xin / featureSize
        let y: Double = yin / featureSize
        
        // Translate input coordinates to grid
        let stretchOffset: Double = (x + y) * stretchConstant2D
        let xs: Double = x + stretchOffset
        let ys: Double = y + stretchOffset
        
        // Floor to get grid coordinates of rhombus super-cell origin
        var xsb: Int = fastFloor(xs)
        var ysb: Int = fastFloor(ys)
        
        // Skew out to get actual coordinates of rhombus origin
        let squishOffset: Double = Double(xsb + ysb) * squishConstant2D
        let xb: Double = Double(xsb) + squishOffset
        let yb: Double = Double(ysb) + squishOffset
        
        // Grid coordinates relative to rhombys
        let xins: Double = xs - Double(xsb)
        let yins: Double = ys - Double(ysb)
        
        // Simplex region
        let inSum: Double = xins + yins
        
        // Relative to origin
        var dx0: Double = x - xb;
        var dy0: Double = y - yb;
        
        var value: Double = 0.0

        
        // Contribution (1,0)
        let dx1: Double = dx0 - 1.0 - squishConstant2D
        let dy1: Double = dy0 - 0.0 - squishConstant2D
        var attn1: Double = 2.0 - dx1 * dx1 - dy1 * dy1
        if (attn1 > 0) {
            attn1 *= attn1
            value += attn1 * attn1 * extrapolate2D(
                x0: xsb + 1,
                y0: ysb + 0,
                x1: dx1,
                y1: dy1)
        }
        
        // Contribution (0,1)
        let dx2: Double = dx0 - 0 - squishConstant2D
        let dy2: Double = dy0 - 1 - squishConstant2D
        var attn2: Double = 2 - dx2 * dx2 - dy2 * dy2
        if (attn2 > 0) {
            attn2 *= attn2
            value += attn2 * attn2 * extrapolate2D(
                x0: xsb + 0,
                y0: ysb + 1,
                x1: dx2,
                y1: dy2
            )
        }
        
        var dx_ext: Double
        var dy_ext: Double
        var xsv_ext: Int
        var ysv_ext: Int
        if (inSum <= 1) {
            // Inside simplex at (0,0)
            let zins = 1 - inSum
            if (zins > xins || zins > yins) {
                // (0,0) one of the closest two simplex vertices
                if (xins > yins) {
                    xsv_ext = xsb + 1
                    ysv_ext = ysb - 1
                    dx_ext = dx0 - 1
                    dy_ext = dy0 + 1
                } else {
                    xsv_ext = xsb - 1
                    ysv_ext = ysb + 1
                    dx_ext = dx0 + 1
                    dy_ext = dy0 - 1
                }
            } else {
                // (1, 0) and (0, 1) are closest two vertices
                xsv_ext = xsb + 1
                ysv_ext = ysb + 1
                dx_ext = dx0 - 1 - 2 * squishConstant2D
                dy_ext = dy0 - 1 - 2 * squishConstant2D
            }
        } else {
            // inside simplex at (1,1)
            let zins = 2 - inSum
            if (zins < xins || zins < yins) {
                // (0,0) one of the closest two simplex vertices
                if (xins > yins) {
                    xsv_ext = xsb + 2
                    ysv_ext = ysb + 0
                    dx_ext = dx0 - 2 - 2 * squishConstant2D
                    dy_ext = dy0 + 0 - 2 * squishConstant2D
                } else {
                    xsv_ext = xsb + 0
                    ysv_ext = ysb + 2
                    dx_ext = dx0 + 0 - 2 * squishConstant2D
                    dy_ext = dy0 - 2 - 2 * squishConstant2D
                }
            } else {
                // (1,0) and (0,1) are closest two vertices
                xsv_ext = xsb
                ysv_ext = ysb
                dx_ext = dx0
                dy_ext = dy0
            }
            xsb += 1
            ysb += 1
            dx0 = dx0 - 1 - 2 * squishConstant2D
            dy0 = dy0 - 1 - 2 * squishConstant2D
        }
        
        // Contribution (0,0) or (1,1)
        var attn0: Double = 2 - dx0 * dx0 - dy0 * dy0
        if (attn0 > 0) {
            attn0 *= attn0
            value += attn0 * attn0 * extrapolate2D(x0: xsb, y0: ysb, x1: dx0, y1: dy0)
        }
        
        // Extra vertex
        var attn_ext: Double = 2 - dx_ext * dx_ext - dy_ext * dy_ext
        if (attn_ext > 0) {
            attn_ext *= attn_ext
            value += attn_ext * attn_ext * extrapolate2D(x0: xsv_ext, y0: ysv_ext, x1: dx_ext, y1: dy_ext)
        }
        
        return value / normConstant2D
    }
}
