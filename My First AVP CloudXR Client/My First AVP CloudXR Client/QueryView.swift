//
//  QueryView.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import SwiftUI

struct QueryView: View {

    @EnvironmentObject var queryService: CloudXRQueryService

    @State private var queryText: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // Query Input Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Send Query to Firebase")
                        .font(.headline)

                    HStack {
                        TextField("Enter your query...", text: $queryText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .autocorrectionDisabled(true)

                        Button {
                            Task {
                                await sendQuery()
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(queryText.isEmpty || queryService.isLoading)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Query History Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Query History")
                            .font(.headline)

                        Spacer()

                        Button {
                            Task {
                                try? await queryService.fetchQueries()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(queryService.isLoading)
                    }

                    if queryService.queries.isEmpty {
                        Text("No queries yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(queryService.queries) { query in
                                    QueryCard(query: query)
                                }
                            }
                        }
                    }
                }
                .padding()

                if queryService.isLoading {
                    ProgressView("Loading...")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Firebase Queries")
            .alert("Query Status", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendQuery() async {
        guard !queryText.isEmpty else { return }

        do {
            let queryId = try await queryService.sendQuery(queryText)
            alertMessage = "Query sent successfully! ID: \(queryId)"
            showAlert = true
            queryText = "" // Clear input
        } catch {
            alertMessage = "Failed to send query: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

struct QueryCard: View {

    let query: CloudXRQueryService.Query

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(query.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                StatusBadge(status: query.status)
            }

            // Query Text
            Text(query.query)
                .font(.body)
                .lineLimit(nil)

            // Response
            if let response = query.response {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Response:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(response)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct StatusBadge: View {

    let status: CloudXRQueryService.Query.QueryStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    QueryView()
        .environmentObject(CloudXRQueryService(
            projectId: "xxx",
            apiKey: "xxx"
        ))
}
