# Head Tracking Troubleshooting Guide

## Common Issues and Solutions

### Issue: Head Tracking Not Starting

**Symptoms:**
- Log shows "Head Position Update Blocked" with reason "Not ready for tracking"
- Environment doesn't position correctly relative to user

**Possible Causes and Solutions:**

1. **State Flags Not Set Correctly**
   
   Check the logs for the state of these flags:
   ```
   isRootSetupComplete
   isEnvironmentSetupComplete
   isHeadTrackingRootReady
   ```
   
   All three must be `true` for `isReadyForHeadTracking` to be true.
   
   **Solution:** Ensure all setup methods properly set their respective flags.

2. **Environment Loading Failed**
   
   If the environment fails to load, `isEnvironmentSetupComplete` won't be set.
   
   **Solution:** Check for errors in the environment loading process:
   ```
   ❌ ENVIRONMENT SETUP FAILED in IntroViewModel
   ```

3. **Timing Issues**
   
   The head tracking request might be happening before setup is complete.
   
   **Solution:** The retry mechanism should handle this, but check if the second retry is occurring:
   ```
   🎯 Head Position Update Second Retry Successful
   ```

### Issue: Environment Appears in Wrong Position

**Symptoms:**
- Environment appears but is not correctly positioned
- Environment visibly moves after appearing

**Possible Causes and Solutions:**

1. **Environment Added Too Early**
   
   The environment might be added to the root before positioning is complete.
   
   **Solution:** Ensure the environment is only added in the `isPositioningComplete` handler.

2. **Positioning Component Issues**
   
   The positioning component might not be set correctly or might have invalid offsets.
   
   **Solution:** Check the positioning component values in the logs:
   ```
   🎯 Updating positioning component
   ├─ Current Needs Positioning: ...
   ├─ Current Should Animate: ...
   └─ Current Animation Duration: ...
   ```

3. **World Tracking Provider Not Running**
   
   The world tracking provider might not be in the running state.
   
   **Solution:** Check if the PositioningSystem is receiving valid device anchors.

### Issue: Environment Not Appearing At All

**Symptoms:**
- No environment visible after head tracking completes
- Logs show positioning is complete but no environment

**Possible Causes and Solutions:**

1. **Environment Reference Lost**
   
   The reference to the environment entity might be lost.
   
   **Solution:** Check if `introEnvironment` is non-nil when positioning completes.

2. **Environment Not Added to Root**
   
   The code to add the environment to the root might not be executing.
   
   **Solution:** Add explicit logging when adding the environment:
   ```
   Logger.info("🌍 Adding environment to positioned root")
   root.addChild(environment)
   ```

3. **Environment Entity Issues**
   
   The environment entity might have issues (e.g., no geometry).
   
   **Solution:** Check the environment entity properties in the logs.

### Issue: Positioning Animation Not Smooth

**Symptoms:**
- Environment appears but moves in a jerky manner
- Positioning doesn't feel natural

**Possible Causes and Solutions:**

1. **Animation Duration Too Short**
   
   The animation might be too quick to appear smooth.
   
   **Solution:** Increase the animation duration:
   ```swift
   positioningComponent.animationDuration = 1.0 // Increase from 0.5
   ```

2. **Animation Timing Function Issues**
   
   The timing function might not be appropriate.
   
   **Solution:** Use a more appropriate timing function in the PositioningSystem.

### Issue: Multiple Environment Instances

**Symptoms:**
- Multiple copies of the environment appear
- Performance issues due to duplicate content

**Possible Causes and Solutions:**

1. **Cleanup Not Properly Executed**
   
   Previous instances might not be properly removed.
   
   **Solution:** Ensure the cleanup method is called and properly removes all entities.

2. **Multiple Addition Attempts**
   
   The environment might be added multiple times.
   
   **Solution:** Add a check to prevent multiple additions:
   ```swift
   if environment.parent == nil {
       root.addChild(environment)
   }
   ```

## Debugging with Logs

The extensive logging system can help diagnose issues. Look for these key log patterns:

### Setup Phase
```
=== INTRO ROOT SETUP in IntroViewModel ===
...
=== ✅ ROOT SETUP COMPLETE in IntroViewModel ===
...
=== ENVIRONMENT SETUP in IntroViewModel ===
...
=== ✅ ENVIRONMENT SETUP COMPLETE in IntroViewModel ===
```

### Head Tracking Phase
```
🎯 Head Position Update Blocked
...
🎯 Head Position Update Retry Successful
...
=== Head Position Update Started ===
...
✅ Head Position Update Complete
```

### Environment Addition Phase
```
=== ✨ Positioning Complete ===
...
🌍 Adding environment to positioned root
...
=== ✅ Setup Complete ===
```

### Cleanup Phase
```
=== CLEANUP STARTED in IntroViewModel ===
...
=== ✅ CLEANUP COMPLETE in IntroViewModel ===
```

## Advanced Debugging

For more complex issues, consider these advanced debugging techniques:

1. **Add Temporary Visual Indicators**
   
   Add simple geometric shapes to visualize positioning:
   ```swift
   let debugSphere = ModelEntity(mesh: .generateSphere(radius: 0.05))
   debugSphere.model?.materials = [SimpleMaterial(color: .red, isMetallic: false)]
   root.addChild(debugSphere)
   ```

2. **Print Device Position Data**
   
   Log the raw device position data:
   ```swift
   let devicePosition = deviceAnchor.originFromAnchorTransform.translation()
   Logger.debug("Device Position: \(devicePosition)")
   ```

3. **Test with Fixed Positions**
   
   Temporarily bypass head tracking with fixed positions:
   ```swift
   // Instead of using device position
   let fixedPosition = SIMD3<Float>(0, 0, -1.0)
   entity.setPosition(fixedPosition, relativeTo: nil)
   ```

4. **Check Component Lifecycle**
   
   Verify that components are being properly added and removed:
   ```swift
   Logger.debug("Entity components: \(entity.components.keys.map { String(describing: $0) })")
   ```

## Performance Considerations

If experiencing performance issues during head tracking:

1. **Reduce Animation Complexity**
   
   Simplify animations during the positioning phase.

2. **Optimize Environment Loading**
   
   Consider loading the environment asynchronously or in parts.

3. **Minimize State Changes**
   
   Reduce the number of state changes and property updates during critical phases. 