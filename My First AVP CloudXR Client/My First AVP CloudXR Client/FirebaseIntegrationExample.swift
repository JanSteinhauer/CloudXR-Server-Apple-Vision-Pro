//
//  FirebaseIntegrationExample.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import SwiftUI

/// Example demonstrations of using the Firebase REST API integration
struct FirebaseIntegrationExample {

    // MARK: - Basic Examples

    /// Example 1: Send a simple query
    static func sendSimpleQuery() async {
        let queryService = CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        )

        do {
            let queryId = try await queryService.sendQuery("What is the CloudXR connection status?")
            print("✅ Query sent with ID: \(queryId)")
        } catch {
            print("❌ Failed to send query: \(error)")
        }
    }

    /// Example 2: Fetch all queries
    static func fetchAllQueries() async {
        let queryService = CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        )

        do {
            try await queryService.fetchQueries()
            print("✅ Fetched \(queryService.queries.count) queries")

            for query in queryService.queries {
                print("Query: \(query.query)")
                print("Status: \(query.status.rawValue)")
                if let response = query.response {
                    print("Response: \(response)")
                }
                print("---")
            }
        } catch {
            print("❌ Failed to fetch queries: \(error)")
        }
    }

    /// Example 3: Using REST API directly to create a document
    static func createCustomDocument() async {
        let rest = FirestoreREST(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey,
            documentPath: "cloudxr/session"
        )

        let now = ISO8601DateFormatter().string(from: Date())

        let fields: [String: FirestoreREST.FirestoreValue] = [
            "connectionStatus": .string("active"),
            "lastUpdate": .timestamp(now),
            "handTrackingEnabled": .boolean(true),
            "frameRate": .integer(90),
            "metadata": .map([
                "deviceModel": .string("Apple Vision Pro"),
                "osVersion": .string("visionOS 2.0")
            ])
        ]

        do {
            try await rest.patchDocument(fields: fields, updateMask: Array(fields.keys))
            print("✅ Session document updated")
        } catch {
            print("❌ Failed to update session: \(error)")
        }
    }

    /// Example 4: List all documents in a collection
    static func listAllQueries() async {
        let rest = FirestoreREST(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey,
            documentPath: "cloudxr/session"
        )

        do {
            let docs = try await rest.listDocuments(collection: "cloudxr_queries")

            print("✅ Found \(docs.count) query documents")

            for doc in docs {
                let docId = doc.name.components(separatedBy: "/").last ?? "unknown"
                print("Document ID: \(docId)")

                if let fields = doc.fields {
                    // Extract query text
                    if case .string(let queryText) = fields["query"] {
                        print("  Query: \(queryText)")
                    }

                    // Extract status
                    if case .string(let status) = fields["status"] {
                        print("  Status: \(status)")
                    }

                    // Extract response if available
                    if case .string(let response) = fields["response"] {
                        print("  Response: \(response)")
                    }
                }
                print("---")
            }
        } catch {
            print("❌ Failed to list queries: \(error)")
        }
    }

    // MARK: - Advanced Examples

    /// Example 5: Send query and wait for response
    static func sendQueryAndWaitForResponse(queryText: String, timeout: TimeInterval = 30.0) async -> String? {
        let queryService = CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        )

        do {
            let queryId = try await queryService.sendQuery(queryText)
            print("✅ Query sent with ID: \(queryId)")

            // Poll for response with timeout
            let startTime = Date()

            while Date().timeIntervalSince(startTime) < timeout {
                try await queryService.fetchQueries()

                if let query = queryService.queries.first(where: { $0.id == queryId }) {
                    if query.status == .completed, let response = query.response {
                        print("✅ Received response: \(response)")
                        return response
                    } else if query.status == .failed {
                        print("❌ Query failed")
                        return nil
                    }
                }

                // Wait before next poll
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }

            print("⏱️ Timeout waiting for response")
            return nil

        } catch {
            print("❌ Failed to send query: \(error)")
            return nil
        }
    }

    /// Example 6: Batch send multiple queries
    static func sendBatchQueries(queries: [String]) async -> [String] {
        let queryService = CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        )

        var queryIds: [String] = []

        for query in queries {
            do {
                let queryId = try await queryService.sendQuery(query)
                queryIds.append(queryId)
                print("✅ Sent query: \(query) (ID: \(queryId))")
            } catch {
                print("❌ Failed to send query '\(query)': \(error)")
            }
        }

        return queryIds
    }

    /// Example 7: Monitor queries in real-time
    static func monitorQueriesRealTime(duration: TimeInterval = 60.0) async {
        let queryService = CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        )

        print("📡 Starting real-time query monitoring for \(duration) seconds...")

        let startTime = Date()

        while Date().timeIntervalSince(startTime) < duration {
            do {
                try await queryService.fetchQueries()

                // Log any completed queries
                for query in queryService.queries where query.status == .completed && query.response != nil {
                    print("✅ Query completed:")
                    print("   Q: \(query.query)")
                    print("   A: \(query.response!)")
                    print("   Time: \(query.timestamp)")
                    print("---")
                }

            } catch {
                print("❌ Error fetching queries: \(error)")
            }

            // Wait before next poll (2 seconds)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        print("✅ Monitoring complete")
    }
}

// MARK: - SwiftUI Integration Examples

/// Example view showing how to integrate Firebase queries into a SwiftUI view
struct FirebaseIntegrationExampleView: View {

    @StateObject private var queryService: CloudXRQueryService

    @State private var queryText = ""
    @State private var response: String?

    init() {
        _queryService = StateObject(wrappedValue: CloudXRQueryService(
            projectId: FirebaseConfig.projectId,
            apiKey: FirebaseConfig.apiKey
        ))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Query Example")
                .font(.title)

            TextField("Enter your query", text: $queryText)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Send Query") {
                Task {
                    do {
                        _ = try await queryService.sendQuery(queryText)
                        queryText = ""
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            .disabled(queryText.isEmpty)

            if let response = response {
                Text("Response:")
                    .font(.headline)
                Text(response)
                    .padding()
            }

            List(queryService.queries) { query in
                VStack(alignment: .leading) {
                    Text(query.query)
                        .font(.headline)
                    Text(query.status.rawValue)
                        .font(.caption)
                    if let resp = query.response {
                        Text(resp)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
    }
}
