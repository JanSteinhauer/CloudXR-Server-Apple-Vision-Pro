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
    @AppStorage("ipAddress") static var ipAddress: String = "34.118.75.2"
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset

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
                                    ip: "34.158.227.20",
                                    clientToken: "CLIENT_TOKEN",
                                    certificateValidationHandler: { challenge in
                                        // Automatically trust the self-signed cert from the VM
                                        if let trust = challenge.protectionSpace.serverTrust {
                                            return (.useCredential, URLCredential(trust: trust))
                                        }
                                        return (.performDefaultHandling, nil)
                                    }
                                )
                                
                                config.resolutionPreset = .standardPreset
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
