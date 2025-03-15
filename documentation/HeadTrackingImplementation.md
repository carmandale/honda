# Head Tracking Technical Implementation

## Architecture

The head tracking and environment positioning system is built on several key components:

1. **IntroViewModel**: State management for the immersive experience
2. **IntroView**: SwiftUI view that manages the RealityKit content
3. **PositioningComponent**: Custom RealityKit component for positioning entities
4. **PositioningSystem**: RealityKit system that handles the positioning logic

## Key Classes and Methods

### IntroViewModel

```swift
@Observable
@MainActor
final class IntroViewModel {
    // State flags
    var isRootSetupComplete = false
    var isEnvironmentSetupComplete = false
    var isHeadTrackingRootReady = false
    var shouldUpdateHeadPosition = false
    var isPositioningComplete = false
    var isPositioningInProgress = false
    var isSetupComplete = false
    
    // Computed property for tracking readiness
    var isReadyForHeadTracking: Bool {
        isRootSetupComplete &&
        isEnvironmentSetupComplete &&
        isHeadTrackingRootReady
    }
    
    // Setup methods
    func setupRoot() -> Entity { ... }
    func setupEnvironment(in root: Entity) async { ... }
    func cleanup() { ... }
}
```

### IntroView

```swift
struct IntroView: View {
    // Head position update handler
    private func handleHeadPositionUpdate() { ... }
    
    var body: some View {
        RealityView { content, attachments in
            // Setup root and environment
        }
        .onChange(of: appModel.introState.shouldUpdateHeadPosition) { ... }
        .onChange(of: appModel.introState.isPositioningComplete) { ... }
    }
}
```

### PositioningComponent

```swift
struct PositioningComponent: Component {
    var offsetX: Float = 0
    var offsetY: Float = 0
    var offsetZ: Float = 0
    var needsPositioning: Bool = false
    var shouldAnimate: Bool = false
    var animationDuration: TimeInterval = 0.5
    var isAnimating: Bool = false
}
```

## Implementation Details

### Root Entity Setup

The root entity is created and configured with a PositioningComponent:

```swift
func setupRoot() -> Entity {
    let root = Entity()
    root.name = "IntroRoot"
    root.position = AppModel.PositioningDefaults.intro.position
    
    root.components.set(PositioningComponent(
        offsetX: 0,
        offsetY: -1.5,
        offsetZ: -1.0,
        needsPositioning: false,
        shouldAnimate: false,
        animationDuration: 0.0
    ))
    
    introRootEntity = root
    isRootSetupComplete = true
    isHeadTrackingRootReady = true
    
    return root
}
```

### Environment Loading

The environment is loaded but not added to the scene yet:

```swift
func setupEnvironment(in root: Entity) async {
    do {
        let environment = try await Entity(named: "Immersive", in: realityKitContentBundle)
        
        // Store reference but DON'T add to root yet
        introEnvironment = environment
        
        // Set completion flag after environment is loaded
        isEnvironmentSetupComplete = true
        environmentLoaded = true
    } catch {
        // Error handling
    }
}
```

### Head Position Tracking

The head position update is triggered when all conditions are met:

```swift
private func handleHeadPositionUpdate() {
    if let root = appModel.introState.introRootEntity {
        Task { @MainActor in
            // Set positioning state
            appModel.introState.isPositioningInProgress = true
            
            // Update positioning component
            if var positioningComponent = root.components[PositioningComponent.self] {
                positioningComponent.needsPositioning = true
                positioningComponent.shouldAnimate = true
                positioningComponent.animationDuration = 0.5
                root.components[PositioningComponent.self] = positioningComponent
                
                // Wait for animation
                try? await Task.sleep(for: .seconds(0.6))
                
                // Reset states
                appModel.introState.shouldUpdateHeadPosition = false
                appModel.introState.isPositioningComplete = true
                appModel.introState.isPositioningInProgress = false
            }
        }
    }
}
```

