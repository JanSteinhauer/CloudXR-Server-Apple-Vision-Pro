//
//  My_First_AVP_CloudXR_ClientApp.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 19.04.26.
//

import SwiftUI

import CloudXRKit

@main
struct My_First_AVP_CloudXR_ClientApp: App {

    @State private var cxrSession = CloudXRSession(
        config: CloudXRKit.Config()
    )

    init() {
        CloudXRKit.registerSystems()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(cxrSession)

        ImmersiveSpace(id: streamingSpaceTitle) {
            ImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .environment(cxrSession)
    }
}
