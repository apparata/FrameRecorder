//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation

public enum FrameRecorderError: Error {
    case recordingCancelled
    case recordingAlreadyStarted
    case delegateNotSet
    case failedToStartWritingVideo
    case failedToFinishRecordingVideo
}
