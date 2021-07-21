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
    func frameRecorderShouldRecordFrame(_ frame: Int) -> Bool
    func frameRecorderWillRecordFrame(_ frame: Int)
    func frameRecorderRequestImageForFrame(_ frame: Int, at time: CFTimeInterval) -> NSUIImage
    func frameRecorderDidRecordFrame(_ frame: Int, at time: CFTimeInterval, image: NSUIImage)
}
