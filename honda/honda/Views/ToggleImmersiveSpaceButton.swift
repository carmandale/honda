//
//  ToggleImmersiveSpaceButton.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            Task { @MainActor in
                switch appModel.immersiveSpaceState {
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                        // Call the cleanup method to reset the immersive view state
                        appModel.introState.cleanup()
                        Logger.debug("🧹 Immersive space cleanup completed")
                        // Show the main window when immersive space is dismissed
                        openWindow(id: AppModel.mainWindowId)
                        // Don't set immersiveSpaceState to .closed because there
                        // are multiple paths to ImmersiveView.onDisappear().
                        // Only set .closed in ImmersiveView.onDisappear().

                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                            case .opened:
                                // Don't set immersiveSpaceState to .open because there
                                // may be multiple paths to ImmersiveView.onAppear().
                                // Only set .open in ImmersiveView.onAppear().
                                break

                            case .userCancelled, .error:
                                // On error, we need to mark the immersive space
                                // as closed because it failed to open.
                                fallthrough
                            @unknown default:
                                // On unknown response, assume space did not open.
                                appModel.immersiveSpaceState = .closed
                                // Show the main window if immersive space failed to open
                                openWindow(id: AppModel.mainWindowId)
                        }

                    case .inTransition:
                        // This case should not ever happen because button is disabled for this case.
                        break
                }
                Logger.info("\n📍 Positioning Requested: Starting head tracking")
                appModel.introState.shouldUpdateHeadPosition = true
                
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
