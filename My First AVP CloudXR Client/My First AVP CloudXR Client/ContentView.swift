//
//  ContentView.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 19.04.26.
//

import SwiftUI
import RealityKit

import CloudXRKit

struct ContentView: View {

    @Environment(CloudXRSession.self) var cxrSession
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @EnvironmentObject var syncService: PrototypeSyncService

    // Configurable session settings.
    @AppStorage("ipAddress") static var ipAddress: String = "192.168.137.1"
    @AppStorage("resolutionPreset") private var resolutionPreset: ResolutionPreset = .standardPreset
    /// Off by default: a study session never needs the participant's hands. They
    /// speak to the avatar, and the task windows are native visionOS windows driven
    /// by the system's own eye-and-pinch input, which is handled by the OS and works
    /// whether or not this app tracks hands. Leaving it on only lets a raised palm
    /// summon the streamed app's hand menu, lets stray pokes reach the scene, and
    /// spends upstream bandwidth on joint poses nobody reads.
    @AppStorage("enableHandTracking") private var enableHandTracking: Bool = false

    @State private var spatialAnchors: [SpatialAnchor] = []
    @State private var isLoadingAnchors = false
    @State private var showAnchorsAlert = false
    @State private var anchorsMessage = ""
    @State private var cloudXRMicEnabled = false
    @State private var cloudXRSessionConnected = false
    @State private var connectionStatusMessage = ""

