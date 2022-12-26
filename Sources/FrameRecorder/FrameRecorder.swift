//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation

// MARK: - Frame Recorder

/// Records video to file frame-by-frame, by asking for one image per frame.
///
/// **NOTE:** The frame recorder is a one-shot instance. A new instance is required to record a new video.
///
public final class FrameRecorder {
    
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
    
    /// The current state the frame recorder is in.
    public private(set) var state: State
        
    /// The dimension of the video frame in pixels.
    public let frameSize: FrameSize
    
    /// The playback frame rate of the recorded video.
    public let framesPerSecond: Int
        
    private var session: FrameRecorderSession?
    
    // MARK: - Constructor
    
    /// Initializes the frame recorder.
    ///
    /// **NOTE:** The frame recorder is a one-shot instance. A new instance is required to
    /// record a new video.
    ///
    /// - Parameters:
    ///   - size: The video frame size in pixels. Defaults to 1280x720.
    ///   - fps: Frames per second. Defaults to 60.
    ///
    public nonisolated init(_ frameSize: FrameSize = .frameSize720p, framesPerSecond: Int = 60) {
        self.frameSize = frameSize
        self.framesPerSecond = framesPerSecond
        self.state = .idle
    }
    
    // MARK: - Record
    
    /// Record the video.
    ///
    /// **NOTE:** The video recorder is a one-shot instance. A new instance is required to record
    ///          another video.
    ///
    /// - Parameters:
    ///   - url: The file URL to write the video to. If a file already exists, it will be overwritten.
    ///   - frames: An asynchronous stream of images two write to the video.
    ///
    @FrameRecorderActor
    public func record(to url: URL, frames: FrameProvider) async throws {
        
        if Task.isCancelled || state == .cancelled {
            state = .cancelled
            throw CancellationError()
        }
        
        guard state == .idle else {
            throw FrameRecorderError.recordingAlreadyStarted
        }
        
        state = .recording
        
        session = FrameRecorderSession(url: url, size: frameSize, fps: framesPerSecond)
        
        do {
            try await withTaskCancellationHandler {
                try await session?.record(frames: frames)
                state = .ended
            } onCancel: {
                session?.cancel()
            }
        } catch let cancellation as CancellationError {
            state = .cancelled
            removeVideo(at: url)
            throw cancellation
        } catch {
            state = .failed
            removeVideo(at: url)
            throw error
        }
    }
    
    @FrameRecorderActor
    private func removeVideo(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            dump(error)
        }
    }
}
