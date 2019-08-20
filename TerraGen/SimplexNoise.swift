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
 * Transpiled reference implementation, i.e.,
 * credit to: https://gist.github.com/KdotJPG/b1270127455a94ac5d19
 */
class SimplexNoise {
    private let stretchConstant2D: Double = -0.211324865405187 // (1.0 / sqrt(2.0 + 1.0) - 1.0) / 2.0
    private let squishConstant2D: Double = 0.366025403784439 // (sqrt(2.0 + 1.0) - 1.0) / 2.0
    private let normConstant2D: Double = 41.0
    /* Gradients for 2D. They approximate the directions to vertices of an octagon from the center */
    private let gradients2D: [Double] = [
        5,  2,    2,  5,
        -5,  2,   -2,  5,
        5, -2,    2, -5,
        -5, -2,   -2, -5,
    ]
    
    private let stretchConstant3D: Double = -1.0 / 6.0
    private let squishConstant3D: Double = 1.0 / 3.0
    private let normConstant3D: Double = 103.0
    /* Gradients for 3D. They approximate the directions to the vertices of a rhombicuboctahedron
     * from the center, skewed so that the triangular and square facets can be inscribed inside
     * circles of the same radius.
     */
    private let gradients3D: [Double] = [
        -11,  4,  4,     -4,  11,  4,    -4,  4,  11,
        11,  4,  4,      4,  11,  4,     4,  4,  11,
        -11, -4,  4,     -4, -11,  4,    -4, -4,  11,
        11, -4,  4,      4, -11,  4,     4, -4,  11,
        -11,  4, -4,     -4,  11, -4,    -4,  4, -11,
        11,  4, -4,      4,  11, -4,     4,  4, -11,
        -11, -4, -4,     -4, -11, -4,    -4, -4, -11,
        11, -4, -4,      4, -11, -4,     4, -4, -11,
    ]
    
    // Permutation lookup table (used for pseudo random gradient assignment)
    var perm: [Int]
    var permGradIndex3D: [Int]
    init(seed: UInt64 = 1) {
        perm = []
        permGradIndex3D = []
        perm.reserveCapacity(256)
        permGradIndex3D.reserveCapacity(256)
        var generator = SeededGenerator(seed: seed)
        for v in (0..<256).shuffled(using: &generator) {
            let element = v // Int.random(in: 0..<256, using: &generator)
            perm.append(element)
            permGradIndex3D.append((perm.last! % (gradients3D.count / 3)) * 3)
        }
    }
    
    private func extrapolate2D(x0 xsb: Int, y0 ysb: Int, x1 dx: Double, y1 dy: Double) -> Double {
        let index: Int = perm[(perm[xsb & 0xFF] + ysb) & 0xFF] & 0x0E
        return gradients2D[index] * dx + gradients2D[index + 1] * dy
    }
    
