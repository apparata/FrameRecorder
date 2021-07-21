//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum PixelBufferError: Error {
    case failedToAccessCGImage
    case failedToCreatePixelBuffer
    case failedToCreateCGContext
}

class PixelBuffer {
    
    static func make(of size: CGSize, from image: NSUIImage, pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        
        #if os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PixelBufferError.failedToAccessCGImage
        }
        #else
        guard let cgImage = image.cgImage else {
            throw PixelBufferError.failedToAccessCGImage
        }
        #endif

        let pixelBuffer = try makeCVPixelBuffer(pool: pool)
                
        try drawImage(cgImage, of: size, to: pixelBuffer)
        
        return pixelBuffer
    }
    
    static private func makeCVPixelBuffer(pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw PixelBufferError.failedToCreatePixelBuffer
        }
        return pixelBuffer
    }
    
    static private func drawImage(_ image: CGImage, of size: CGSize, to pixelBuffer: CVPixelBuffer) throws {
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            throw PixelBufferError.failedToCreateCGContext
        }
        
        context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    }
}
