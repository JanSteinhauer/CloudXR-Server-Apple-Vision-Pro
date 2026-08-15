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
    @StateObject private var conditionService: ExperimentConditionService
    @StateObject private var eventLog: SessionEventLog

    init() {
        CloudXRKit.registerSystems()

        // Load environment configuration
        EnvironmentConfig.shared.debugPrint()

        // Initialize Firebase query service with environment config (with fallback empty values)
        let (projectId, apiKey) = EnvironmentConfig.firebase
        let resolvedProjectId = projectId.isEmpty ? "default-project" : projectId
        let resolvedApiKey = apiKey.isEmpty ? "default-key" : apiKey

        _queryService = StateObject(wrappedValue: CloudXRQueryService(
            projectId: resolvedProjectId,
            apiKey: resolvedApiKey
        ))

        _syncService = StateObject(wrappedValue: PrototypeSyncService(
            projectId: resolvedProjectId,
            apiKey: resolvedApiKey
        ))

        // Built together so every logged event can be stamped with the condition
        // that was live when it happened.
        let condition = ExperimentConditionService(
            projectId: resolvedProjectId,
            apiKey: resolvedApiKey
        )
        let log = SessionEventLog(
            projectId: resolvedProjectId,
            apiKey: resolvedApiKey
        )
        log.conditionService = condition

        _conditionService = StateObject(wrappedValue: condition)
        _eventLog = StateObject(wrappedValue: log)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncService)
                .environmentObject(conditionService)
                .environmentObject(eventLog)
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
                .environmentObject(conditionService)
                .environmentObject(eventLog)
        }
        .defaultSize(width: 480, height: 720)

        WindowGroup(id: "task", for: TaskID.self) { $taskID in
            TaskWindowView(taskID: taskID ?? .task1A)
                .environment(appModel)
                .environmentObject(conditionService)
                .environmentObject(eventLog)
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
