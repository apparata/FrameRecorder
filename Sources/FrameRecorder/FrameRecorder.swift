//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Frame Recorder

/// Records video to file by asking the delegate to provide one image per frame.
///
/// **NOTE:** The video recorder is a one-shot instance. A new instance is required to record a new video.
///
public final class FrameRecorder {
    
    public static let defaultVideoFPS = Int(60)
    public static let defaultVideoSize = CGSize(width: 1280, height: 720)

    public enum State {
        
        /// Video recording has not yet started.
        case idle
        
        /// Video is currently being recorded.
        case recording
        
        /// Video recording was cancelled.
        case cancelled
        
        /// Video recording failed.
        case failed
        
        /// Video recording ended successfully.
        case ended
    }
    
    public private(set) var state: State
    
    public weak var delegate: FrameRecorderDelegate?
    
    public private(set) var fps: Int = defaultVideoFPS
    public private(set) var size: CGSize = defaultVideoSize
    
    private let recorderQueue: DispatchQueue
    private var assetWriter: AVAssetWriter!
    private var input: AVAssetWriterInput!
    
    public init(size: CGSize = defaultVideoSize, fps: Int = defaultVideoFPS) {
        self.fps = fps
        self.size = size
        state = .idle
        recorderQueue = DispatchQueue(label: "se.apparata.RecorderQueue")
    }
            
    // MARK: - Record
    
    /// Starts recording the video.
    ///
    /// **NOTE:** The video recorder is a one-shot instance. A new instance is required to record
    ///          another video.
    ///
    /// **NOTE:** The delegate must be set before `record()` is called.
    ///
    /// - Parameters:
    ///   - url: The file URL to write the video to. If a file already exists, it will be overwritten.
    ///   - size: The video frame size in pixels. Defaults to 1280x720
    ///   - fps: Frames per second. Defaults to 60.
    ///   - completion: Called from main thread when recording ends, is cancelled, or fails.
    public func record(to url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        
        guard state == .idle else {
            if state == .cancelled {
                DispatchQueue.main.async {
                    completion(.failure(FrameRecorderError.recordingCancelled))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(FrameRecorderError.recordingAlreadyStarted))
                }
            }
            return
        }
        
        guard delegate != nil else {
            DispatchQueue.main.async {
                completion(.failure(FrameRecorderError.delegateNotSet))
            }
            return
        }
                
        recorderQueue.async { [size, fps] in
            self.recordOnRecorderQueue(to: url, size: size, fps: fps, completion: completion)
        }
    }
    
    // MARK: - Cancel
    
    /// Cancel video recording.
    public func cancel() {
        state = .cancelled
    }
    
    // MARK: - Record on Queue
    
    private func recordOnRecorderQueue(to url: URL,
                                       size: CGSize,
                                       fps: Int,
                                       completion: @escaping (Result<URL, Error>) -> Void) {
        
        state = .recording
        
        let frameDuration = CFTimeInterval(1.0 / Double(fps))
        let timescale: Int32 = 600
        let framePresentationDuration = CMTimeMake(
            value: Int64(floor(Double(timescale) / Double(fps))),
            timescale: timescale)
        
        var frame: Int = 0
                        
        do {
            try prepareForWritingVideoFile(at: url)
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .m4v)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        assetWriter.add(input)
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )
        
        guard assetWriter.startWriting() else {
            DispatchQueue.main.async {
                completion(.failure(FrameRecorderError.failedToStartWritingVideo))
            }
            return
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        input.requestMediaDataWhenReady(on: self.recorderQueue, using: { [weak self] in
            
            guard let self = self else {
                return
            }
            
            guard let delegate = self.delegate else {
                return
            }
            
            if self.state == .cancelled {
                self.cancelRecording(completion: completion)
                return
            }
            
            guard delegate.frameRecorder(self, shouldRecordFrame: frame) else {
                self.finishRecording(completion: completion)
                return
            }
            
            if self.input?.isReadyForMoreMediaData ?? false {
                
                guard let pool = pixelBufferAdaptor.pixelBufferPool else {
                    return
                }
                
                let time = frameDuration * CFTimeInterval(frame)
                let image = delegate.frameRecorder(self, requestImageForFrame: frame, at: time)
                
                do {
                    let pixelBuffer = try PixelBuffer.make(of: size, from: image, pool: pool)
                    let presentationTime = CMTimeMultiply(framePresentationDuration, multiplier: Int32(frame))
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)

                    delegate.frameRecorder(self, didRecordFrame: frame, at: time, image: image)
                } catch {
                    dump(error)
                }
                
                frame += 1
            }
        })
    }
    
    // MARK: - Finish Recording
    
    private func finishRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let input = input, let assetWriter = assetWriter else {
            state = .failed
            DispatchQueue.main.async {
                completion(.failure(FrameRecorderError.failedToFinishRecordingVideo))
            }
            return
        }
        
        input.markAsFinished()
        assetWriter.finishWriting { [weak self] in
            self?.state = .ended
            DispatchQueue.main.async {
                completion(.success(assetWriter.outputURL))
            }
        }
    }

    // MARK: - Cancel Recording
    
    private func cancelRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        state = .cancelled
        input?.markAsFinished()
        assetWriter?.cancelWriting()
        DispatchQueue.main.async {
            completion(.failure(FrameRecorderError.recordingCancelled))
        }
    }
    
    // MARK: - Prepare for Writing
    
    private func prepareForWritingVideoFile(at url: URL) throws {
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