### Environment Addition

The environment is added to the root only after positioning is complete:

```swift
.onChange(of: appModel.introState.isPositioningComplete) { _, complete in
    if complete {
        Task { @MainActor in
            if let root = appModel.introState.introRootEntity,
               let environment = appModel.introState.introEnvironment {
                // NOW we add the environment to the root
                root.addChild(environment)
                
                // Set setup complete
                appModel.introState.isSetupComplete = true
            }
        }
    }
}
```

## PositioningSystem Implementation

The PositioningSystem is responsible for actually positioning entities based on the user's head position:

```swift
public func update(context: SceneUpdateContext) {
    // Get device anchor from world tracking provider
    guard let deviceAnchor = appModel.trackingManager.worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
        return
    }
    
    // Position entities that need positioning
    for entity in context.entities(matching: Self.query) {
        guard var positioningComponent = entity.components[PositioningComponent.self],
              positioningComponent.needsPositioning,
              !positioningComponent.isAnimating else { continue }
        
        // Calculate target position based on device position and offsets
        let devicePosition = deviceAnchor.originFromAnchorTransform.translation()
        let targetPosition = SIMD3<Float>(
            devicePosition.x + positioningComponent.offsetX,
            devicePosition.y + positioningComponent.offsetY,
            devicePosition.z + positioningComponent.offsetZ
        )
        
        // Animate or set position
        if positioningComponent.shouldAnimate {
            entity.animateAbsolutePosition(
                to: targetPosition,
                duration: positioningComponent.animationDuration
            )
        } else {
            entity.setPosition(targetPosition, relativeTo: nil)
        }
    }
}
```

## Retry Mechanism

To handle timing issues, a retry mechanism is implemented:

```swift
.onChange(of: appModel.introState.shouldUpdateHeadPosition) { _, shouldUpdate in
    if shouldUpdate {
        if !appModel.introState.isReadyForHeadTracking || appModel.introState.isPositioningInProgress {
            // Log blocking conditions
            
            // Wait and retry
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                if appModel.introState.isReadyForHeadTracking && !appModel.introState.isPositioningInProgress {
                    handleHeadPositionUpdate()
                } else {
                    // Second retry after longer delay
                    try? await Task.sleep(for: .seconds(1.0))
                    if appModel.introState.isReadyForHeadTracking && !appModel.introState.isPositioningInProgress {
                        handleHeadPositionUpdate()
                    }
                }
            }
        } else {
            handleHeadPositionUpdate()
        }
    }
}
```

## Cleanup Process

Proper cleanup is essential to prevent issues when reusing the immersive space:

```swift
func cleanup() {
    Task { @MainActor in
        // Cancel any ongoing tasks
        isPositioningInProgress = false
        shouldUpdateHeadPosition = false
        
        // Remove entities from hierarchy
        if let rootEntity = introRootEntity {
            for child in rootEntity.children {
                rootEntity.removeChild(child)
            }
            
            // Handle environment entity
            if let environment = introEnvironment {
                if environment.parent == rootEntity {
                    rootEntity.removeChild(environment)
                }
                environment.components.removeAll()
            }
        }
        
        // Release references and reset flags
        introEnvironment = nil
        introRootEntity = nil
        scene = nil
        
        // Reset all state flags
        isRootSetupComplete = false
        isEnvironmentSetupComplete = false
        isHeadTrackingRootReady = false
        isPositioningComplete = false
        isPositioningInProgress = false
        isSetupComplete = false
        environmentLoaded = false
        shouldUpdateHeadPosition = false
    }
}
```

## Best Practices

1. **State Management**: Use clear state flags to track progress
2. **Separation of Concerns**: Keep loading, positioning, and scene addition separate
3. **Comprehensive Logging**: Log each step for debugging
4. **Retry Mechanism**: Implement retries to handle timing issues
5. **Proper Cleanup**: Ensure all entities and components are properly cleaned up 