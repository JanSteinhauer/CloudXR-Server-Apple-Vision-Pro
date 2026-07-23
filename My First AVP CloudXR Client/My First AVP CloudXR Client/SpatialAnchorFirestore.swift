//
//  SpatialAnchorFirestore.swift
//  My First AVP CloudXR Client
//
//  Saves detected spatial anchors to Firestore
//

import Foundation
import ARKit

@MainActor
class SpatialAnchorFirestore {

    private let firestoreREST: FirestoreREST
    private let collection: String

    // Track which objects we've already saved to avoid duplicates
    private var savedObjectIds: Set<UUID> = []

    init() {
        let (projectId, apiKey) = EnvironmentConfig.firebase

        self.firestoreREST = FirestoreREST(
            projectId: projectId.isEmpty ? "default-project" : projectId,
            apiKey: apiKey.isEmpty ? "default-key" : apiKey,
            documentPath: "cloudxr/session"
        )

        self.collection = FirebaseConfig.spatialAnchorsCollection
    }

    /// Save a detected object anchor to Firestore
    func saveObjectAnchor(_ anchor: ObjectAnchor, headPose: simd_float4x4? = nil) async {
        // Check if we already saved this object
        guard !savedObjectIds.contains(anchor.id) else {
            print("📍 [SpatialAnchorFirestore] Object \(anchor.referenceObject.name) already saved, skipping")
            return
        }

        // Check if Firebase is configured
        let (projectId, apiKey) = EnvironmentConfig.firebase
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            print("⚠️ [SpatialAnchorFirestore] Firebase not configured, skipping save")
            return
        }

        // Extract transform information
        let transform = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        // Extract rotation (quaternion from transform matrix)
        let rotation = simd_quatf(transform)

        // Get bounding box for scale
        let scale = anchor.boundingBox.extent

        // Create Firestore fields using FirestoreValue
        let positionMap: FirestoreREST.FirestoreValue = .map(Self.vec3Map(position))
        let rotationMap: FirestoreREST.FirestoreValue = .map(Self.quatMap(rotation))
        let scaleMap: FirestoreREST.FirestoreValue = .map(Self.vec3Map(scale))
        let labelString = anchor.referenceObject.name.replacingOccurrences(of: "_", with: " ")

        var fields: [String: FirestoreREST.FirestoreValue] = [:]
        fields["object_id"] = .string(anchor.referenceObject.name)
        fields["label"] = .string(labelString)
        fields["position"] = positionMap
        fields["rotation"] = rotationMap
        fields["scale"] = scaleMap
        fields["timestamp"] = .timestamp(ISO8601DateFormatter().string(from: Date()))
        fields["is_tracked"] = .boolean(anchor.isTracked)

        if let headPose {
            let headPosition = SIMD3<Float>(headPose.columns.3.x, headPose.columns.3.y, headPose.columns.3.z)
            let headRotation = simd_quatf(headPose)
            fields["head_position"] = .map(Self.vec3Map(headPosition))
            fields["head_rotation"] = .map(Self.quatMap(headRotation))
        }

        do {
            // Generate unique document ID
            let docId = "\(anchor.referenceObject.name)_\(UUID().uuidString.prefix(8))"

            print("📍 [SpatialAnchorFirestore] Saving object '\(anchor.referenceObject.name)' to Firestore...")
            print("   Position: (\(position.x), \(position.y), \(position.z))")
            print("   Document ID: \(docId)")

            try await firestoreREST.createDocument(
                collection: collection,
                documentId: docId,
                fields: fields
            )

            // Mark as saved
            savedObjectIds.insert(anchor.id)

            print("✅ [SpatialAnchorFirestore] Successfully saved spatial anchor to Firestore!")

        } catch {
            print("❌ [SpatialAnchorFirestore] Failed to save spatial anchor: \(error)")
        }
    }

    /// Update an existing spatial anchor position
    func updateObjectAnchor(_ anchor: ObjectAnchor, documentId: String) async {
        let (projectId, apiKey) = EnvironmentConfig.firebase
        guard !projectId.isEmpty && !apiKey.isEmpty else { return }

        let transform = anchor.originFromAnchorTransform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let rotation = simd_quatf(transform)

        let updateFields: [String: FirestoreREST.FirestoreValue] = [
            "position": .map([
                "x": .string(String(Double(position.x))),
                "y": .string(String(Double(position.y))),
                "z": .string(String(Double(position.z)))
            ]),
            "rotation": .map([
                "x": .string(String(Double(rotation.vector.x))),
                "y": .string(String(Double(rotation.vector.y))),
                "z": .string(String(Double(rotation.vector.z))),
                "w": .string(String(Double(rotation.vector.w)))
            ]),
            "timestamp": .timestamp(ISO8601DateFormatter().string(from: Date())),
            "is_tracked": .boolean(anchor.isTracked)
        ]

        do {
            try await firestoreREST.updateDocument(
                collection: collection,
                documentId: documentId,
                fields: updateFields
            )
            print("📍 [SpatialAnchorFirestore] Updated spatial anchor position")
        } catch {
            print("❌ [SpatialAnchorFirestore] Failed to update spatial anchor: \(error)")
        }
    }

    /// Clear the saved objects cache (for testing)
    func clearSavedCache() {
        savedObjectIds.removeAll()
        print("🗑️ [SpatialAnchorFirestore] Cleared saved objects cache")
    }

    private static func vec3Map(_ v: SIMD3<Float>) -> [String: FirestoreREST.FirestoreValue] {
        return [
            "x": .string(String(Double(v.x))),
            "y": .string(String(Double(v.y))),
            "z": .string(String(Double(v.z)))
        ]
    }

    private static func quatMap(_ q: simd_quatf) -> [String: FirestoreREST.FirestoreValue] {
        return [
            "x": .string(String(Double(q.vector.x))),
            "y": .string(String(Double(q.vector.y))),
            "z": .string(String(Double(q.vector.z))),
            "w": .string(String(Double(q.vector.w)))
        ]
    }
}
