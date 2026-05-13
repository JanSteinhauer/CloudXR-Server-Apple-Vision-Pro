//
//  CloudXRQueryService.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import SwiftUI
import Combine

/// Service for managing CloudXR queries and responses via Firebase
@MainActor
final class CloudXRQueryService: ObservableObject {

    struct Query: Identifiable {
        let id: String
        let query: String
        let timestamp: Date
        var response: String?
        var status: QueryStatus

        enum QueryStatus: String {
            case pending = "pending"
            case processing = "processing"
            case completed = "completed"
            case failed = "failed"
        }
    }

    let rest: FirestoreREST

    @Published var queries: [Query] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private var pollTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 2.0 // Poll every 2 seconds

    init(projectId: String, apiKey: String) {
        self.rest = FirestoreREST(
            projectId: projectId,
            apiKey: apiKey,
            documentPath: "cloudxr/session" // Main session document
        )

        // Start polling for query updates
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    // MARK: - Query Operations

    /// Send a new query to Firebase
    func sendQuery(_ queryText: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        let now = ISO8601DateFormatter().string(from: Date())

        let fields: [String: FirestoreREST.FirestoreValue] = [
            "query": .string(queryText),
            "timestamp": .timestamp(now),
            "status": .string("pending"),
            "response": .null
        ]

        do {
            let docName = try await rest.createDocument(collection: "cloudxr_queries", fields: fields)

            // Extract document ID from name (format: projects/.../databases/.../documents/cloudxr_queries/{id})
            let docId = docName.components(separatedBy: "/").last ?? ""

            let newQuery = Query(
                id: docId,
                query: queryText,
                timestamp: Date(),
                response: nil,
                status: .pending
            )

            queries.append(newQuery)

            print("✅ [CloudXRQueryService] Query sent: \(queryText)")
            return docId
        } catch {
            lastError = "Failed to send query: \(error.localizedDescription)"
            print("❌ [CloudXRQueryService] Error sending query: \(error)")
            throw error
        }
    }

    /// Fetch all queries from Firebase
    func fetchQueries() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let docs = try await rest.listDocuments(collection: "cloudxr_queries")

            var fetchedQueries: [Query] = []

            for doc in docs {
                guard let fields = doc.fields else { continue }

                let docId = doc.name.components(separatedBy: "/").last ?? ""

                let queryText = stringValue(from: fields["query"]) ?? ""
                let response = stringValue(from: fields["response"])
                let statusStr = stringValue(from: fields["status"]) ?? "pending"
                let status = Query.QueryStatus(rawValue: statusStr) ?? .pending

                // Parse timestamp
                var timestamp = Date()
                if let timestampStr = timestampValue(from: fields["timestamp"]) {
                    let formatter = ISO8601DateFormatter()
                    timestamp = formatter.date(from: timestampStr) ?? Date()
                }

                let query = Query(
                    id: docId,
                    query: queryText,
                    timestamp: timestamp,
                    response: response,
                    status: status
                )

                fetchedQueries.append(query)
            }

            // Sort by timestamp (newest first)
            queries = fetchedQueries.sorted { $0.timestamp > $1.timestamp }

            print("✅ [CloudXRQueryService] Fetched \(queries.count) queries")
        } catch {
            lastError = "Failed to fetch queries: \(error.localizedDescription)"
            print("❌ [CloudXRQueryService] Error fetching queries: \(error)")
            throw error
        }
    }

    /// Update query status
    func updateQueryStatus(queryId: String, status: Query.QueryStatus, response: String? = nil) async throws {
        var fields: [String: FirestoreREST.FirestoreValue] = [
            "status": .string(status.rawValue)
        ]

        if let response = response {
            fields["response"] = .string(response)
        }

        // Update document path temporarily
        let originalPath = rest.documentPath
        let queryDocPath = "cloudxr_queries/\(queryId)"

        // Create new REST instance for this specific document
        let queryRest = FirestoreREST(
            projectId: rest.projectId,
            apiKey: "", // We'll use the same session's credentials
            documentPath: queryDocPath
        )

        do {
            try await rest.patchDocument(fields: fields, updateMask: Array(fields.keys))

            // Update local state
            if let index = queries.firstIndex(where: { $0.id == queryId }) {
                queries[index].status = status
                if let response = response {
                    queries[index].response = response
                }
            }

            print("✅ [CloudXRQueryService] Updated query \(queryId) status to \(status.rawValue)")
        } catch {
            lastError = "Failed to update query: \(error.localizedDescription)"
            print("❌ [CloudXRQueryService] Error updating query: \(error)")
            throw error
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            // Initial fetch
            try? await self.fetchQueries()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                try? await self.fetchQueries()
            }
        }
    }

    // MARK: - Helper Methods

    private func stringValue(from value: FirestoreREST.FirestoreValue?) -> String? {
        guard let value = value else { return nil }
        if case .string(let str) = value {
            return str
        }
        return nil
    }

    private func timestampValue(from value: FirestoreREST.FirestoreValue?) -> String? {
        guard let value = value else { return nil }
        if case .timestamp(let ts) = value {
            return ts
        }
        return nil
    }
}
