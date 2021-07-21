import Foundation
#if canImport(AppKit)
import AppKit
public typealias NSUIImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias NSUIImage = UIImage
#endif
