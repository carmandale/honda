//
//  hondaApp.swift
//  honda
//
//  Created by Dale Carman on 2/26/25.
//

import SwiftUI

@main
struct hondaApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup(id: AppModel.mainWindowId) {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            IntroView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
