//
//  ContentView.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var opacity: Double = 1.0
    
    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("Hello, world!")

            ToggleImmersiveSpaceButton()
        }
        .padding()
        .opacity(opacity)
        .onChange(of: appModel.immersiveSpaceState) { _, newState in
            if newState == .open {
                // Fade out then dismiss window
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 0
                } completion: {
                    dismissWindow(id: AppModel.mainWindowId)
                }
            }
        }
        .onAppear {
            // Fade in when window appears
            opacity = 0
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
