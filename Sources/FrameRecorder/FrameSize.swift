//
//  Copyright © 2021 Apparata AB. All rights reserved.
//

import Foundation
import CoreGraphics

public enum FrameSize {
    case frameSize720p
    case frameSize1080p
    case frameSize4K
    case frameSize(width: Int, height: Int)
}
 
extension FrameSize {
    
    public var width: Int {
        switch self {
        case .frameSize720p: return 1280
        case .frameSize1080p: return 1920
        case .frameSize4K: return 3840
        case .frameSize(let width, _): return width
        }
    }
    
    public var height: Int {
        switch self {
        case .frameSize720p: return 720
        case .frameSize1080p: return 1080
        case .frameSize4K: return 2160
        case .frameSize(_, let height): return height
        }
    }
    
    public var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
    
    public init(width: Int, height: Int) {
        self = .frameSize(width: width, height: height)
    }

    public init(width: Double, height: Double) {
        self = .frameSize(width: Int(width), height: Int(height))
    }
    
    public init(width: CGFloat, height: CGFloat) {
        self = .frameSize(width: Int(width), height: Int(height))
    }

    public init(size: CGSize) {
        self = .frameSize(width: Int(size.width), height: Int(size.height))
    }

}
