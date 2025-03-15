# Head Tracking and Environment Setup

## Overview

This document explains the head tracking and environment setup process in the Honda visionOS application. The implementation follows a specific sequence to ensure that content appears in the correct position relative to the user without visible movement after initial appearance.

## Key Components

- **IntroViewModel**: Manages the state of the immersive experience
- **IntroView**: Handles the visual representation and user interaction
- **PositioningComponent/System**: Handles the positioning of entities relative to the user's head position

## Process Flow

The process follows these key steps:

1. **Root Entity Setup**
2. **Environment Loading** (but not adding to scene yet)
3. **Head Position Tracking**
4. **Environment Addition** (only after positioning is complete)

### Detailed Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │     │                 │
│  Setup Root     │────▶│  Load           │────▶│  Position Root  │────▶│  Add Environment│
│  Entity         │     │  Environment    │     │  Entity         │     │  to Scene       │
│                 │     │                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

## State Flags

The system uses several state flags to track progress:

- `isRootSetupComplete`: Root entity has been created and configured
- `isEnvironmentSetupComplete`: Environment has been loaded (but not added to scene)
- `isHeadTrackingRootReady`: Root entity is ready for head tracking
- `shouldUpdateHeadPosition`: Signal to start head position tracking
- `isPositioningInProgress`: Head position tracking is currently in progress
- `isPositioningComplete`: Head position tracking has completed
- `isSetupComplete`: The entire setup process is complete

## Critical Implementation Detail

**Important**: The environment entity is loaded first but is NOT added to the root entity until after positioning is complete. This ensures that the environment appears in the correct position from the start, without visible movement.

## Code Flow

1. **Root Setup**:
   ```swift
   let root = appModel.introState.setupRoot()
   content.add(root)
   ```

2. **Environment Loading**:
   ```swift
   await appModel.introState.setupEnvironment(in: root)
   // Environment is loaded but NOT added to root yet
   isEnvironmentSetupComplete = true
   ```

3. **Head Position Tracking**:
   ```swift
   if appModel.introState.isReadyForHeadTracking {
       handleHeadPositionUpdate()
   }
   ```

4. **Environment Addition** (after positioning):
   ```swift
   if appModel.introState.isPositioningComplete {
       root.addChild(environment)
   }
   ```

## Troubleshooting

If head tracking is not working, check:

1. **State Flags**: Ensure all required flags are set correctly:
   ```
   isRootSetupComplete && isEnvironmentSetupComplete && isHeadTrackingRootReady
   ```

2. **Positioning Component**: Verify the root entity has a valid PositioningComponent

3. **Timing Issues**: The retry mechanism should handle most timing issues, but check logs for:
   - "Head Position Update Blocked"
   - "Head Position Update Retry Failed"

## Logging

The system includes comprehensive logging to track the state at each step:

- Root setup completion
- Environment loading
- Head tracking readiness
- Positioning progress
- Environment addition

Look for log entries with these prefixes:
- `===` for section headers
- `✅` for successful completions
- `❌` for errors
- `🎯` for head tracking events
- `🌍` for environment events

## Implementation Notes

This approach ensures that content appears in the correct position from the start, providing a better user experience by avoiding visible repositioning of content after it appears. 