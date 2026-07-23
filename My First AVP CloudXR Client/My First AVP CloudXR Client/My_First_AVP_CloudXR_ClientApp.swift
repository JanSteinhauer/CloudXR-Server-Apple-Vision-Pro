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

    @State private var appModel = AppModel()

    @StateObject private var queryService: CloudXRQueryService
    @StateObject private var syncService: PrototypeSyncService

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

        _syncService = StateObject(wrappedValue: PrototypeSyncService(
            projectId: projectId.isEmpty ? "default-project" : projectId,
            apiKey: apiKey.isEmpty ? "default-key" : apiKey
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncService)
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

        WindowGroup(id: "taskMaster") {
            TaskMasterView()
                .environment(appModel)
        }
        .defaultSize(width: 480, height: 720)

        WindowGroup(id: "task", for: TaskID.self) { $taskID in
            TaskWindowView(taskID: taskID ?? .task1A)
                .environment(appModel)
        }
        .defaultSize(width: 1200, height: 820)

        ImmersiveSpace(id: streamingSpaceTitle) {
            ImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .environment(cxrSession)
        .environment(objectTrackingManager)
    }
}
