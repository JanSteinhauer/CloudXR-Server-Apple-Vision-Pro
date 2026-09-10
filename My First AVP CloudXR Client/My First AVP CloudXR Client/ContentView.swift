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

    @AppStorage("ipAddress") static var ipAddress: String = "34.118.79.176"
    
    @State private var cloudXRMicEnabled = false
    @State private var cloudXRSessionConnected = false
    @State private var connectionStatusMessage = ""
    @State private var isConnecting = false
    @State private var participantName = ""

    var body: some View {
        VStack(spacing: 50) {
            Spacer()
            
            HStack(spacing: 80) {
                Image("UniWürzburgLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                
                Image("Chair_HCI_Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
            }
            .padding(.top, 40)
            
            Spacer()
            
            VStack(spacing: 12) {
                if !participantName.isEmpty {
                    Text("Welcome \(participantName)!")
                        .font(.system(size: 72, weight: .bold))
                }
                
                Text("Click connect to begin")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                Button(action: connectToCloudXR) {
                    if isConnecting {
                        ProgressView()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                    } else {
                        Text("Connect")
                            .font(.title2)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isConnecting || cloudXRSessionConnected)
                
                if !connectionStatusMessage.isEmpty {
                    Text(connectionStatusMessage)
                        .font(.body)
                        .foregroundStyle(cloudXRSessionConnected ? Color.green : Color.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(60)
        .onAppear {
            Task {
                await fetchParticipantName()
            }
        }
        .onChange(of: syncService.launchSignal) { _, signal in
            if let signal {
                openWindow(id: "task", value: signal.task)
            }
        }
    }
    
    private func fetchParticipantName() async {
        do {
            let (projectId, apiKey) = EnvironmentConfig.firebase
            if projectId.isEmpty || apiKey.isEmpty { return }
            
            let rest = FirestoreREST(
                projectId: projectId,
                apiKey: apiKey,
                documentPath: "experiment_control/participant_name"
            )
            let (json, _) = try await rest.getDocument()
            guard let fields = json["fields"] as? [String: Any],
                  let nameField = fields["name"] as? [String: Any],
                  let nameString = nameField["stringValue"] as? String else {
                return
            }
            self.participantName = nameString
        } catch {
            print("Failed to fetch participant name: \(error.localizedDescription)")
        }
    }
    
    private func connectToCloudXR() {
        isConnecting = true
        connectionStatusMessage = "Fetching IP address from Firebase..."
        
        Task { @MainActor in
            do {
                let (projectId, apiKey) = EnvironmentConfig.firebase
                if projectId.isEmpty || apiKey.isEmpty {
                    throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: "Firebase credentials not available. Please add .env file."])
                }
                
                let rest = FirestoreREST(
                    projectId: projectId,
                    apiKey: apiKey,
                    documentPath: "experiment_control/ConnectIPAddress"
                )
                
                let (json, _) = try await rest.getDocument()
                guard let fields = json["fields"] as? [String: Any],
                      let addressField = fields["address"] as? [String: Any],
                      let ipString = addressField["stringValue"] as? String else {
                    throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Invalid Firebase document structure."])
                }
                
                let fetchedIP = ipString.trimmingCharacters(in: .whitespacesAndNewlines)
                ContentView.ipAddress = fetchedIP.isEmpty ? EnvironmentConfig.shared.cloudXRServerIP : fetchedIP
                
                connectionStatusMessage = "Connecting securely to \(ContentView.ipAddress):48322…"
                print("[CloudXR] Connecting to \(ContentView.ipAddress):48322")
                
                var config = CloudXRKit.Config()
                let token = EnvironmentConfig.shared.cloudXRClientToken
                
                if !token.isEmpty {
                    config.connectionType = .localSecure(
                        ip: ContentView.ipAddress,
                        clientToken: token,
                        certificateValidationHandler: { challenge in
                            if let trust = challenge.protectionSpace.serverTrust {
                                return (.useCredential, URLCredential(trust: trust))
                            }
                            return (.performDefaultHandling, nil)
                        }
                    )
                } else {
                    config.connectionType = .local(ip: ContentView.ipAddress)
                    print("⚠️ Using local connection without secure token")
                }
                
                config.resolutionPreset = .standardPreset
                // For participant sessions, hand tracking is recommended to be disabled
                config.handTrackingMode = .disabled
                
                cxrSession.configure(config: config)
                try await cxrSession.connect()
                
                cloudXRSessionConnected = true
                cxrSession.setMicEnabled(true)
                cloudXRMicEnabled = cxrSession.isMicEnabled
                connectionStatusMessage = "Connected to \(ContentView.ipAddress)"
                
                await openImmersiveSpace(id: streamingSpaceTitle)
            } catch {
                cloudXRSessionConnected = false
                cloudXRMicEnabled = false
                connectionStatusMessage = "Connection failed: \(error.localizedDescription)"
                print("❌ [CloudXR] Connection failed: \(error)")
            }
            isConnecting = false
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
