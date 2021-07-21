//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public protocol FrameRecorderDelegate: AnyObject {
    func frameRecorder(_ frameRecorder: FrameRecorder, shouldRecordFrame frame: Int) -> Bool
    func frameRecorder(_ frameRecorder: FrameRecorder, willRecordFrame frame: Int)
    func frameRecorder(_ frameRecorder: FrameRecorder, requestImageForFrame frame: Int, at time: CFTimeInterval) -> NSUIImage
    func frameRecorder(_ frameRecorder: FrameRecorder, didRecordFrame frame: Int, at time: CFTimeInterval, image: NSUIImage)
}
