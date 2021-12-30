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

public protocol FrameProvider {
    /// Returns an image corresponding to frame index at specified time or `nil` if no more frames.
    func requestFrame(_ frame: Int, at time: CFTimeInterval, framesPerSecondTarget fps: Int) -> NSUIImage?
}
