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
final class ImmersiveViewModel {
    // MARK: Properties
    var introRootEntity: Entity?
    var introEnvironment: Entity?
    var scene: RealityKit.Scene?
    
    // New flag to prevent duplicate environment loading
    var environmentLoaded = false
    
    // Dependencies
    var appModel: AppModel!
    
    // Root setup flags
    var isRootSetupComplete = false
    var isEnvironmentSetupComplete = false
    var isHeadTrackingRootReady = false
    var shouldUpdateHeadPosition = false
    var isPositioningComplete = false
    var isPositioningInProgress = false  // Add positioning progress flag
    var isSetupComplete = false
    
    var isReadyForHeadTracking: Bool {
        isRootSetupComplete &&
        isEnvironmentSetupComplete &&
        isHeadTrackingRootReady
    }
    
    // MARK: - Setup Methods
    func setupRoot() -> Entity {
        Logger.debug("""
        
        === INTRO ROOT SETUP in IntroViewModel ===
        ├─ Root Entity: \(introRootEntity != nil)
        ├─ Scene Ready: \(scene != nil)
        └─ Environment Loaded: \(environmentLoaded)
        """)
        
        // Reset state tracking first
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
        
        root.components.set(PositioningComponent(
            offsetX: 0,
            offsetY: -1.5,  // Maintain intro's specific offset
            offsetZ: -1.0,
            needsPositioning: false,
            shouldAnimate: false,
            animationDuration: 0.0
        ))
        
        // Only log success after validation
        guard root.components[PositioningComponent.self] != nil else {
            Logger.error("""
            
            ❌ ROOT SETUP FAILED in IntroViewModel
            └─ Error: Missing positioning component
            """)
            return root
        }
        
        introRootEntity = root
        isRootSetupComplete = true
        isHeadTrackingRootReady = true
        
        Logger.debug("""
        
        === ✅ ROOT SETUP COMPLETE in IntroViewModel ===
        ├─ Entity Name: \(root.name)
        ├─ Position: \(root.position)
        └─ Has Positioning: true
        """)
        
        return root
    }
    
    // MARK: - Setup Environment
    func setupEnvironment(in root: Entity) async {
        Logger.debug("\n=== ENVIRONMENT SETUP in IntroViewModel ===")
        
        var environment: Entity
        do {
            // Add the initial RealityKit content
            environment = try! await Entity(named: "Immersive", in: realityKitContentBundle)
//            root.addChild(environment)

            Logger.debug("✅ Loaded intro_environment")
            introEnvironment = environment
            
            isEnvironmentSetupComplete = true
            
            Logger.debug("\n=== ✅ ENVIRONMENT SETUP COMPLETE in IntroViewModel ===\n")
            
        } catch {
            Logger.error("""
            
            ❌ ENVIRONMENT SETUP FAILED in IntroViewModel
            └─ Error: \(error)
            """)
        }
    }
    
    // MARK: - Cleanup Methods
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
                
                // Remove all components from root that might cause issues on reinit
                var componentsToRemove = [ComponentType]()
                for componentName in rootEntity.components.names {
                    componentsToRemove.append(componentName)
                }
                
                for component in componentsToRemove {
                    rootEntity.components.remove(component)
                }
            }
            
            // Release entity references
            introEnvironment = nil
            introRootEntity = nil
            
            // Clear scene reference
            scene = nil
            
            // Reset all state flags
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
