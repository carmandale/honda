//
//  ImmersiveViewModel.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import Foundation
import RealityKit
import RealityKitContent
import SwiftUI

@Observable
@MainActor
final class IntroViewModel {
    // MARK: Properties
    var introRootEntity: Entity?
    var introEnvironment: Entity?
    var scene: RealityKit.Scene?
    
    // New flag to prevent duplicate environment loading
    var environmentLoaded = false
    
    // Dependencies
    var appModel: AppModel!
    
    // MARK: - State Flags
    // These flags control the flow of the head tracking and environment setup process
    
    // Root setup flags
    var isRootSetupComplete = false      // Set to true when root entity is created and configured
    var isEnvironmentSetupComplete = false // Set to true when environment is loaded (but not yet added to scene)
    var isHeadTrackingRootReady = false  // Set to true when root entity is ready for head tracking
    var shouldUpdateHeadPosition = false // Signal to start head position tracking
    var isPositioningComplete = false    // Set to true when head position tracking has completed
    var isPositioningInProgress = false  // Indicates head position tracking is currently in progress
    var isSetupComplete = false          // Set to true when the entire setup process is complete
    
    // This computed property determines if the system is ready for head tracking
    // All three conditions must be true for head tracking to proceed
    var isReadyForHeadTracking: Bool {
        isRootSetupComplete &&
        isEnvironmentSetupComplete &&
        isHeadTrackingRootReady
    }
    
    // MARK: - Setup Methods
    
    /// Sets up the root entity with positioning component
    /// This is the first step in the process flow
    func setupRoot() -> Entity {
        Logger.debug("""
        
        === INTRO ROOT SETUP in IntroViewModel ===
        ├─ Root Entity: \(introRootEntity != nil)
        ├─ Scene Ready: \(scene != nil)
        └─ Environment Loaded: \(environmentLoaded)
        """)
        
        // Reset state tracking first to ensure clean state
        isRootSetupComplete = false
        isEnvironmentSetupComplete = false
        isHeadTrackingRootReady = false
        isPositioningComplete = false
        isPositioningInProgress = false  // Reset positioning progress state
        
        Logger.info("🔄 Starting new intro session: tracking states reset")
        Logger.info("📱 IntroViewModel: Setting up root")
        
        let root = Entity()
        root.name = "IntroRoot"
        root.position = AppModel.PositioningDefaults.intro.position
        
        // Add positioning component to enable head tracking
        // This component will be used by the PositioningSystem to position the entity
        // relative to the user's head position
        root.components.set(PositioningComponent(
            offsetX: 0,
            offsetY: -1.5,  // Maintain intro's specific offset
            offsetZ: -1.0,
            needsPositioning: false, // Initially false, will be set to true when head tracking starts
            shouldAnimate: false,    // Initially false, will be set to true when head tracking starts
            animationDuration: 0.0   // Initially 0, will be set when head tracking starts
        ))
        
        // Only log success after validation
        guard root.components[PositioningComponent.self] != nil else {
            Logger.error("""
            
            ❌ ROOT SETUP FAILED in IntroViewModel
            └─ Error: Missing positioning component
            """)
            return root
        }
        
        // Store reference and update state flags
        introRootEntity = root
        isRootSetupComplete = true      // Mark root setup as complete
        isHeadTrackingRootReady = true  // Mark root as ready for head tracking
        
        Logger.debug("""
        
        === ✅ ROOT SETUP COMPLETE in IntroViewModel ===
        ├─ Entity Name: \(root.name)
        ├─ Position: \(root.position)
        └─ Has Positioning: true
        """)
        
        return root
    }
    
    // MARK: - Setup Environment
    
    /// Loads the environment entity but does NOT add it to the scene yet
    /// This is the second step in the process flow
    /// The environment will only be added to the root after positioning is complete
    func setupEnvironment(in root: Entity) async {
        Logger.debug("""
        
        === ENVIRONMENT SETUP in IntroViewModel ===
        ├─ Root Entity: \(introRootEntity?.name ?? "nil")
        ├─ Environment Loaded: \(environmentLoaded)
        └─ Environment Setup Complete: \(isEnvironmentSetupComplete)
        """)
        
        do {
            // Load the environment entity from RealityKit content
            let environment = try await Entity(named: "Immersive", in: realityKitContentBundle)
            
            // Store reference but DON'T add to root yet
            // This is a critical part of the design - we only add the environment
            // after the root entity has been positioned correctly
            introEnvironment = environment
            
            Logger.debug("""
            ✅ Loaded environment entity
            ├─ Name: \(environment.name)
            ├─ Children: \(environment.children.count)
            └─ Components: \(environment.components.count)
            """)
            
            // Set completion flag after environment is loaded
            // Note: We're NOT adding it to the root yet - that happens after positioning
            // This allows head tracking to proceed while delaying the actual addition
            isEnvironmentSetupComplete = true
            environmentLoaded = true
            
            Logger.debug("""
            
            === ✅ ENVIRONMENT SETUP COMPLETE in IntroViewModel ===
            ├─ Environment Entity: \(environment.name)
            ├─ Environment Loaded: \(environmentLoaded)
            ├─ Environment Setup Complete: \(isEnvironmentSetupComplete)
            ├─ Root Setup Complete: \(isRootSetupComplete)
            ├─ Head Tracking Ready: \(isHeadTrackingRootReady)
            └─ Ready for Head Tracking: \(isReadyForHeadTracking)
            """)
            
        } catch {
            Logger.error("""
            
            ❌ ENVIRONMENT SETUP FAILED in IntroViewModel
            └─ Error: \(error)
            """)
        }
    }
    
    // MARK: - Cleanup Methods
    
    /// Properly cleans up all entities and resets state
    /// This is essential to prevent issues when reusing the immersive space
    func cleanup() {
        Logger.debug("\n=== CLEANUP STARTED in IntroViewModel ===")
        
        // Important: Stop any ongoing tasks first
        Task { @MainActor in
            // Cancel any pending animations or tasks
            isPositioningInProgress = false
            shouldUpdateHeadPosition = false
            
            // Properly remove entities from the hierarchy
            if let rootEntity = introRootEntity {
                // Remove all children to ensure proper cleanup
                for child in rootEntity.children {
                    rootEntity.removeChild(child)
                }
                
                // Specifically handle environment entity
                if let environment = introEnvironment {
                    if environment.parent == rootEntity {
                        rootEntity.removeChild(environment)
                    }
                    // Remove any components that might cause issues on reinit
                    environment.components.removeAll()
                }
                

            }
            
            // Release entity references
            introEnvironment = nil
            introRootEntity = nil
            
            // Clear scene reference
            scene = nil
            
            // Reset all state flags to ensure clean state for next session
            isRootSetupComplete = false
            isEnvironmentSetupComplete = false
            isHeadTrackingRootReady = false
            isPositioningComplete = false
            isPositioningInProgress = false
            isSetupComplete = false
            environmentLoaded = false
            
            // Ensure we reset the head tracking state
            shouldUpdateHeadPosition = false
            
            Logger.debug("""
            === ✅ CLEANUP COMPLETE in IntroViewModel ===
            ├─ All state flags reset
            ├─ Entity references cleared
            ├─ Components removed
            └─ Ready for next immersive session
            """)
        }
    }
}
