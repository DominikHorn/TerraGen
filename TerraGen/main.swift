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

func parseArguments() -> (width: Int, height: Int, seed: UInt64, targetFilePath: String) {
    // CommandLine argument count must equal three
    guard CommandLine.argc == 5 else {
        print("Usage: \(CommandLine.arguments[0]) <width> <height> <seed> <file>")
        exitWith(.NoError)
    }
    
    // Initialize script parameters
    guard let width = Int(CommandLine.arguments[1]) else {
        print("Failed to parse width parameter")
        exitWith(.InvalidArgument)
    }
    guard let height = Int(CommandLine.arguments[2]) else {
        print("Failed to parse height parameter")
        exitWith(.InvalidArgument)
    }
    guard let seed = UInt64(CommandLine.arguments[3]) else {
        print("Failed to parse seed parameter")
        exitWith(.InvalidArgument)
    }
    let targetFilePath = NSString(string: CommandLine.arguments[4]).expandingTildeInPath
    
    return (width, height, seed, targetFilePath)
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

func uniformQuantize(value: Double, max: Double, min: Double, stepCount: Int) -> Double {
    let stepSize = (max - min) / Double(stepCount)
    return floor(value / stepSize) * stepSize
}

func main() {
    let (width, height, seed, targetFilePath) = parseArguments()
    let context = createGrayScaleContext(width: width, height: height)
    
    let noise = SimplexNoise(seed: seed)
    for y in 0..<height {
        for x in 0..<width {
            let value = 127.5 * (noise.noise2D(x: Double(x), y: Double(y)) + 1.0)
            let quantized = uniformQuantize(value: value, max: 255, min: 0, stepCount: 4)
            setGrayScalePixel(
                value: UInt8(min(max(quantized, 0x00), 0xFF)),
                inContext: context,
                x: x,
                y: y,
                width: width
            )
        }
    }

    write(grayScaleContext: context, toPath: targetFilePath)
}

main()
