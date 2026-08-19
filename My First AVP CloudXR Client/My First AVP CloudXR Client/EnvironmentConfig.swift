//
//  EnvironmentConfig.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import Foundation

/// Loads configuration from .env file or provides fallback values
struct EnvironmentConfig {

    // MARK: - Singleton
    static let shared = EnvironmentConfig()

    // MARK: - Properties
    private var config: [String: String] = [:]

    // MARK: - Public Accessors
    var firebaseProjectId: String {
        if let value = config["FIREBASE_PROJECT_ID"], !value.isEmpty {
            return value
        }
        print("⚠️ FIREBASE_PROJECT_ID not found in .env file, using empty default")
        return ""
    }

    var firebaseApiKey: String {
        if let value = config["FIREBASE_API_KEY"], !value.isEmpty {
            return value
        }
        print("⚠️ FIREBASE_API_KEY not found in .env file, using empty default")
        return ""
    }

    var cloudXRClientToken: String {
        if let value = config["CLOUDXR_CLIENT_TOKEN"], !value.isEmpty {
            return value
        }
        print("⚠️ CLOUDXR_CLIENT_TOKEN not found in .env file, using empty default")
        return ""
    }

    /// Address of the Windows host as seen by the Vision Pro. The fallback is
    /// the standard address of Windows Mobile Hotspot used by this project.
    var cloudXRServerIP: String {
        let value = config["CLOUDXR_SERVER_IP"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = value, !value.isEmpty {
            return value
        }
        return "192.168.137.1"
    }

    // MARK: - LiveKit (participant microphone)

    /// Must match `livekitclient_server_url` in the Unity project's
    /// `Resources/01_LiveKitClient.asset`.
    var liveKitServerURL: String {
        config["LIVEKIT_SERVER_URL"] ?? "wss://realitystack-livekit.caidas.uni-wuerzburg.de"
    }

    /// Must match `livekitcontrol_server_url` in `Resources/02_LiveKitControl.asset`.
    /// Used only to mint a join token.
    var liveKitControlURL: String {
        config["LIVEKIT_CONTROL_URL"] ?? "https://realitystack-livekit.caidas.uni-wuerzburg.de:4437"
    }

    var liveKitControlUser: String { config["LIVEKIT_CONTROL_USER"] ?? "" }
    var liveKitControlApiKey: String { config["LIVEKIT_CONTROL_API_KEY"] ?? "" }

    /// Must match `room` in `Resources/03_LiveKitSession.asset` — the headset has to
    /// join the same room the Unity server and the agent are in.
    var liveKitRoom: String { config["LIVEKIT_ROOM"] ?? "" }

    /// Identity the headset publishes under. Kept distinct from the Unity server's
    /// local participant so the two are tellable apart in the room.
    var liveKitParticipantIdentity: String {
        config["LIVEKIT_PARTICIPANT_IDENTITY"] ?? "avp-participant"
    }

    // MARK: - Initialization
    private init() {
        loadEnvironmentVariables()
    }

    // MARK: - Private Methods
    private mutating func loadEnvironmentVariables() {
        // Try to find .env file in multiple locations
        let possiblePaths = [
            // App bundle (when .env is included as a resource)
            Bundle.main.path(forResource: ".env", ofType: nil),

            // Same directory as the app on device
            Bundle.main.bundlePath + "/.env",

            // Project root (for simulator/development)
            "/Users/I759164/Documents/University/Master Thesis/ClaudeXR-Server-Apple-Vision-Pro/.env",

            // Documents directory
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent(".env").path
        ].compactMap { $0 }

        for path in possiblePaths {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                parseEnvironmentFile(contents)
                print("✅ [EnvironmentConfig] Loaded .env from: \(path)")
                return
            }
        }

        print("⚠️ [EnvironmentConfig] No .env file found in any location")
        print("   Searched paths:")
        for path in possiblePaths {
            print("   - \(path)")
        }
    }

    private mutating func parseEnvironmentFile(_ contents: String) {
        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            // Skip comments and empty lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE
            let parts = trimmed.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                config[key] = value
            }
        }
    }

    // MARK: - Custom Configuration

    /// Get a custom environment variable
    func get(_ key: String) -> String? {
        return config[key]
    }

    /// Check if .env was loaded successfully
    var isLoaded: Bool {
        return !config.isEmpty
    }

    /// Print all loaded configuration (for debugging - careful with sensitive data!)
    func debugPrint() {
        print("=== Environment Configuration ===")
        if config.isEmpty {
            print("⚠️ No .env file loaded - using defaults")
        } else {
            print("Loaded keys: \(config.keys.sorted())")
        }
        print("FIREBASE_PROJECT_ID: \(firebaseProjectId.isEmpty ? "<not set>" : firebaseProjectId)")
        print("FIREBASE_API_KEY: \(firebaseApiKey.isEmpty ? "<not set>" : maskSecret(firebaseApiKey))")
        print("CLOUDXR_CLIENT_TOKEN: \(cloudXRClientToken.isEmpty ? "<not set>" : maskSecret(cloudXRClientToken))")
        print("CLOUDXR_SERVER_IP: \(cloudXRServerIP)")
        print("=================================")
    }

    private func maskSecret(_ secret: String) -> String {
        guard secret.count > 8 else { return "***" }
        let start = secret.prefix(4)
        let end = secret.suffix(4)
        return "\(start)...\(end)"
    }
}

// MARK: - Convenience Extensions

extension EnvironmentConfig {
    /// Firebase configuration
    static var firebase: (projectId: String, apiKey: String) {
        let config = EnvironmentConfig.shared
        return (config.firebaseProjectId, config.firebaseApiKey)
    }

    /// CloudXR configuration
    static var cloudXR: String {
        let config = EnvironmentConfig.shared
        return config.cloudXRClientToken
    }

    /// LiveKit configuration for publishing the headset microphone.
    static var liveKit: (serverURL: String, controlURL: String, user: String,
                         apiKey: String, room: String, identity: String) {
        let config = EnvironmentConfig.shared
        return (config.liveKitServerURL, config.liveKitControlURL,
                config.liveKitControlUser, config.liveKitControlApiKey,
                config.liveKitRoom, config.liveKitParticipantIdentity)
    }
}
