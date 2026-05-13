# Quick Start: Firebase Queries in CloudXR

## 🚀 In 5 Minutes

### Step 1: Add Files to Xcode (2 minutes)

1. Open your Xcode project
2. Right-click "My First AVP CloudXR Client" folder in the navigator
3. Choose "Add Files to 'My First AVP CloudXR Client'..."
4. Select these files (they're already created in the folder):
   - ✅ FirestoreREST.swift
   - ✅ CloudXRQueryService.swift
   - ✅ QueryView.swift
   - ✅ FirebaseConfig.swift
   - ✅ FirebaseIntegrationExample.swift
5. Click "Add"

### Step 2: Build and Run (1 minute)

1. Build your project (⌘+B)
2. Run on Simulator or Device (⌘+R)

### Step 3: Test It! (2 minutes)

1. In the app, tap **"Open Firebase Queries"**
2. Type a test query: "Hello from Vision Pro!"
3. Tap the send button (paper plane icon)
4. Open Firebase Console to see your query appear in real-time!

**Firebase Console**: https://console.firebase.google.com/project/jansteinhauermasterthesis/firestore

Look for the `cloudxr_queries` collection.

## 📱 What You Can Do Now

### Send Queries from Your App
```swift
// From any view with access to queryService
@EnvironmentObject var queryService: CloudXRQueryService

Button("Ask Firebase") {
    Task {
        try await queryService.sendQuery("What's the weather?")
    }
}
```

### View All Queries
```swift
// Access all queries
queryService.queries.forEach { query in
    print("\(query.query) - \(query.status)")
}
```

### Use REST API Directly
```swift
let rest = FirestoreREST(
    projectId: "xxx",
    apiKey: "xxx",
    documentPath: "cloudxr/myDocument"
)

// Create/update a document
try await rest.patchDocument(
    fields: ["message": .string("Hello Firebase!")],
    updateMask: ["message"]
)
```

## 🔧 What's Already Configured

✅ Firebase project connected
✅ API key configured
✅ Query service initialized
✅ UI ready to use
✅ Auto-polling every 2 seconds
✅ Status tracking (pending/processing/completed/failed)

## 📝 File Summary

| File | Purpose | Size |
|------|---------|------|
| FirestoreREST.swift | Low-level REST API client | 9.2 KB |
| CloudXRQueryService.swift | High-level query service | 6.8 KB |
| QueryView.swift | SwiftUI query interface | 5.5 KB |
| FirebaseConfig.swift | Configuration & examples | 2.1 KB |
| FirebaseIntegrationExample.swift | Usage examples | 7.5 KB |

## 🎯 Next: Add a Backend

To respond to queries, create a simple Python backend:

```python
# backend.py
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('serviceAccount.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def on_query(doc_snapshot, changes, read_time):
    for change in changes:
        doc = change.document
        data = doc.to_dict()
        
        if data.get('status') == 'pending':
            # Process and respond
            doc.reference.update({
                'response': f"Received: {data['query']}",
                'status': 'completed'
            })

db.collection('cloudxr_queries').on_snapshot(on_query)
```

## 📚 Full Documentation

- **FIREBASE_SETUP_COMPLETE.md** - Complete setup guide
- **Firebase_Integration_README.md** - Detailed API documentation
- **FirebaseIntegrationExample.swift** - Code examples

## ⚡ Pro Tips

1. **Test in Firebase Console**: Watch documents appear in real-time
2. **Check Network**: Make sure you have internet connectivity
3. **Security Rules**: For testing, allow all read/writes (see docs)
4. **Polling**: Service auto-polls every 2 seconds
5. **Environment Object**: QueryService is available as @EnvironmentObject

## 🐛 Common Issues

**Problem**: Can't see queries
**Solution**: Check Firebase Console, verify API key

**Problem**: 403 Forbidden
**Solution**: Update Firestore security rules to allow access

**Problem**: Build errors
**Solution**: Make sure all .swift files are added to the Xcode project

---

That's it! You're ready to send and receive queries from Firebase in your CloudXR Vision Pro app! 🎉

For more details, see the full documentation files.
