//
//  ContentView.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 19.04.26.
//

import SwiftUI
import RealityKit
import RealityKitContent

import CloudXRKit

struct ContentView: View {

    @Environment(CloudXRSession.self) var cxrSession
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    // Configurable session settings.
    @AppStorage("ipAddress") static var ipAddress: String = ""
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset
    @AppStorage("enableHandTracking") private var enableHandTracking: Bool = true

    var body: some View {
        VStack {

            Form {
                HStack {
                    Text("IP Address")
                    Spacer()
                    TextField("0.0.0.0", text: ContentView.$ipAddress)
                        .autocorrectionDisabled(true)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .searchDictationBehavior(.inline(activation: .onLook))
                        .onSubmit {
                            // strip whitespace
                            ContentView.ipAddress = ContentView.ipAddress.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                }

                Toggle("Enable Hand Tracking", isOn: $enableHandTracking)
            }

//            Model3D(named: "Scene", bundle: realityKitContentBundle)
//                .padding(.bottom, 50)
//
//            Button("Connect") {
//                Task { @MainActor in
//                    var config = CloudXRKit.Config()
//                    // Configure our IP address
//                    config.connectionType = .local(ip: ContentView.ipAddress)
//                    // Set the resolution preset to low-resolution for testing; normally use .standardPreset
//                    config.resolutionPreset = .standardPreset
//                    cxrSession.configure(config: config)
//                    // Connect!
//                    try await cxrSession.connect()
//
//                    await openImmersiveSpace(id: streamingSpaceTitle)
//                }
//            }.padding()
            Button("Connect") {
                            Task { @MainActor in
                                var config = CloudXRKit.Config()

                                config.connectionType = .localSecure(
                                    ip: "192.168.137.1",
                                    clientToken: "SBl2PlUXUDDRWtt90ZdlaHes0/41cWIJUzcCCzxfbDM",
                                    certificateValidationHandler: { challenge in
                                        // Automatically trust the self-signed cert from the VM
                                        if let trust = challenge.protectionSpace.serverTrust {
                                            return (.useCredential, URLCredential(trust: trust))
                                        }
                                        return (.performDefaultHandling, nil)
                                    }
                                )

                                config.resolutionPreset = .standardPreset

                                // Enable hand tracking for interaction
                                #if targetEnvironment(simulator)
                                config.handTrackingMode = enableHandTracking ? .simulated : .disabled
                                #else
                                config.handTrackingMode = enableHandTracking ? .prediction : .disabled
                                #endif

                                cxrSession.configure(config: config)

                                // Connect!
                                try await cxrSession.connect()

                                await openImmersiveSpace(id: streamingSpaceTitle)
                            }
                        }.padding()

        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