    var body: some View {
        VStack {

            Form {
                HStack {
                    Text("IP Address")
                    Spacer()
                    TextField("192.168.137.1", text: ContentView.$ipAddress)
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

                Toggle("Hand tracking", isOn: $enableHandTracking)
                Text(enableHandTracking
                     ? "On — a raised palm can summon the streamed app's hand menu. Turn off for participant sessions."
                     : "Off — recommended for participant sessions. Window input still works; that is system eye-and-pinch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Connect") {
                            Task { @MainActor in
                                let enteredIP = ContentView.ipAddress.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                let serverIP = enteredIP.isEmpty || enteredIP == "0.0.0.0"
                                    ? EnvironmentConfig.shared.cloudXRServerIP
                                    : enteredIP

                                // Never pass an empty hostname to CloudXR. An empty value
                                // produces `wss://:48322` and fails with "Host not found".
                                ContentView.ipAddress = serverIP
                                cloudXRSessionConnected = false
                                connectionStatusMessage = "Connecting securely to \(serverIP):48322…"
                                print("[CloudXR] Connecting to \(serverIP):48322")

                                do {
                                    var config = CloudXRKit.Config()
                                    let token = EnvironmentConfig.shared.cloudXRClientToken

                                    if !token.isEmpty {
                                        config.connectionType = .localSecure(
                                            ip: serverIP,
                                            clientToken: token,
                                            certificateValidationHandler: { challenge in
                                                // Trust the self-signed certificate issued by
                                                // the local CloudXR Stream Manager.
                                                if let trust = challenge.protectionSpace.serverTrust {
                                                    return (.useCredential, URLCredential(trust: trust))
                                                }
                                                return (.performDefaultHandling, nil)
                                            }
                                        )
                                    } else {
                                        config.connectionType = .local(ip: serverIP)
                                        connectionStatusMessage = "Connecting to \(serverIP):48322…"
                                        print("⚠️ Using local connection without secure token")
                                    }

                                    config.resolutionPreset = .standardPreset

                                    #if targetEnvironment(simulator)
                                    config.handTrackingMode = enableHandTracking ? .simulated : .disabled
                                    #else
                                    config.handTrackingMode = enableHandTracking ? .prediction : .disabled
                                    #endif

                                    cxrSession.configure(config: config)
                                    try await cxrSession.connect()
                                    cloudXRSessionConnected = true

                                    // Framework 6.1+ publishes the Vision Pro microphone
                                    // through CloudXR Runtime 6.2+ after connection.
                                    cxrSession.setMicEnabled(true)
                                    cloudXRMicEnabled = cxrSession.isMicEnabled
                                    connectionStatusMessage = "Connected to \(serverIP)"

                                    await openImmersiveSpace(id: streamingSpaceTitle)
                                } catch {
                                    cloudXRSessionConnected = false
                                    cloudXRMicEnabled = false
                                    connectionStatusMessage = "Connection failed: \(error.localizedDescription)"
                                    print("❌ [CloudXR] Connection to \(serverIP) failed: \(error)")
                                }
                            }
                        }.padding()

            if !connectionStatusMessage.isEmpty {
                Text(connectionStatusMessage)
                    .font(.caption)
                    .foregroundStyle(cloudXRSessionConnected ? Color.green : Color.secondary)
                    .padding(.horizontal)
            }

            cloudXRMicrophoneRow
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button("Prototype") {
                    Task {
                        try? await syncService.resetAllTriggers()
                        openWindow(id: "taskMaster")
                    }
                }

                // Opens the window directly, without going near Firestore. The
                // web-driven path has three places to fail - the write, the poll,
                // the trigger mapping - and this has none of them, so it separates
                // "the window plumbing is broken" from "the trigger never arrived".
                //
                // Deliberately does not call resetAllTriggers the way the Prototype
                // button does: clearing the document here would fight whatever the
                // control website has just set.
                Button("Brief A") {
                    openWindow(id: "task", value: TaskID.brief1A)
                }

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
        .onAppear {
            // The first Firebase fetch can finish before this view attaches its
            // onChange handlers. Reconcile current state once so an already-active
            // move is never silently missed.
            var tasksToOpen = syncService.activeTasks
            if let signal = syncService.launchSignal {
                tasksToOpen.insert(signal.task)
            }
            for task in tasksToOpen {
                openWindow(id: "task", value: task)
            }
        }
        .onChange(of: syncService.activeTasks) { oldValue, newValue in
            let opened = newValue.subtracting(oldValue)
            for task in opened {
                // Explicit requests have their own launchSignal. Avoid opening a
                // second window when that signal and the boolean edge share a poll.
                if task == syncService.launchSignal?.task { continue }
                openWindow(id: "task", value: task)
            }
            
            let closed = oldValue.subtracting(newValue)
            for task in closed {
                dismissWindow(id: "task", value: task)
            }
        }
        .onChange(of: syncService.launchSignal) { _, signal in
            if let signal {
                openWindow(id: "task", value: signal.task)
            }
        }
    }

    // MARK: - CloudXR microphone

    private var cloudXRMicrophoneRow: some View {
        HStack(spacing: 12) {
            Image(systemName: cloudXRMicEnabled ? "mic.fill" : "mic.slash")
                .foregroundStyle(cloudXRMicEnabled ? Color.green : Color.secondary)

            Text(cloudXRMicEnabled
                 ? "Vision Pro microphone streaming through CloudXR"
                 : "CloudXR microphone is muted")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(cloudXRMicEnabled ? "Mute" : "Unmute") {
                cxrSession.setMicEnabled(!cloudXRMicEnabled)
                cloudXRMicEnabled = cxrSession.isMicEnabled
            }
            .controlSize(.small)
            .disabled(!cloudXRSessionConnected)
        }
    }

    // MARK: - Fetch Spatial Anchors

    private func fetchSpatialAnchors() async {
        isLoadingAnchors = true
        defer { isLoadingAnchors = false }

        let (projectId, apiKey) = EnvironmentConfig.firebase

        // Check if Firebase is configured
        if projectId.isEmpty || apiKey.isEmpty {
            anchorsMessage = "Firebase not configured. Please add .env file with FIREBASE_PROJECT_ID and FIREBASE_API_KEY."
            showAnchorsAlert = true
            print("⚠️ [ContentView] Firebase credentials not available")
            return
        }

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
