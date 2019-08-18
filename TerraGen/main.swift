//
//  main.swift
//  TerraGen
//
//  Created by Dominik Horn on 8/18/19.
//  Copyright © 2019 Dominik Horn. All rights reserved.
//

import Cocoa

// TODO: replace these with command line arguments
let width = 256
let height = 256
let targetFilePath = "/Users/Dominik/Desktop/terrain.png"


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
    exit(-1)
}

// TODO: temporary code writing to the pixels
let pixels = context.data!
for y in 0..<height {
    for x in 0..<width {
        pixels.storeBytes(of: UInt8(y), toByteOffset: y * width + x, as: UInt8.self)
    }
}

// Store to file on disk
guard let cgimage = context.makeImage() else {
    print("Failed to create NSImage from CGContext")
    exit(-2)
}
let imgRep = NSBitmapImageRep(cgImage: cgimage)
let pngData = imgRep.representation(using: .png, properties: [:])
try pngData?.write(to: URL(fileURLWithPath: targetFilePath), options: [])
