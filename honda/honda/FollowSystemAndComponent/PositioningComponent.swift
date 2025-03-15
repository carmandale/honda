/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The component for following the device.
*/

import Foundation
import RealityKit
import SwiftUI
import ARKit

/// A component to add to any entity that you want to move with the device's transform.
/// This component works with the PositioningSystem to position entities relative to the user's head.
public struct PositioningComponent: Component, Codable {
    // Offset values determine the position relative to the device/head position
    var offsetX: Float  // Horizontal offset (positive = right, negative = left)
    var offsetY: Float  // Vertical offset (positive = up, negative = down)
    var offsetZ: Float  // Depth offset (positive = forward, negative = backward)
    
    // Control flags for the positioning system
    var needsPositioning: Bool  // When true, the entity will be positioned by the PositioningSystem
    var shouldAnimate: Bool     // When true, the position change will be animated
    var animationDuration: TimeInterval  // Duration of the animation when shouldAnimate is true
    var isAnimating: Bool       // Internal flag to track animation state
    
    public init(
        offsetX: Float = 0.0,
        offsetY: Float = 0.0,
        offsetZ: Float = 0.0,
        needsPositioning: Bool = true,
        shouldAnimate: Bool = false,
        animationDuration: TimeInterval = 0.5,
        isAnimating: Bool = false
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.offsetZ = offsetZ
        self.needsPositioning = needsPositioning
        self.shouldAnimate = shouldAnimate
        self.animationDuration = animationDuration
        self.isAnimating = isAnimating
    }
}
