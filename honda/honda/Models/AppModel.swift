//
//  AppModel.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

enum AppPhase: String, CaseIterable, Codable, Sendable, Equatable {
    case loading
    case ready
    case intro
    case completed
    case error
    
    var needsImmersiveSpace: Bool {
        return self != .loading && self != .error
    }
    
    var needsHandTracking: Bool {
        switch self {
        case .intro, .ready:
            return true
        case .loading, .completed, .error:
            return false
        }
    }
    
    var shouldKeepPreviousSpace: Bool {
        if self == .completed { return true }
        return false
    }
    
    var spaceId: String {
        switch self {
        case .intro: return AppModel.introSpaceId
        case .loading, .ready, .completed, .error: return ""
        }
    }
    
    var windowId: String {
        switch self {
        case .loading, .ready, .completed, .error: return AppModel.mainWindowId
        case .intro: return AppModel.introWindowId
        }
    }
}


/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    /// Current phase of the app
    var currentPhase: AppPhase = .loading
    
    let immersiveSpaceID = "ImmersiveSpace"
    nonisolated static let introSpaceId = "ImmersiveSpace"
    nonisolated static let mainWindowId = "ContentView"
    nonisolated static let introWindowId: String = "IntroWindow"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    enum PositioningDefaults {
        case intro

        var position: SIMD3<Float> {
            switch self {
            case .intro:    return SIMD3<Float>(0.0, -0.25, 0.25)
            }
        }
    }
    
    // MARK: - Global UI Settings
    enum UIConstants {
        // Button Dimensions
        static let buttonCornerRadius: CGFloat = 16
        static let buttonPaddingHorizontal: CGFloat = 24
        static let buttonPaddingVertical: CGFloat = 16
        static let buttonExpandScale: CGFloat = 1.1
        static let buttonPressScale: CGFloat = 0.85
        
        // Animation Durations
        static let buttonHoverDuration: CGFloat = 0.2
        static let buttonPressDuration: CGFloat = 0.3
    }
    
    var isNavWindowOpen = false
    var navWindowId = "NavWindow"
    
    var introState: ImmersiveViewModel
    let trackingManager = TrackingSessionManager()

    
    // MARK: Initialization
    init() {
        self.introState = ImmersiveViewModel()
        
        // Set up dependencies
        self.introState.appModel = self
        self.trackingManager.appModel = self  // Set the reference to AppModel
        
        Logger.debug("AppModel init() - Instance: \(ObjectIdentifier(self))")
    }
    
}
