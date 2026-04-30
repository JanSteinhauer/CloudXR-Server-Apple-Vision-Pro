//
//  ImmersiveView.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 19.04.26.
//

import SwiftUI
import RealityKit

import CloudXRKit

let streamingSpaceTitle = "CxrStreamingImmersiveSpace"

struct ImmersiveView: View {

    @Environment(CloudXRSession.self) var cxrSession
    @State private var sessionEntity = Entity()

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
        }
    }
}
