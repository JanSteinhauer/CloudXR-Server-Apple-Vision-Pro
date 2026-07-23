//
//  ImmersiveView.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 19.04.26.
//

import SwiftUI
import RealityKit
import ARKit

import CloudXRKit

let streamingSpaceTitle = "CxrStreamingImmersiveSpace"

struct ImmersiveView: View {

    @Environment(CloudXRSession.self) var cxrSession
    @Environment(ObjectTrackingManager.self) var objectTrackingManager

    @State private var sessionEntity = Entity()
    @State private var root = Entity()
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    @State private var spatialAnchorFirestore = SpatialAnchorFirestore()

    var body: some View {
        RealityView { content in
            sessionEntity.name = "Session"

            // Just a quick check; this View shouldn't be opened unless we're connected.
            if cxrSession.state != .connected {
                print("Oops, we shouldn't be trying to render CloudXR without being connected!")
            }

            sessionEntity.components[CloudXRSessionComponent.self] = .init(session: cxrSession)
            sessionEntity.transform = .init()
            content.add(sessionEntity)

            // Add root entity for object tracking visualizations
            content.add(root)

            // Start object tracking
            Task {
                let objectTracking = await objectTrackingManager.startTracking()
                guard let objectTracking else {
                    print("Failed to start object tracking")
                    return
                }

                print("✅ Object tracking started successfully")

                // Listen for anchor updates
                for await anchorUpdate in objectTracking.anchorUpdates {
                    let anchor = anchorUpdate.anchor
                    let id = anchor.id

                    switch anchorUpdate.event {
                    case .added:
                        print("🎯 Object detected: \(anchor.referenceObject.name)")
                        let model = objectTrackingManager.referenceObjectLoader.usdzsPerReferenceObjectID[anchor.referenceObject.id]
                        let visualization = ObjectAnchorVisualization(for: anchor, withModel: model)
                        self.objectVisualizations[id] = visualization
                        root.addChild(visualization.entity)

                        // Save spatial anchor to Firestore (with current head pose)
                        let headPose = objectTrackingManager.currentHeadPose()
                        Task {
                            await spatialAnchorFirestore.saveObjectAnchor(anchor, headPose: headPose)
                        }

                    case .updated:
                        self.objectVisualizations[id]?.update(with: anchor)
                    case .removed:
                        print("❌ Object lost: \(anchor.referenceObject.name)")
                        self.objectVisualizations[id]?.entity.removeFromParent()
                        self.objectVisualizations.removeValue(forKey: id)
                    }
                }
            }
        }
        .onAppear() {
            objectTrackingManager.isImmersiveSpaceOpened = true
        }
        .onDisappear() {
            for (_, visualization) in objectVisualizations {
                root.removeChild(visualization.entity)
            }
            objectVisualizations.removeAll()
            objectTrackingManager.didLeaveImmersiveSpace()
        }
    }
}
