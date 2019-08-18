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

func main() {
    // CommandLine argument count must equal three
    guard CommandLine.argc == 4 else {
        print("Usage: \(CommandLine.arguments[0]) <width> <height> <file>")
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
    let targetFilePath = NSString(string: CommandLine.arguments[3]).expandingTildeInPath
    
    print("Generating Terrain with width: \(width) and height: \(height) at path: \(targetFilePath)")
    
    // Create target file if it does not exist (required)
    let fileManager = FileManager.default
    if (!fileManager.fileExists(atPath: targetFilePath)) {
        print("Created File since it does not exist")
        fileManager.createFile(atPath: targetFilePath, contents: nil, attributes: nil)
    }
    
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
    
    // TODO: temporary code writing to the pixels
    let pixels = context.data!
    for y in 0..<height {
        for x in 0..<width {
            let value: Float = 256 * (Float(y) / (2.0 * Float(height)) + Float(x) / (2.0 * Float(width)))
            pixels.storeBytes(of: UInt8(value), toByteOffset: y * width + x, as: UInt8.self)
        }
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

main()
