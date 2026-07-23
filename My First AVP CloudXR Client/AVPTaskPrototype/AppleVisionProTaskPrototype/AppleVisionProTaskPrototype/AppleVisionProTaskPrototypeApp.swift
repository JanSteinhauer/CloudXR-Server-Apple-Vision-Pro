//
//  AppleVisionProTaskPrototypeApp.swift
//  AppleVisionProTaskPrototype
//
//  Two scenes:
//   - "main" window: master window with the agent picker and task list.
//   - task window (parameterised by TaskID): one window per opened task.
//

import SwiftUI

@main
struct AppleVisionProTaskPrototypeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 480, height: 720)

        WindowGroup(id: "task", for: TaskID.self) { $taskID in
            TaskWindowView(taskID: taskID ?? .task1A)
                .environment(model)
        }
        .defaultSize(width: 1200, height: 820)
    }
}
