//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation

public enum FrameRecorderError: Error {
    case recordingAlreadyStarted
    case failedToStartWritingVideo(Error?)
    case failedToFinishRecordingVideo
    case unexpected
}
