//
//  ImmersiveView.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    
    @State private var introTintIntensity: Double = 0.2 {
        didSet {
            Logger.debug("introTintIntensity changed to: \(introTintIntensity)")
            // Consider adding a breakpoint here to inspect the call stack
        }
    }
    
    @State private var showNavToggle: Bool = true
    
    var surroundingsEffect: SurroundingsEffect? {
        let tintColor = Color(red: introTintIntensity, green: introTintIntensity, blue: introTintIntensity)
        return SurroundingsEffect.colorMultiply(tintColor)
    }

    @State var handTrackedEntity: Entity = {
        let handAnchor = AnchorEntity(.hand(.left, location: .aboveHand))
        return handAnchor
    }()
    
    // Handle head position update
    private func handleHeadPositionUpdate() {
        if let root = appModel.introState.introRootEntity {
            Task { @MainActor in
                Logger.info("\n=== Head Position Update Started ===")
                
                // Set positioning state first
                appModel.introState.isPositioningInProgress = true
                
                // Update positioning component
                if var positioningComponent = root.components[PositioningComponent.self] {
                    positioningComponent.needsPositioning = true
                    positioningComponent.shouldAnimate = true
                    positioningComponent.animationDuration = 0.5
                    root.components[PositioningComponent.self] = positioningComponent
                    
                    // Wait for animation plus a small buffer
                    try? await Task.sleep(for: .seconds(0.6))
                    
                    // Reset states
                    appModel.introState.shouldUpdateHeadPosition = false
                    appModel.introState.isPositioningComplete = true
                    appModel.introState.isPositioningInProgress = false
                }
            }
        }
    }

    var body: some View {
        RealityView { content, attachments in
            Logger.debug("=== Setting up IntroView ===")

            // Create fresh root entity
            let root = appModel.introState.setupRoot()
            content.add(root)
            Logger.debug("✅ Added root to content")
            
            if showNavToggle {
                content.add(handTrackedEntity)
                if let attachmentEntity = attachments.entity(for: "navToggle") {
                    attachmentEntity.components[BillboardComponent.self] = .init()
                    handTrackedEntity.addChild(attachmentEntity)
                }
            }
            
            // Store root entity reference
            appModel.introState.introRootEntity = root
            
            // Handle environment and attachments in Task
            Task { @MainActor in
                // Load environment first
                Logger.debug("📱 Starting environment setup")
                await appModel.introState.setupEnvironment(in: root)
                
                appModel.introState.environmentLoaded = true
                Logger.info("\n=== Environment Setup Complete ===")
                Logger.info("""
                ✨ Environment Details
                ├─ Phase: \(appModel.currentPhase)
                ├─ Root Entity: \(root.name)
                └─ Environment: \(appModel.introState.introEnvironment?.name ?? "")
                """)
            }
            
        } attachments: {
            if showNavToggle {
                Attachment(id: "navToggle") {
                    ToggleImmersiveSpaceButton()
                }
            }
        }
        // Add head position update handler
        .onChange(of: appModel.introState.shouldUpdateHeadPosition) { _, shouldUpdate in
            if shouldUpdate {
                // Log any blocking conditions
                if !appModel.introState.isReadyForHeadTracking || appModel.introState.isPositioningInProgress {
                    Logger.debug("""
                    🎯 Head Position Update Blocked
                    └─ Reason: \(!appModel.introState.isReadyForHeadTracking ? "Not ready for tracking" : "Positioning in progress")
                    """)
                    
                    // Wait 0.5 seconds and retry
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        // Retry the update if conditions are now favorable
                        if appModel.introState.isReadyForHeadTracking && !appModel.introState.isPositioningInProgress {
                            Logger.info("🎯 Head Position Update Retry Successful")
                            // Trigger the update logic
                            handleHeadPositionUpdate()
                        } else {
                            Logger.debug("🎯 Head Position Update Retry Failed - Still Blocked")
                        }
                    }
                } else {
                    Logger.info("🎯 Head Position Update Ready")
                    handleHeadPositionUpdate()
                }
            }
        }
        // Add positioning completion handler
        .onChange(of: appModel.introState.isPositioningComplete) { _, complete in
            if complete {
                Task { @MainActor in
                    if let root = appModel.introState.introRootEntity,
                       let environment = appModel.introState.introEnvironment {
                        Logger.info("""
                        ✨ Positioning Complete
                        ├─ Phase: \(appModel.currentPhase)
                        ├─ ImmersiveSpaceState: \(appModel.immersiveSpaceState)
                        ├─ Root Entity: \(root.name)
                        └─ Environment Ready: \(environment.name)
                        """)
                        
                        // Now add environment to scene
                        root.addChild(environment)
                        
                        // Small delay to ensure everything is settled
                        try? await Task.sleep(for: .seconds(0.3))
                        
                        // Set setup complete before starting animation
                        appModel.introState.isSetupComplete = true
                        
                        // Reset positioning flag before starting animation
                        appModel.introState.isPositioningInProgress = false

                        // Move the steering wheel to the center of the scene
//                        Logger.debug("🔍 Attempting to find SteeringWheel entity")
//                        if let steeringWheel = root.findEntity(named: "SteeringWheel") {
//                            let startPosition = steeringWheel.position
//                            Logger.debug("✅ SteeringWheel entity found at position: \(startPosition)")
//                            Logger.debug("✅ SteeringWheel parent: \(steeringWheel.parent?.name ?? "none"), isEnabled: \(steeringWheel.isEnabled)")
//                            
//                            // Using a relative movement value
//                            let relativeMovement = SIMD3<Float>(0.425, 0.0, 0.0)
//                            Logger.debug("🎬 Moving SteeringWheel by \(relativeMovement)")
//                            
//                            Task {
//                                // Use your existing animatePosition which already handles relative movement
//                                await steeringWheel.animatePosition(to: relativeMovement, duration: 1.5, waitForCompletion: true)
//                                
//                                // Check final position after animation
//                                let endPosition = steeringWheel.position
//                                Logger.debug("✅ SteeringWheel animation completed")
//                                Logger.debug("   - Start position: \(startPosition)")
//                                Logger.debug("   - Expected end position: \(SIMD3<Float>(startPosition.x + relativeMovement.x, startPosition.y + relativeMovement.y, startPosition.z + relativeMovement.z))")
//                                Logger.debug("   - Actual end position: \(endPosition)")
//                                
//                                // Check if position actually changed
//                                if endPosition != startPosition {
//                                    Logger.debug("✓ Position changed successfully")
//                                } else {
//                                    Logger.warning("⚠️ Position did not change!")
//                                }
//                            }
//                        } else {
//                            Logger.warning("❌ SteeringWheel entity not found in scene")
//                        }
                    }
                }
            }
        }
    }
}

//#Preview(immersionStyle: .mixed) {
//    ImmersiveView()
//        .environment(AppModel())
//}
