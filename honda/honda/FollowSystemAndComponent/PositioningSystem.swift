/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The system for following the device's position and updating the entity to move each time the scene rerenders.
*/

import Foundation
import RealityKit
import SwiftUI
import ARKit

/// A system that moves entities to the device's transform each time the scene rerenders.
/// This system is responsible for positioning entities based on the user's head position.
/// It works with entities that have a PositioningComponent attached.
@MainActor
public class PositioningSystem: System {
    // MARK: - Static Properties
    
    // Query to find all entities with a PositioningComponent
    static let query = EntityQuery(where: .has(PositioningComponent.self))
    private static var sharedAppModel: AppModel?
    private let systemId = UUID()
    
    // Static method to set AppModel
    // This must be called before the system can function properly
    static func setAppModel(_ appModel: AppModel) {
        Logger.debug("\n🔄 PositioningSystem.setAppModel called")
        sharedAppModel = appModel
    }
    
    // MARK: - System Initialization
    public required init(scene: RealityKit.Scene) {
        Logger.debug("\n🎯 PositioningSystem \(systemId) initializing...")
    }
    
    // MARK: - System Update
    // This method is called by RealityKit on each frame update
    // It handles the actual positioning of entities based on head position
    public func update(context: SceneUpdateContext) {
        // Get device anchor from TrackingSessionManager's worldTrackingProvider
        // This requires the AppModel to be set via setAppModel()
        guard let appModel = Self.sharedAppModel else {
            Logger.error("\n❌ PositioningSystem: Missing AppModel reference")
            return
        }
        
        // Skip silently if tracking isn't running or no device anchor available
        // This prevents errors when the world tracking provider isn't ready
        guard case .running = appModel.trackingManager.worldTrackingProvider.state,
              let deviceAnchor = appModel.trackingManager.worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }
        
        // Position entities that need positioning
        // This processes all entities with a PositioningComponent where needsPositioning=true
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Skip entities that don't need positioning or are already animating
            guard var positioningComponent = entity.components[PositioningComponent.self],
                  positioningComponent.needsPositioning,
                  !positioningComponent.isAnimating else { continue }
            
            Task {
                // Set animating state immediately to prevent concurrent positioning attempts
                positioningComponent.isAnimating = true
                entity.components[PositioningComponent.self] = positioningComponent
                
                // Try to position the entity based on the device anchor
                if await tryPositionEntity(entity: entity, component: &positioningComponent, deviceAnchor: deviceAnchor) {
                    // Wait for animation to complete if animation is enabled
                    if positioningComponent.shouldAnimate {
                        try? await Task.sleep(for: .seconds(positioningComponent.animationDuration))
                    }
                    
                    // Update final state after positioning is complete
                    // This resets the flags so the entity won't be positioned again
                    // unless needsPositioning is set to true again
                    positioningComponent.isAnimating = false
                    positioningComponent.needsPositioning = false
                    entity.components[PositioningComponent.self] = positioningComponent
                    
                    Logger.info("\n✨ Head Position Update Complete\n└─ Position: \(entity.position(relativeTo: nil))")
                }
            }
        }
    }
    
    // MARK: - Entity Positioning
    // This method handles the actual positioning logic
    // It calculates the target position based on the device position and component offsets
    private func tryPositionEntity(entity: Entity, component: inout PositioningComponent, deviceAnchor: DeviceAnchor) async -> Bool {
        // Get the device transform and position
        let deviceTransform = deviceAnchor.originFromAnchorTransform
        let devicePosition = deviceTransform.translation()
        
        // Validate translation values
        // These limits ensure the entity stays within a reasonable distance from the user
        let minValidDistance: Float = 0.3  // Minimum 0.3 meters from device
        let maxValidDistance: Float = 3.0   // Maximum 3 meters from device
        
        // Calculate distance from device
        let distance = sqrt(devicePosition.x * devicePosition.x + devicePosition.y * devicePosition.y + devicePosition.z * devicePosition.z)
        let isValid = distance >= minValidDistance && distance <= maxValidDistance
        
        // If the device position is invalid, abort positioning
        if !isValid {
            Logger.debug("\n⚠️ Invalid Position:\n└─ Distance: \(String(format: "%.2f", distance))m (valid: \(minValidDistance)-\(maxValidDistance)m)")
            return false
        }
        
        // Calculate the target position with offsets
        // This applies the component's offset values to the device position
        let targetPosition = SIMD3<Float>(
            devicePosition.x + component.offsetX,
            devicePosition.y + component.offsetY,
            devicePosition.z + component.offsetZ
        )
        
        // Calculate distance from device to target (including offsets)
        // This ensures the final position is within valid range
        let distanceFromDevice = length(targetPosition - devicePosition)
        
        // Validate and adjust position if needed
        // If the target position is too close or too far, adjust it to stay within valid range
        let finalPosition: SIMD3<Float>
        if distanceFromDevice < minValidDistance || distanceFromDevice > maxValidDistance {
            Logger.debug("\n⚠️ Invalid position detected for '\(entity.name)'\n└─ Distance from device: \(distanceFromDevice)m (valid: \(minValidDistance)-\(maxValidDistance)m)")
            
            // Calculate direction vector from device to target
            let direction = normalize(targetPosition - devicePosition)
            
            // Clamp distance to valid range
            let clampedDistance = simd_clamp(distanceFromDevice, minValidDistance, maxValidDistance)
            
            // Calculate new position at clamped distance
            finalPosition = devicePosition + (direction * clampedDistance)
            
            Logger.debug("\n✅ Adjusted to safe distance: \(clampedDistance)m")
        } else {
            finalPosition = targetPosition
        }
        
        // Apply the final position to the entity
        // If animation is enabled, animate to the position
        // Otherwise, set the position immediately
        if component.shouldAnimate {
            await entity.animateAbsolutePosition(
                to: finalPosition,
                duration: component.animationDuration,
                timing: .easeInOut,
                waitForCompletion: false
            )
        } else {
            entity.setPosition(finalPosition, relativeTo: nil)
        }
        
        return true
    }
}
