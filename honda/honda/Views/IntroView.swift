//
//  ImmersiveView.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct IntroView: View {
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
                Logger.info("""
                
                === Head Position Update Started ===
                ├─ Root Entity: \(root.name)
                ├─ Root Position: \(root.position)
                ├─ Has Positioning Component: \(root.components[PositioningComponent.self] != nil)
                └─ Environment Loaded: \(appModel.introState.environmentLoaded)
                """)
                
                // Set positioning state first to prevent concurrent positioning attempts
                appModel.introState.isPositioningInProgress = true
                
                // Update positioning component
                if var positioningComponent = root.components[PositioningComponent.self] {
                    Logger.info("""
                    🎯 Updating positioning component
                    ├─ Current Needs Positioning: \(positioningComponent.needsPositioning)
                    ├─ Current Should Animate: \(positioningComponent.shouldAnimate)
                    └─ Current Animation Duration: \(positioningComponent.animationDuration)
                    """)
                    
                    // Set the component properties to trigger positioning in the PositioningSystem
                    // The PositioningSystem looks for entities with needsPositioning=true
                    positioningComponent.needsPositioning = true
                    positioningComponent.shouldAnimate = true
                    positioningComponent.animationDuration = 0.5
                    root.components[PositioningComponent.self] = positioningComponent
                    
                    Logger.info("⏳ Waiting for positioning animation to complete...")
                    
                    // Wait for animation plus a small buffer
                    // This ensures the positioning animation has time to complete
                    try? await Task.sleep(for: .seconds(0.6))
                    
                    // Reset states after positioning is complete
                    // isPositioningComplete=true will trigger the environment addition
                    appModel.introState.shouldUpdateHeadPosition = false
                    appModel.introState.isPositioningComplete = true
                    appModel.introState.isPositioningInProgress = false
                    
                    Logger.info("""
                    ✅ Head Position Update Complete
                    └─ New Root Position: \(root.position)
                    """)
                } else {
                    Logger.error("❌ No positioning component found on root entity")
                    // Reset states even if positioning failed
                    appModel.introState.shouldUpdateHeadPosition = false
                    appModel.introState.isPositioningInProgress = false
                }
            }
        } else {
            Logger.error("❌ Cannot update head position: Root entity is nil")
        }
    }

    var body: some View {
        RealityView { content, attachments in
            Logger.debug("=== Setting up IntroView ===")

            // Create fresh root entity
            // This is the first step in the process flow
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
                // Load environment first - this is the second step in the process flow
                // Note: The environment is loaded but NOT added to the scene yet
                Logger.debug("📱 Starting environment setup")
                await appModel.introState.setupEnvironment(in: root)
                
                // Log environment setup completion
                Logger.info("""
                
                === Environment Setup Complete ===
                ✨ Environment Details
                ├─ Phase: \(appModel.currentPhase)
                ├─ Root Entity: \(root.name)
                ├─ Environment: \(appModel.introState.introEnvironment?.name ?? "nil")
                ├─ Environment Loaded: \(appModel.introState.environmentLoaded)
                ├─ Environment Setup Complete: \(appModel.introState.isEnvironmentSetupComplete)
                ├─ Root Setup Complete: \(appModel.introState.isRootSetupComplete)
                ├─ Head Tracking Ready: \(appModel.introState.isHeadTrackingRootReady)
                └─ Ready for Head Tracking: \(appModel.introState.isReadyForHeadTracking)
                """)
                
                // Now that environment is loaded (but not added), check if we should update head position
                // This is the third step in the process flow
                if appModel.introState.shouldUpdateHeadPosition && appModel.introState.isReadyForHeadTracking {
                    Logger.info("🎯 Environment loaded and ready for tracking, triggering head position update")
                    handleHeadPositionUpdate()
                } else if appModel.introState.shouldUpdateHeadPosition {
                    Logger.info("""
                    🎯 Head tracking requested but not ready yet
                    ├─ Root Setup: \(appModel.introState.isRootSetupComplete)
                    ├─ Environment Setup: \(appModel.introState.isEnvironmentSetupComplete)
                    └─ Head Tracking Ready: \(appModel.introState.isHeadTrackingRootReady)
                    """)
                }
            }
        } attachments: {
            if showNavToggle {
                Attachment(id: "navToggle") {
                    ToggleImmersiveSpaceButton()
                }
            }
        }
        // Add head position update handler
        // This onChange handler monitors the shouldUpdateHeadPosition flag
        // and triggers head tracking when appropriate
        .onChange(of: appModel.introState.shouldUpdateHeadPosition) { _, shouldUpdate in
            if shouldUpdate {
                // Log any blocking conditions
                if !appModel.introState.isReadyForHeadTracking || appModel.introState.isPositioningInProgress {
                    let reason = !appModel.introState.isReadyForHeadTracking ? "Not ready for tracking" : "Positioning in progress"
                    let details = !appModel.introState.isReadyForHeadTracking ? 
                        """
                        ├─ Root Setup: \(appModel.introState.isRootSetupComplete)
                        ├─ Environment Setup: \(appModel.introState.isEnvironmentSetupComplete)
                        └─ Head Tracking Ready: \(appModel.introState.isHeadTrackingRootReady)
                        """ : "└─ Positioning in progress"
                    
                    Logger.debug("""
                    🎯 Head Position Update Blocked
                    └─ Reason: \(reason)
                    \(details)
                    """)
                    
                    // Wait 0.5 seconds and retry
                    // This retry mechanism handles timing issues where components
                    // might not be ready when head tracking is first requested
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        // Retry the update if conditions are now favorable
                        if appModel.introState.isReadyForHeadTracking && !appModel.introState.isPositioningInProgress {
                            Logger.info("🎯 Head Position Update Retry Successful")
                            // Trigger the update logic
                            handleHeadPositionUpdate()
                        } else {
                            Logger.debug("🎯 Head Position Update Retry Failed - Still Blocked")
                            
                            // If still blocked after retry, check again in 1 second
                            // This second retry helps with cases where environment setup takes longer
                            try? await Task.sleep(for: .seconds(1.0))
                            if appModel.introState.isReadyForHeadTracking && !appModel.introState.isPositioningInProgress {
                                Logger.info("🎯 Head Position Update Second Retry Successful")
                                handleHeadPositionUpdate()
                            }
                        }
                    }
                } else {
                    Logger.info("🎯 Head Position Update Ready")
                    handleHeadPositionUpdate()
                }
            }
        }
        // Add positioning completion handler
        // This onChange handler monitors the isPositioningComplete flag
        // and adds the environment to the scene when positioning is complete
        // This is the fourth and final step in the process flow
        .onChange(of: appModel.introState.isPositioningComplete) { _, complete in
            if complete {
                Task { @MainActor in
                    if let root = appModel.introState.introRootEntity,
                       let environment = appModel.introState.introEnvironment {
                        Logger.info("""
                        
                        === ✨ Positioning Complete ===
                        ├─ Phase: \(appModel.currentPhase)
                        ├─ ImmersiveSpaceState: \(appModel.immersiveSpaceState)
                        ├─ Root Entity: \(root.name)
                        ├─ Root Position: \(root.position)
                        └─ Environment Ready: \(environment.name)
                        """)
                        
                        // NOW we add the environment to the root
                        // This happens only after positioning is complete
                        // This is a critical part of the design - we only add the environment
                        // after the root entity has been positioned correctly
                        // This ensures the environment appears in the correct position from the start
                        Logger.info("🌍 Adding environment to positioned root")
                        root.addChild(environment)
                        
                        // Small delay to ensure everything is settled
                        try? await Task.sleep(for: .seconds(0.3))
                        
                        // Set setup complete before starting animation
                        appModel.introState.isSetupComplete = true
                        
                        // Reset positioning flag before starting animation
                        appModel.introState.isPositioningInProgress = false
                        
                        Logger.info("""
                        
                        === ✅ Setup Complete ===
                        ├─ Environment Added: true
                        ├─ Root Position: \(root.position)
                        └─ Environment Position: \(environment.position(relativeTo: root))
                        """)
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
