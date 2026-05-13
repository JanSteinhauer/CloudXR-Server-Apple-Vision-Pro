//
//  FirebaseConfig.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import Foundation

struct FirebaseConfig {
    /// Your Firebase project ID (loaded from .env)
    static let projectId = EnvironmentConfig.shared.firebaseProjectId

    /// Your Firebase Web API Key (loaded from .env)
    static let apiKey = EnvironmentConfig.shared.firebaseApiKey

    /// The document path for the main session
    static let sessionDocumentPath = "cloudxr/session"

    /// The collection name for queries
    static let queriesCollection = "cloudxr_queries"

    /// The collection name for spatial anchors
    static let spatialAnchorsCollection = "spatial_anchors"
}

// MARK: - Usage Examples

extension FirebaseConfig {
    /// Example: Create a simple query
    static func exampleSendQuery() async throws {
        let rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: sessionDocumentPath
        )

        let now = ISO8601DateFormatter().string(from: Date())
        let fields: [String: FirestoreREST.FirestoreValue] = [
            "query": .string("What is the CloudXR connection status?"),
            "timestamp": .timestamp(now),
            "status": .string("pending")
        ]

        _ = try await rest.createDocument(collection: queriesCollection, fields: fields)
    }

    /// Example: Fetch queries
    static func exampleFetchQueries() async throws -> [FirestoreREST.DocEnvelope] {
        let rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: sessionDocumentPath
        )

        return try await rest.listDocuments(collection: queriesCollection)
    }

    /// Example: Update a specific query with a response
    static func exampleUpdateQuery(queryId: String, response: String) async throws {
        let rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: "\(queriesCollection)/\(queryId)"
        )

        let fields: [String: FirestoreREST.FirestoreValue] = [
            "response": .string(response),
            "status": .string("completed")
        ]

        try await rest.patchDocument(fields: fields, updateMask: ["response", "status"])
    }
}
