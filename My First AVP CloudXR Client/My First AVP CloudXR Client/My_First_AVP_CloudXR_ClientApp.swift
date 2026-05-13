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

    @State private var objectTrackingManager = ObjectTrackingManager()

    @StateObject private var queryService: CloudXRQueryService

    init() {
        CloudXRKit.registerSystems()

        // Load environment configuration
        EnvironmentConfig.shared.debugPrint()

        // Initialize Firebase query service with environment config (with fallback empty values)
        let (projectId, apiKey) = EnvironmentConfig.firebase

        _queryService = StateObject(wrappedValue: CloudXRQueryService(
            projectId: projectId.isEmpty ? "default-project" : projectId,
            apiKey: apiKey.isEmpty ? "default-key" : apiKey
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request world sensing authorization for object tracking
                    await objectTrackingManager.requestWorldSensingAuthorization()

                    // Load reference objects
                    await objectTrackingManager.referenceObjectLoader.loadBuiltInReferenceObjects()

                    print("✅ Loaded \(objectTrackingManager.referenceObjectLoader.enabledReferenceObjectsCount) reference objects")

                    // Monitor ARKit session events
                    await objectTrackingManager.monitorSessionEvents()
                }
        }
        .environment(cxrSession)
        .environment(objectTrackingManager)
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
        .environment(objectTrackingManager)
    }
}
