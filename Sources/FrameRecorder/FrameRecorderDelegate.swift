//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation
import UIKit

public protocol FrameRecorderDelegate: AnyObject {
    func frameRecorderShouldRecordFrame(_ frame: Int) -> Bool
    func frameRecorderWillRecordFrame(_ frame: Int)
    func frameRecorderRequestImageForFrame(_ frame: Int, at time: CFTimeInterval) -> UIImage
    func frameRecorderDidRecordFrame(_ frame: Int, at time: CFTimeInterval, image: UIImage)
}
