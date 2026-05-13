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

    @StateObject private var queryService: CloudXRQueryService

    init() {
        CloudXRKit.registerSystems()

        // Load environment configuration
        EnvironmentConfig.shared.debugPrint()

        // Initialize Firebase query service with environment config
        let (projectId, apiKey) = EnvironmentConfig.firebase

        _queryService = StateObject(wrappedValue: CloudXRQueryService(
            projectId: projectId,
            apiKey: apiKey
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(cxrSession)
        .environmentObject(queryService)

        WindowGroup(id: "queries") {
            QueryView()
                .environmentObject(queryService)
        }

        ImmersiveSpace(id: streamingSpaceTitle) {
            ImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .environment(cxrSession)
    }
}
