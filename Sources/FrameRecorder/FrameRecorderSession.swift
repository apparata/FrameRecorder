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

internal final class FrameRecorderSession {
    
    private enum ProcessingStatus {
        case `continue`
        case finished
    }
    
    private class ProcessingContext {
        var status: ProcessingStatus = .continue
        var frame: Int = 0
        
        func advanceFrame() {
            frame += 1
        }
    }
    
    private var isCancelled: Bool = false
    
    private let recorderQueue: DispatchQueue
    private var assetWriter: AVAssetWriter!
    private var input: AVAssetWriterInput!
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    private let url: URL
    private let size: FrameSize
    private let fps: Int
    
    private let frameDuration: CFTimeInterval
    private let framePresentationDuration: CMTime
    private let timescale: Int32 = 600
        
    internal init(url: URL, size: FrameSize, fps: Int) {
        self.url = url
        self.size = size
        self.fps = fps
        
        frameDuration = CFTimeInterval(1.0 / Double(fps))
        framePresentationDuration = CMTimeMake(
            value: Int64(floor(Double(timescale) / Double(fps))),
            timescale: timescale)
        
        // Create a serial queue for recording.
        recorderQueue = DispatchQueue(label: "se.apparata.FrameRecorderQueue")
    }
    
    // MARK: - Cancel
    
    internal func cancel() {
        isCancelled = true
    }
    
    // MARK: - Record
    
    @FrameRecorderActor
    internal func record(frames: FrameProvider) async throws {
        try prepareForWritingVideoFile()
        
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .m4v)
        
        input = makeAssetWriterInput()
        assetWriter.add(input)
        
        pixelBufferAdaptor = makePixelBufferAdaptor(input: input)
        
        // The asset writer and its inputs must be configured at this point.
        guard assetWriter.startWriting() else {
            throw FrameRecorderError.failedToStartWritingVideo(assetWriter.error)
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        let context = ProcessingContext()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: recorderQueue) { [weak self] in
                do {
                    try self?.processNextBatchOfFrames(from: frames, context: context)
                    
                    if context.status == .finished {
                        self?.input?.markAsFinished()
                        self?.assetWriter?.finishWriting {
                            continuation.resume()
                        }
                    }
                } catch {
                    // Try cancelling, no matter what the error is.
                    self?.input?.markAsFinished()
                    self?.assetWriter?.cancelWriting()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Request Next Frame
    
    private func processNextBatchOfFrames(from frames: FrameProvider, context: ProcessingContext) throws {
        
        guard let input = input, let pool = pixelBufferAdaptor.pixelBufferPool else {
            throw FrameRecorderError.unexpected
        }
        
        if isCancelled {
            throw CancellationError()
        }
                
        while input.isReadyForMoreMediaData {

            let time = frameDuration * CFTimeInterval(context.frame)
            guard let image = frames.requestFrame(context.frame, at: time, framesPerSecondTarget: fps) else {
                context.status = .finished
                return
            }
            
            let pixelBuffer = try PixelBuffer.make(of: size.cgSize, from: image, pool: pool)
            let presentationTime = CMTimeMultiply(framePresentationDuration, multiplier: Int32(context.frame))
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        
            if isCancelled {
                throw CancellationError()
            }

            context.advanceFrame()
        }
        
        context.status = .continue
    }
    
    // MARK: - Make Asset Writer Input
    
    private func makeAssetWriterInput() -> AVAssetWriterInput {
        AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ])
    }
    
    // MARK: - Make Pixel Buffer Adaptor
    
    private func makePixelBufferAdaptor(input: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
        AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )
    }
    
    // MARK: - Prepare for Writing
    
    private func prepareForWritingVideoFile() throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: url.path) {
            // Remove file if it already exists.
            try fileManager.removeItem(atPath: url.path)
        } else {
            // Create directory if needed.
            try fileManager.createDirectory(
                atPath: url.deletingLastPathComponent().path,
                withIntermediateDirectories: true,
                attributes: nil)
        }
    }
}
