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
    @Environment(\.openWindow) var openWindow

    // Configurable session settings.
    @AppStorage("ipAddress") static var ipAddress: String = ""
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset
    @AppStorage("enableHandTracking") private var enableHandTracking: Bool = true

    @State private var spatialAnchors: [SpatialAnchor] = []
    @State private var isLoadingAnchors = false
    @State private var showAnchorsAlert = false
    @State private var anchorsMessage = ""

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
                                    clientToken: EnvironmentConfig.shared.cloudXRClientToken,
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

            HStack(spacing: 20) {
                Button("Open Firebase Queries") {
                    openWindow(id: "queries")
                }

                Button(action: {
                    Task {
                        await fetchSpatialAnchors()
                    }
                }) {
                    HStack {
                        if isLoadingAnchors {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Firestore")
                    }
                }
                .disabled(isLoadingAnchors)
            }
            .padding()

            // Display spatial anchors if loaded
            if !spatialAnchors.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Spatial Anchors (\(spatialAnchors.count))")
                        .font(.headline)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(spatialAnchors) { anchor in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(anchor.label)
                                            .font(.body)
                                            .fontWeight(.semibold)

                                        Spacer()

                                        Text(anchor.objectId)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text("Position: (\(anchor.position.x, specifier: "%.2f"), \(anchor.position.y, specifier: "%.2f"), \(anchor.position.z, specifier: "%.2f"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text("Rotation: (\(anchor.rotation.x, specifier: "%.0f")°, \(anchor.rotation.y, specifier: "%.0f")°, \(anchor.rotation.z, specifier: "%.0f")°, w:\(anchor.rotation.w, specifier: "%.0f"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text("Scale: (\(anchor.scale.x, specifier: "%.2f"), \(anchor.scale.y, specifier: "%.2f"), \(anchor.scale.z, specifier: "%.2f"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if let timestamp = anchor.timestamp {
                                        Text("Detected: \(timestamp, style: .relative)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
            }

        }
        .padding()
        .alert("Spatial Anchors", isPresented: $showAnchorsAlert) {
            Button("OK") { }
        } message: {
            Text(anchorsMessage)
        }
    }

    // MARK: - Fetch Spatial Anchors

    private func fetchSpatialAnchors() async {
        isLoadingAnchors = true
        defer { isLoadingAnchors = false }

        let (projectId, apiKey) = EnvironmentConfig.firebase

        let rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: "cloudxr/session" // Temporary, we'll list a collection
        )

        do {
            let docs = try await rest.listDocuments(collection: FirebaseConfig.spatialAnchorsCollection)

            var anchors: [SpatialAnchor] = []

            for doc in docs {
                guard let fields = doc.fields else { continue }

                let docId = doc.name.components(separatedBy: "/").last ?? ""

                // Extract object_id and label
                let objectId = stringValue(from: fields["object_id"]) ?? docId
                let label = stringValue(from: fields["label"]) ?? "Unknown"

                // Extract position (map of x, y, z)
                var position = (x: 0.0, y: 0.0, z: 0.0)
                if case .map(let posMap) = fields["position"] {
                    position = extractVector3(from: posMap)
                }

                // Extract rotation (map of x, y, z, w)
                var rotation = (x: 0.0, y: 0.0, z: 0.0, w: 1.0)
                if case .map(let rotMap) = fields["rotation"] {
                    rotation.x = extractDouble(from: rotMap["x"])
                    rotation.y = extractDouble(from: rotMap["y"])
                    rotation.z = extractDouble(from: rotMap["z"])
                    rotation.w = extractDouble(from: rotMap["w"])
                }

                // Extract scale (map of x, y, z)
                var scale = (x: 1.0, y: 1.0, z: 1.0)
                if case .map(let scaleMap) = fields["scale"] {
                    scale = extractVector3(from: scaleMap)
                }

                // Extract timestamp
                var timestamp: Date?
                if case .timestamp(let ts) = fields["timestamp"] {
                    timestamp = ISO8601DateFormatter().date(from: ts)
                }

                let anchor = SpatialAnchor(
                    id: docId,
                    objectId: objectId,
                    label: label,
                    position: position,
                    rotation: rotation,
                    scale: scale,
                    timestamp: timestamp
                )

                anchors.append(anchor)
            }

            spatialAnchors = anchors

            if anchors.isEmpty {
                anchorsMessage = "No spatial anchors found in Firestore."
            } else {
                anchorsMessage = "Loaded \(anchors.count) spatial anchor(s)!"
            }

            showAnchorsAlert = true

            print("✅ [ContentView] Loaded \(anchors.count) spatial anchors")

        } catch {
            anchorsMessage = "Failed to load spatial anchors: \(error.localizedDescription)"
            showAnchorsAlert = true
            print("❌ [ContentView] Error loading spatial anchors: \(error)")
        }
    }

    private func stringValue(from value: FirestoreREST.FirestoreValue?) -> String? {
        guard let value = value else { return nil }
        if case .string(let str) = value {
            return str
        }
        return nil
    }

    private func extractDouble(from value: FirestoreREST.FirestoreValue?) -> Double {
        guard let value = value else { return 0.0 }

        switch value {
        case .integer(let i):
            return Double(i)
        case .string(let s):
            return Double(s) ?? 0.0
        default:
            return 0.0
        }
    }

    private func extractVector3(from map: [String: FirestoreREST.FirestoreValue]) -> (x: Double, y: Double, z: Double) {
        return (
            x: extractDouble(from: map["x"]),
            y: extractDouble(from: map["y"]),
            z: extractDouble(from: map["z"])
        )
    }
}

// MARK: - Spatial Anchor Model

struct SpatialAnchor: Identifiable {
    let id: String
    let objectId: String        // e.g., "cup_01"
    let label: String            // e.g., "cup"
    let position: (x: Double, y: Double, z: Double)
    let rotation: (x: Double, y: Double, z: Double, w: Double)  // Quaternion
    let scale: (x: Double, y: Double, z: Double)
    let timestamp: Date?
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