    private func extrapolate3D(xsb: Int, ysb: Int, zsb: Int, dx: Double, dy: Double, dz: Double) -> Double {
        let index = permGradIndex3D[(perm[(perm[xsb & 0xFF] + ysb) & 0xFF] + zsb) & 0xFF]
        return gradients3D[index] * dx
                + gradients3D[index + 1] * dy
                + gradients3D[index + 2] * dz
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
    public func noise2D(x xin: Double, y yin: Double, featureSizeX: Double = 25.0, featureSizeY: Double = 25.0) -> Double {
        let x: Double = xin / featureSizeX
        let y: Double = yin / featureSizeY
        
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
        var dx0: Double = x - xb
        var dy0: Double = y - yb
        
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
    
    public func noise3D(x xin: Double, y yin: Double, z zin: Double, featureSizeX: Double = 25.0, featureSizeY: Double = 25.0, featureSizeZ: Double = 25.0) -> Double {
        let x = xin / featureSizeX
        let y = yin / featureSizeY
        let z = zin / featureSizeZ
        
        // Place input coords on simplectic honeycomb
        let stretchOffset: Double = (x + y + z) * stretchConstant3D
        let xs: Double = x + stretchOffset
        let ys: Double = y + stretchOffset
        let zs: Double = z + stretchOffset
        
        // Floor to get simplectic honeycomb coordinates of rhombohedron (streteched cube) super-cell origin
        let xsb: Int = fastFloor(xs)
        let ysb: Int = fastFloor(ys)
        let zsb: Int = fastFloor(zs)
        
        // Skew out to get actual coordinates of rhombohedron origin
        let squishOffset: Double = Double(xsb + ysb + zsb) * squishConstant3D
        let xb: Double = Double(xsb) + squishOffset
        let yb: Double = Double(ysb) + squishOffset
        let zb: Double = Double(zsb) + squishOffset
        
        // Compute simplectic honeycomb coordinates relative to rhombohedral origin
        let xins: Double = xs - Double(xsb)
        let yins: Double = ys - Double(ysb)
        let zins: Double = zs - Double(zsb)
        
        // Sum together to get value indicating region of simplex
        let inSum = xins + yins + zins
        
        // Positions relative to origin point
        var dx0: Double = x - xb
        var dy0: Double = y - yb
        var dz0: Double = z - zb
        
        var dx_ext0, dy_ext0, dz_ext0: Double
        var dx_ext1, dy_ext1, dz_ext1: Double
        var xsv_ext0, ysv_ext0, zsv_ext0: Int
        var xsv_ext1, ysv_ext1, zsv_ext1: Int
        
        var value: Double = 0.0
        if (inSum <= 1) {
            // Inside tetrahedron at (0,0,0), find which point (0,0,1), (0,1,0), (1,0,0) is closest
            var aPoint: Int8 = 0x01
            var aScore: Double = xins
            var bPoint: Int8 = 0x02
            var bScore: Double = yins
            if aScore >= bScore && zins > bScore {
                bScore = zins
                bPoint = 0x04
            } else if aScore < bScore && zins > aScore {
                aScore = zins
                aPoint = 0x04
            }
            
            // Determine two lattice points not part of the terahedron that may contribute
            // This depends on the closes two tetrahedral vertices, including (0,0,0)
            let wins = 1 - inSum
            // Test if (0,0,0) is one of the two closest vertices
            if wins > aScore || wins > bScore {
                // The other closest vertex is the closest out of a and b
                let c: Int8 = bScore > aScore ? bPoint : aPoint
                if (c & 0x01) == 0 {
                    xsv_ext0 = xsb - 1
                    xsv_ext1 = xsb
                    dx_ext0 = dx0 + 1
                    dx_ext1 = 1
                } else {
                    xsv_ext0 = xsb + 1
                    xsv_ext1 = xsb + 1
                    dx_ext0 = dx0 - 1
                    dx_ext1 = dx0 - 1
                }
                
                if (c & 0x02) == 0 {
                    ysv_ext0 = ysb
                    ysv_ext1 = ysb
                    dy_ext0 = dy0
                    dy_ext1 = dy0
                    if (c & 0x01) == 0 {
                        ysv_ext1 -= 1
                        dy_ext1 += 1
                    } else {
                        ysv_ext0 -= 1
                        dy_ext0 += 1
                    }
                } else {
                    ysv_ext0 = ysb + 1
                    ysv_ext1 = ysb + 1
                    dy_ext0 = dy0 - 1
                    dy_ext1 = dy0 - 1
                }
                
                if (c & 0x04) == 0 {
                    zsv_ext0 = zsb
                    zsv_ext1 = zsb - 1
                    dz_ext0 = dz0
                    dz_ext1 = dz0 + 1
                } else {
                    zsv_ext0 = zsb + 1
                    zsv_ext1 = zsb + 1
                    dz_ext0 = dz0 - 1
                    dz_ext1 = dz0 - 1
                }
            } else {
                // Two extra vertices are determined by the closes two
                let c: Int8 = (aPoint | bPoint)
                if (c & 0x01) == 0 {
                    xsv_ext0 = xsb
                    xsv_ext1 = xsb - 1
                    dx_ext0 = dx0 - 2 * squishConstant3D
                    dx_ext1 = dx0 + 1 - squishConstant3D
                } else {
                    xsv_ext0 = xsb + 1
                    xsv_ext1 = xsb + 1
                    dx_ext0 = dx0 - 1 - 2 * squishConstant3D
                    dx_ext1 = dx0 - 1 - squishConstant3D
                }
                
                if (c & 0x02) == 0 {
                    ysv_ext0 = ysb
                    ysv_ext1 = ysb - 1
                    dy_ext0 = dy0 - 2 * squishConstant3D
                    dy_ext1 = dy0 + 1 - squishConstant3D
                } else {
                    ysv_ext0 = ysb + 1
                    ysv_ext1 = ysb + 1
                    dy_ext0 = dy0 - 1 - 2 * squishConstant3D
                    dy_ext1 = dy0 - 1 - squishConstant3D
                }
                
                if (c & 0x04) == 0 {
                    zsv_ext0 = zsb
                    zsv_ext1 = zsb - 1
                    dz_ext0 = dz0 - 2 * squishConstant3D
                    dz_ext1 = dz0 + 1 - squishConstant3D
                } else {
                    zsv_ext0 = zsb + 1
                    zsv_ext1 = zsb + 1
                    dz_ext0 = dz0 - 1 - 2 * squishConstant3D
                    dz_ext1 = dz0 - 1 - squishConstant3D
                }
            }
            
            // Contribution (0,0,0)
            var attn0: Double = 2 - dx0 * dx0 - dy0 * dy0 - dz0 * dz0
            if (attn0 > 0) {
                attn0 *= attn0
                value += attn0 * attn0 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 0, zsb: zsb + 0, dx: dx0, dy: dy0, dz: dz0)
            }
            
            //Contribution (1,0,0)
            let dx1: Double = dx0 - 1 - squishConstant3D
            let dy1: Double = dy0 - 0 - squishConstant3D
            let dz1: Double = dz0 - 0 - squishConstant3D
            var attn1: Double = 2 - dx1 * dx1 - dy1 * dy1 - dz1 * dz1
            if (attn1 > 0) {
                attn1 *= attn1
                value += attn1 * attn1 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 0, zsb: zsb + 0, dx: dx1, dy: dy1, dz: dz1)
            }
            
            //Contribution (0,1,0)
            let dx2: Double = dx0 - 0 - squishConstant3D
            let dy2: Double = dy0 - 1 - squishConstant3D
            let dz2: Double = dz1
            var attn2: Double = 2 - dx2 * dx2 - dy2 * dy2 - dz2 * dz2
            if (attn2 > 0) {
                attn2 *= attn2
                value += attn2 * attn2 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 1, zsb: zsb + 0, dx: dx2, dy: dy2, dz: dz2)
            }
            
            //Contribution (0,0,1)
            let dx3: Double = dx2
            let dy3: Double = dy1
            let dz3: Double = dz0 - 1 - squishConstant3D
            var attn3: Double = 2 - dx3 * dx3 - dy3 * dy3 - dz3 * dz3
            if (attn3 > 0) {
                attn3 *= attn3
                value += attn3 * attn3 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 0, zsb: zsb + 1, dx: dx3, dy: dy3, dz: dz3)
            }
        } else if inSum >= 2 {
            // Inside tetrahedron at (1,1,1)
            
            // Determine which two tetrahedral vertices are the closest, out of (1,1,0), (1,0,1), (0,1,1) but not (1,1,1).
            var aPoint: Int8 = 0x06
            var aScore: Double = xins
            var bPoint: Int8 = 0x05
            var bScore: Double = yins
            if aScore <= bScore && zins < bScore {
                bScore = zins
                bPoint = 0x03
            } else if aScore > bScore && zins < aScore {
                aScore = zins
                aPoint = 0x03
            }
            
            // Determine the two lattice points not part of the tetrahedron that may contribute.
            // This depends on the closest two tetrahedral vertices, including (1,1,1)
            let wins: Double = 3 - inSum
            // Test if (1,1,1) is one of the closest two tetrahedral vertices.
            if wins < aScore || wins < bScore {
                //Our other closest vertex is the closest out of a and b.
                let c: Int8 = bScore < aScore ? bPoint : aPoint
                
                if (c & 0x01) != 0 {
                    xsv_ext0 = xsb + 2
                    xsv_ext1 = xsb + 1
                    dx_ext0 = dx0 - 2 - 3 * squishConstant3D
                    dx_ext1 = dx0 - 1 - 3 * squishConstant3D
                } else {
                    xsv_ext0 = xsb
                    xsv_ext1 = xsb
                    dx_ext0 = dx0 - 3 * squishConstant3D
                    dx_ext1 = dx0 - 3 * squishConstant3D
                }
                
                if (c & 0x02) != 0 {
                    ysv_ext0 = ysb + 1
                    ysv_ext1 = ysb + 1
                    dy_ext0 = dy0 - 1 - 3 * squishConstant3D
                    dy_ext1 = dy0 - 1 - 3 * squishConstant3D
                    if (c & 0x01) != 0 {
                        ysv_ext1 += 1
                        dy_ext1 -= 1
                    } else {
                        ysv_ext0 += 1
                        dy_ext0 -= 1
                    }
                } else {
                    ysv_ext0 = ysb
                    ysv_ext1 = ysb
                    dy_ext0 = dy0 - 3 * squishConstant3D
                    dy_ext1 = dy0 - 3 * squishConstant3D
                }
                
                if (c & 0x04) != 0 {
                    zsv_ext0 = zsb + 1
                    zsv_ext1 = zsb + 2
                    dz_ext0 = dz0 - 1 - 3 * squishConstant3D
                    dz_ext1 = dz0 - 2 - 3 * squishConstant3D
                } else {
                    zsv_ext0 = zsb
                    zsv_ext1 = zsb
                    dz_ext0 = dz0 - 3 * squishConstant3D
                    dz_ext1 = dz0 - 3 * squishConstant3D
                }
            } else {
                // Two extra vertices are determined by the closest two
                let c: Int8 = aPoint & bPoint
                
                if (c & 0x01) != 0 {
                    xsv_ext0 = xsb + 1
                    xsv_ext1 = xsb + 2
                    dx_ext0 = dx0 - 1 - squishConstant3D
                    dx_ext1 = dx0 - 2 - 2 * squishConstant3D
                } else {
                    xsv_ext0 = xsb
                    xsv_ext1 = xsb
                    dx_ext0 = dx0 - squishConstant3D
                    dx_ext1 = dx0 - 2 * squishConstant3D
                }
                
                if ((c & 0x02) != 0) {
                    ysv_ext0 = ysb + 1
                    ysv_ext1 = ysb + 2
                    dy_ext0 = dy0 - 1 - squishConstant3D
                    dy_ext1 = dy0 - 2 - 2 * squishConstant3D
                } else {
                    ysv_ext0 = ysb
                    ysv_ext1 = ysb
                    dy_ext0 = dy0 - squishConstant3D
                    dy_ext1 = dy0 - 2 * squishConstant3D
                }
                
                if ((c & 0x04) != 0) {
                    zsv_ext0 = zsb + 1
                    zsv_ext1 = zsb + 2
                    dz_ext0 = dz0 - 1 - squishConstant3D
                    dz_ext1 = dz0 - 2 - 2 * squishConstant3D
                } else {
                    zsv_ext0 = zsb
                    zsv_ext1 = zsb
                    dz_ext0 = dz0 - squishConstant3D
                    dz_ext1 = dz0 - 2 * squishConstant3D
                }
            }
            
            //Contribution (1,1,0)
            let dx3: Double = dx0 - 1 - 2 * squishConstant3D
            let dy3: Double = dy0 - 1 - 2 * squishConstant3D
            let  dz3: Double = dz0 - 0 - 2 * squishConstant3D
            var attn3: Double = 2 - dx3 * dx3 - dy3 * dy3 - dz3 * dz3
            if attn3 > 0 {
                attn3 *= attn3
                value += attn3 * attn3 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 1, zsb: zsb + 0, dx: dx3, dy: dy3, dz: dz3)
            }
            
            //Contribution (1,0,1)
            let dx2: Double = dx3
            let dy2: Double = dy0 - 0 - 2 * squishConstant3D
            let dz2: Double = dz0 - 1 - 2 * squishConstant3D
            var attn2: Double = 2 - dx2 * dx2 - dy2 * dy2 - dz2 * dz2
            if (attn2 > 0) {
                attn2 *= attn2
                value += attn2 * attn2 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 0, zsb: zsb + 1, dx: dx2, dy: dy2, dz: dz2)
            }
            
            //Contribution (0,1,1)
            let dx1: Double = dx0 - 0 - 2 * squishConstant3D
            let dy1: Double = dy3
            let dz1: Double = dz2
            var attn1: Double = 2 - dx1 * dx1 - dy1 * dy1 - dz1 * dz1
            if (attn1 > 0) {
                attn1 *= attn1
                value += attn1 * attn1 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 1, zsb: zsb + 1, dx: dx1, dy: dy1, dz: dz1)
            }
            
            //Contribution (1,1,1)
            dx0 = dx0 - 1 - 3 * squishConstant3D
            dy0 = dy0 - 1 - 3 * squishConstant3D
            dz0 = dz0 - 1 - 3 * squishConstant3D
            var attn0: Double = 2 - dx0 * dx0 - dy0 * dy0 - dz0 * dz0
            if (attn0 > 0) {
                attn0 *= attn0
                value += attn0 * attn0 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 1, zsb: zsb + 1, dx: dx0, dy: dy0, dz: dz0)
            }
        } else {
            // Inside octahedron (rectified 3-simplex) in between
            var aScore: Double
            var aPoint: Int8
            var aIsFurtherSide: Bool
            var bScore: Double
            var bPoint: Int8
            var bIsFurtherSide: Bool
            
            // Decide between point (0,0,1) and (1,1,0) as closest
            let p1: Double = xins + yins
            if p1 > 1 {
                aScore = p1 - 1
                aPoint = 0x03
                aIsFurtherSide = true
            } else {
                aScore = 1 - p1
                aPoint = 0x04
                aIsFurtherSide = false
            }
            
            // Decide between point (0,1,0) and (1,0,1) as closest
            let p2: Double = xins + zins
            if p2 > 1 {
                bScore = p2 - 1
                bPoint = 0x05
                bIsFurtherSide = true
            } else {
                bScore = 1 - p2
                bPoint = 0x02
                bIsFurtherSide = false
            }
            
            // The closest out of the two (1,0,0) and (0,1,1) will replace the furthest
            // out of the two decided above, if closer.
            let p3: Double = yins + zins
            if (p3 > 1) {
                let score: Double = p3 - 1
                if (aScore <= bScore && aScore < score) {
                    aScore = score
                    aPoint = 0x06
                    aIsFurtherSide = true
                } else if (aScore > bScore && bScore < score) {
                    bScore = score
                    bPoint = 0x06
                    bIsFurtherSide = true
                }
            } else {
                let score: Double = 1 - p3
                if (aScore <= bScore && aScore < score) {
                    aScore = score
                    aPoint = 0x01
                    aIsFurtherSide = false
                } else if (aScore > bScore && bScore < score) {
                    bScore = score
                    bPoint = 0x01
                    bIsFurtherSide = false
                }
            }
            
            // Where each of the two closest points are determines how the extra two vertices are calculated.
            if (aIsFurtherSide == bIsFurtherSide) {
                if (aIsFurtherSide) { //Both closest points on (1,1,1) side
                    
                    // One of the two extra points is (1,1,1)
                    dx_ext0 = dx0 - 1 - 3 * squishConstant3D
                    dy_ext0 = dy0 - 1 - 3 * squishConstant3D
                    dz_ext0 = dz0 - 1 - 3 * squishConstant3D
                    xsv_ext0 = xsb + 1
                    ysv_ext0 = ysb + 1
                    zsv_ext0 = zsb + 1
                    
                    // Other extra point is based on the shared axis.
                    let c: Int8 = aPoint & bPoint
                    if ((c & 0x01) != 0) {
                        dx_ext1 = dx0 - 2 - 2 * squishConstant3D
                        dy_ext1 = dy0 - 2 * squishConstant3D
                        dz_ext1 = dz0 - 2 * squishConstant3D
                        xsv_ext1 = xsb + 2
                        ysv_ext1 = ysb
                        zsv_ext1 = zsb
                    } else if ((c & 0x02) != 0) {
                        dx_ext1 = dx0 - 2 * squishConstant3D
                        dy_ext1 = dy0 - 2 - 2 * squishConstant3D
                        dz_ext1 = dz0 - 2 * squishConstant3D
                        xsv_ext1 = xsb
                        ysv_ext1 = ysb + 2
                        zsv_ext1 = zsb
                    } else {
                        dx_ext1 = dx0 - 2 * squishConstant3D
                        dy_ext1 = dy0 - 2 * squishConstant3D
                        dz_ext1 = dz0 - 2 - 2 * squishConstant3D
                        xsv_ext1 = xsb
                        ysv_ext1 = ysb
                        zsv_ext1 = zsb + 2
                    }
                } else {
                    // Both closest points on (0,0,0) side
                    // One of the two extra points is (0,0,0)
                    dx_ext0 = dx0
                    dy_ext0 = dy0
                    dz_ext0 = dz0
                    xsv_ext0 = xsb
                    ysv_ext0 = ysb
                    zsv_ext0 = zsb
                    
                    // Other extra point is based on the omitted axis.
                    let c: Int8 = aPoint | bPoint
                    if ((c & 0x01) == 0) {
                        dx_ext1 = dx0 + 1 - squishConstant3D
                        dy_ext1 = dy0 - 1 - squishConstant3D
                        dz_ext1 = dz0 - 1 - squishConstant3D
                        xsv_ext1 = xsb - 1
                        ysv_ext1 = ysb + 1
                        zsv_ext1 = zsb + 1
                    } else if ((c & 0x02) == 0) {
                        dx_ext1 = dx0 - 1 - squishConstant3D
                        dy_ext1 = dy0 + 1 - squishConstant3D
                        dz_ext1 = dz0 - 1 - squishConstant3D
                        xsv_ext1 = xsb + 1
                        ysv_ext1 = ysb - 1
                        zsv_ext1 = zsb + 1
                    } else {
                        dx_ext1 = dx0 - 1 - squishConstant3D
                        dy_ext1 = dy0 - 1 - squishConstant3D
                        dz_ext1 = dz0 + 1 - squishConstant3D
                        xsv_ext1 = xsb + 1
                        ysv_ext1 = ysb + 1
                        zsv_ext1 = zsb - 1
                    }
                }
            } else {
                // One point on (0,0,0) side, one point on (1,1,1) side
                let c1, c2: Int8
                if (aIsFurtherSide) {
                    c1 = aPoint
                    c2 = bPoint
                } else {
                    c1 = bPoint
                    c2 = aPoint
                }
                
                // One contribution is a permutation of (1,1,-1)
                if ((c1 & 0x01) == 0) {
                    dx_ext0 = dx0 + 1 - squishConstant3D
                    dy_ext0 = dy0 - 1 - squishConstant3D
                    dz_ext0 = dz0 - 1 - squishConstant3D
                    xsv_ext0 = xsb - 1
                    ysv_ext0 = ysb + 1
                    zsv_ext0 = zsb + 1
                } else if ((c1 & 0x02) == 0) {
                    dx_ext0 = dx0 - 1 - squishConstant3D
                    dy_ext0 = dy0 + 1 - squishConstant3D
                    dz_ext0 = dz0 - 1 - squishConstant3D
                    xsv_ext0 = xsb + 1
                    ysv_ext0 = ysb - 1
                    zsv_ext0 = zsb + 1
                } else {
                    dx_ext0 = dx0 - 1 - squishConstant3D
                    dy_ext0 = dy0 - 1 - squishConstant3D
                    dz_ext0 = dz0 + 1 - squishConstant3D
                    xsv_ext0 = xsb + 1
                    ysv_ext0 = ysb + 1
                    zsv_ext0 = zsb - 1
                }
                
                // One contribution is a permutation of (0,0,2)
                dx_ext1 = dx0 - 2 * squishConstant3D
                dy_ext1 = dy0 - 2 * squishConstant3D
                dz_ext1 = dz0 - 2 * squishConstant3D
                xsv_ext1 = xsb
                ysv_ext1 = ysb
                zsv_ext1 = zsb
                if ((c2 & 0x01) != 0) {
                    dx_ext1 -= 2
                    xsv_ext1 += 2
                } else if ((c2 & 0x02) != 0) {
                    dy_ext1 -= 2
                    ysv_ext1 += 2
                } else {
                    dz_ext1 -= 2
                    zsv_ext1 += 2
                }
            }
            
            // Contribution (1,0,0)
            let dx1: Double = dx0 - 1 - squishConstant3D
            let dy1: Double = dy0 - 0 - squishConstant3D
            let dz1: Double = dz0 - 0 - squishConstant3D
            var attn1: Double = 2 - dx1 * dx1 - dy1 * dy1 - dz1 * dz1
            if (attn1 > 0) {
                attn1 *= attn1
                value += attn1 * attn1 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 0, zsb: zsb + 0, dx: dx1, dy: dy1, dz: dz1)
            }
            
            // Contribution (0,1,0)
            let dx2: Double = dx0 - 0 - squishConstant3D
            let dy2: Double = dy0 - 1 - squishConstant3D
            let dz2: Double = dz1
            var attn2: Double = 2 - dx2 * dx2 - dy2 * dy2 - dz2 * dz2
            if (attn2 > 0) {
                attn2 *= attn2
                value += attn2 * attn2 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 1, zsb: zsb + 0, dx: dx2, dy: dy2, dz: dz2)
            }
            
            // Contribution (0,0,1)
            let dx3: Double = dx2
            let dy3: Double = dy1
            let dz3: Double = dz0 - 1 - squishConstant3D
            var attn3: Double = 2 - dx3 * dx3 - dy3 * dy3 - dz3 * dz3
            if (attn3 > 0) {
                attn3 *= attn3
                value += attn3 * attn3 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 0, zsb: zsb + 1, dx: dx3, dy: dy3, dz: dz3)
            }
            
            // Contribution (1,1,0)
            let dx4: Double = dx0 - 1 - 2 * squishConstant3D
            let dy4: Double = dy0 - 1 - 2 * squishConstant3D
            let dz4: Double = dz0 - 0 - 2 * squishConstant3D
            var attn4: Double = 2 - dx4 * dx4 - dy4 * dy4 - dz4 * dz4
            if (attn4 > 0) {
                attn4 *= attn4
                value += attn4 * attn4 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 1, zsb: zsb + 0, dx: dx4, dy: dy4, dz: dz4)
            }
            
            // Contribution (1,0,1)
            let dx5: Double = dx4
            let dy5: Double = dy0 - 0 - 2 * squishConstant3D
            let dz5: Double = dz0 - 1 - 2 * squishConstant3D
            var attn5: Double = 2 - dx5 * dx5 - dy5 * dy5 - dz5 * dz5
            if (attn5 > 0) {
                attn5 *= attn5
                value += attn5 * attn5 * extrapolate3D(xsb: xsb + 1, ysb: ysb + 0, zsb: zsb + 1, dx: dx5, dy: dy5, dz: dz5)
            }
            
            // Contribution (0,1,1)
            let dx6: Double = dx0 - 0 - 2 * squishConstant3D
            let dy6: Double = dy4
            let dz6: Double = dz5
            var attn6: Double = 2 - dx6 * dx6 - dy6 * dy6 - dz6 * dz6
            if (attn6 > 0) {
                attn6 *= attn6
                value += attn6 * attn6 * extrapolate3D(xsb: xsb + 0, ysb: ysb + 1, zsb: zsb + 1, dx: dx6, dy: dy6, dz: dz6)
            }
        }
        
        //First extra vertex
        var attn_ext0: Double = 2 - dx_ext0 * dx_ext0 - dy_ext0 * dy_ext0 - dz_ext0 * dz_ext0;
        if (attn_ext0 > 0)
        {
            attn_ext0 *= attn_ext0;
            value += attn_ext0 * attn_ext0 * extrapolate3D(xsb: xsv_ext0, ysb: ysv_ext0, zsb: zsv_ext0, dx: dx_ext0, dy: dy_ext0, dz: dz_ext0);
        }
        
        //Second extra vertex
        var attn_ext1: Double = 2 - dx_ext1 * dx_ext1 - dy_ext1 * dy_ext1 - dz_ext1 * dz_ext1;
        if (attn_ext1 > 0)
        {
            attn_ext1 *= attn_ext1;
            value += attn_ext1 * attn_ext1 * extrapolate3D(xsb: xsv_ext1, ysb: ysv_ext1, zsb: zsv_ext1, dx: dx_ext1, dy: dy_ext1, dz: dz_ext1);
        }
        
        return value / normConstant3D;
    }
}
