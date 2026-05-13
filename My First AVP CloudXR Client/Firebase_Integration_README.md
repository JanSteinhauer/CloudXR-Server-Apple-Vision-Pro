# Firebase REST API Integration for CloudXR

This document explains how to use the Firebase REST API integration in your CloudXR Apple Vision Pro project.

## Overview

The Firebase integration allows your CloudXR app to:
- Send queries to Firebase Firestore
- Receive responses from external services
- Track query status (pending, processing, completed, failed)
- View query history in real-time

## Architecture

### Components

1. **FirestoreREST.swift** - Low-level REST API client for Firebase
2. **CloudXRQueryService.swift** - High-level service for managing queries
3. **QueryView.swift** - SwiftUI interface for sending and viewing queries
4. **FirebaseConfig.swift** - Configuration and examples

## Firebase Configuration

Your Firebase project configuration:
- **Project ID**: `xxx`
- **API Key**: `xxx`

### Firestore Structure

```
cloudxr_queries/ (collection)
├── {queryId1}
│   ├── query: "What is the connection status?"
│   ├── timestamp: "2026-05-13T10:30:00Z"
│   ├── status: "pending" | "processing" | "completed" | "failed"
│   └── response: "The connection is active" (optional)
├── {queryId2}
│   └── ...
```

## Usage

### 1. Opening the Query Interface

In your app, tap "Open Firebase Queries" button to open the query window.

### 2. Sending a Query

```swift
// Using CloudXRQueryService
let queryService = CloudXRQueryService(
    projectId: "xxx",
    apiKey: "xxx"
)

// Send a query
try await queryService.sendQuery("What is the CloudXR status?")
```

### 3. Fetching Queries

The service automatically polls for updates every 2 seconds. You can also manually refresh:

```swift
try await queryService.fetchQueries()
```

### 4. Using the REST API Directly

For more control, use `FirestoreREST` directly:

```swift
let rest = FirestoreREST(
    projectId: "xxx",
    apiKey: "xxx",
    documentPath: "cloudxr_queries/someQueryId"
)

// GET a document
let (json, updateTime) = try await rest.getDocument()

// PATCH (update) a document
let fields: [String: FirestoreREST.FirestoreValue] = [
    "response": .string("CloudXR is connected"),
    "status": .string("completed")
]
try await rest.patchDocument(fields: fields, updateMask: ["response", "status"])

// POST (create) a new document
let newFields: [String: FirestoreREST.FirestoreValue] = [
    "query": .string("New query"),
    "timestamp": .timestamp(ISO8601DateFormatter().string(from: Date())),
    "status": .string("pending")
]
let docName = try await rest.createDocument(collection: "cloudxr_queries", fields: newFields)

// LIST documents in a collection
let docs = try await rest.listDocuments(collection: "cloudxr_queries")
```

## Firestore Value Types

The `FirestoreREST.FirestoreValue` enum supports these types:

```swift
.string("text")                          // String value
.integer(42)                             // Integer value
.boolean(true)                           // Boolean value
.timestamp("2026-05-13T10:30:00Z")      // ISO8601 timestamp
.map(["key": .string("value")])         // Nested object
.null                                    // Null value
```

## Query Status Flow

1. **pending** - Query created, waiting for processing
2. **processing** - Query is being processed by external service
3. **completed** - Query processed successfully, response available
4. **failed** - Query processing failed

## External Service Integration

To respond to queries from an external service:

1. Listen to the `cloudxr_queries` collection
2. Filter for queries where `status == "pending"`
3. Process the query
4. Update the document with:
   - `response`: Your response text
   - `status`: "completed" or "failed"

### Example Python Backend

```python
import firebase_admin
from firebase_admin import firestore
from datetime import datetime

db = firestore.client()

# Listen for new queries
def on_snapshot(col_snapshot, changes, read_time):
    for change in changes:
        if change.type.name == 'ADDED':
            doc = change.document
            data = doc.to_dict()
            
            if data.get('status') == 'pending':
                # Process the query
                response = process_query(data['query'])
                
                # Update with response
                doc.reference.update({
                    'response': response,
                    'status': 'completed'
                })

# Start listening
query = db.collection('cloudxr_queries').where('status', '==', 'pending')
query.on_snapshot(on_snapshot)
```

## Security Rules

Make sure your Firestore security rules allow read/write access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /cloudxr_queries/{document=**} {
      allow read, write: if true; // For testing only!
      // In production, add proper authentication
    }
  }
}
```

**Important**: The rules above are for testing only. In production, implement proper authentication and authorization.

## Troubleshooting

### Queries not appearing
- Check Firebase Console to verify documents are being created
- Verify the API key and project ID are correct
- Check Firestore security rules

### Polling not working
- The service polls every 2 seconds by default
- Check console logs for error messages
- Verify network connectivity

### Document not found (404)
- Ensure the document path is correct
- Verify the document exists in Firestore
- Check for typos in collection/document names

## Advanced Usage

### Custom Polling Interval

Modify `CloudXRQueryService.swift`:

```swift
private let pollInterval: TimeInterval = 5.0 // 5 seconds instead of 2
```

### Stop Polling

```swift
// The service automatically stops polling when deinitialized
// Or you can cancel the task manually:
pollTask?.cancel()
```

### Batch Operations

```swift
// Send multiple queries in parallel
async let query1 = queryService.sendQuery("Query 1")
async let query2 = queryService.sendQuery("Query 2")
async let query3 = queryService.sendQuery("Query 3")

let results = try await [query1, query2, query3]
```

## Next Steps

1. Implement authentication for production use
2. Add push notifications for query responses
3. Integrate with your CloudXR connection status
4. Add query filtering and search capabilities
5. Implement query templates for common questions
