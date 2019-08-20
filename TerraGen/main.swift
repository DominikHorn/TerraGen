//
//  main.swift
//  TerraGen
//
//  Created by Dominik Horn on 8/18/19.
//  Copyright © 2019 Dominik Horn. All rights reserved.
//

import Cocoa

enum ErrorCode: Int32 {
    case NoError = 0
    case InvalidArgument = 1
    case CoreGraphicsError = 2
    case IOError = 3
}

func exitWith(_ error: ErrorCode = .NoError) -> Never {
    exit(error.rawValue)
}

func parseArguments() -> (width: UInt, height: UInt, depth: UInt, featureSizeX: Double, featureSizeY: Double, featureSizeZ: Double, quantizerLevels: UInt, seed: UInt64, targetFilePath: String) {
    // CommandLine argument count must equal three
    guard CommandLine.argc == 10 else {
        print("Usage: \(CommandLine.arguments[0]) <width> <height> <depth> <featureSizeX> <featureSizeY> <featureSizeZ> <quantizerLevels> <seed> <file>")
        exitWith(.NoError)
    }
    
    // Initialize script parameters
    guard let width = UInt(CommandLine.arguments[1]) else {
        print("Failed to parse width parameter")
        exitWith(.InvalidArgument)
    }
    guard let height = UInt(CommandLine.arguments[2]) else {
        print("Failed to parse height parameter")
        exitWith(.InvalidArgument)
    }
    guard let depth = UInt(CommandLine.arguments[3]) else {
        print("Failed to parse depth parameter")
        exitWith(.InvalidArgument)
    }
    guard let featureSizeX = Double(CommandLine.arguments[4]) else {
        print("Failed to parse featureSizeX parameter")
        exitWith(.InvalidArgument)
    }
    guard let featureSizeY = Double(CommandLine.arguments[5]) else {
        print("Failed to parse featureSizeY parameter")
        exitWith(.InvalidArgument)
    }
    guard let featureSizeZ = Double(CommandLine.arguments[6]) else {
        print("Failed to parse featureSizeZ parameter")
        exitWith(.InvalidArgument)
    }
    guard let quantizerLevels = UInt(CommandLine.arguments[7]) else {
        print("Failed to parse quantizerLevels parameter")
        exitWith(.InvalidArgument)
    }
    guard let seed = UInt64(CommandLine.arguments[8]) else {
        print("Failed to parse seed parameter")
        exitWith(.InvalidArgument)
    }
    let targetFilePath = NSString(string: NSString(string: CommandLine.arguments[9]).expandingTildeInPath).deletingPathExtension
    
    return (width, height, depth, featureSizeX, featureSizeY, featureSizeZ, quantizerLevels, seed, targetFilePath)
}

func createGrayScaleContext(width: Int, height: Int) -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext.init(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("Failed to initialize CGContext")
            exitWith(.CoreGraphicsError)
    }
    
    return context
}

func write(grayScaleContext context: CGContext, toPath targetFilePath: String) {
    // Create target file if it does not exist (required)
    let fileManager = FileManager.default
    if (!fileManager.fileExists(atPath: targetFilePath)) {
        fileManager.createFile(atPath: targetFilePath, contents: nil, attributes: nil)
    }
    
    // Store to file on disk
    guard let cgimage = context.makeImage() else {
        print("Failed to create NSImage from CGContext")
        exitWith(.CoreGraphicsError)
    }
    let imgRep = NSBitmapImageRep(cgImage: cgimage)
    let pngData = imgRep.representation(using: .png, properties: [:])
    
    do {
        try pngData?.write(to: URL(fileURLWithPath: targetFilePath), options: [])
    } catch {
        print("Failed to write data to disk")
        exitWith(.IOError)
    }
}

func setGrayScalePixel(value: UInt8, inContext context: CGContext, x: Int, y: Int, width: Int) {
    context.data!.storeBytes(of: value, toByteOffset: y * width + x, as: UInt8.self)
}

func uniformQuantize(value: Double, max: Double, min: Double, quantizerLevels: UInt) -> Double {
    guard quantizerLevels != 0 else {
        return 0.0
    }
    
    let stepSize = (max - min) / Double(quantizerLevels)
    return floor(value / stepSize) * stepSize
} 

func main() {
    let (width, height, depth, featureSizeX, featureSizeY, featureSizeZ, quantizerLevels, seed, targetFilePath) = parseArguments()
    
    let noise = SimplexNoise(seed: seed)
    for z in Progress(0..<depth) {
        let context = createGrayScaleContext(width: Int(width), height: Int(height))
        for y in 0..<height {
            for x in 0..<width {
                let value = 127.5 * (noise.noise3D(x: Double(x), y: Double(y), z: Double(z),
                                    featureSizeX: featureSizeX, featureSizeY: featureSizeY, featureSizeZ: featureSizeZ) + 1.0)
                let quantized = uniformQuantize(value: value, max: 255, min: 0, quantizerLevels: quantizerLevels)
                setGrayScalePixel(
                    value: UInt8(min(max(quantized, 0x00), 0xFF)),
                    inContext: context,
                    x: Int(x),
                    y: Int(y),
                    width: Int(width)
                )
            }
        }
        write(grayScaleContext: context, toPath: "\(targetFilePath)_\(z).png")
    }
}

main()
