//
//  FirestoreREST.swift
//  My First AVP CloudXR Client
//
//  Created by Steinhauer, Jan on 13.05.26.
//

import SwiftUI

@MainActor
final class FirestoreREST {
    struct DocEnvelope: Codable {
        let name: String
        let fields: [String: FirestoreValue]?
        let updateTime: String?
    }

    enum FirestoreValue: Codable {
        case string(String)
        case integer(Int64)
        case map([String: FirestoreValue])
        case null
        case timestamp(String)
        case boolean(Bool)

        // Encode/Decode Firestore's wire format
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            let raw = try c.decode([String: AnyDecodable].self)

            if let v = raw["stringValue"]?.string {
                self = .string(v); return
            }
            if let v = raw["integerValue"]?.string, let n = Int64(v) {
                self = .integer(n); return
            }
            if let v = raw["mapValue"]?.dict?["fields"]?.dict?.mapValues({ $0.firestoreValue }) {
                self = .map(v); return
            }
            if let v = raw["booleanValue"]?.bool {
                self = .boolean(v); return
            }
            if let v = raw["nullValue"]?.string {
                _ = v; self = .null; return
            }
            if let v = raw["timestampValue"]?.string {
                self = .timestamp(v); return
            }

            throw DecodingError.typeMismatch(
                FirestoreREST.FirestoreValue.self,
                DecodingError.Context(
                    codingPath: c.codingPath,
                    debugDescription: "Unknown FirestoreValue payload"
                )
            )
        }


        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .string(let s): try c.encode(["stringValue": s])
            case .integer(let n): try c.encode(["integerValue": String(n)])
            case .map(let m): try c.encode(["mapValue": ["fields": m]])
            case .null: try c.encode(["nullValue": "NULL_VALUE"])
            case .timestamp(let t): try c.encode(["timestampValue": t])
            case .boolean(let b):   try c.encode(["booleanValue": b])
            }
        }
    }

    let projectId: String
    private let apiKey: String
    let documentPath: String // e.g. "cloudxr/queries"
    private let base: String

    init(projectId: String, apiKey: String, documentPath: String) {
        self.projectId = projectId
        self.apiKey = apiKey
        self.documentPath = documentPath
        self.base = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }

    // GET /documents/{doc}
    func getDocument() async throws -> (json: [String: Any], updateTime: String?) {
        let url = URL(string: "\(base)/\(documentPath)?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode != 200 {
            throw httpError(resp, data: data)
        }

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return (obj, obj["updateTime"] as? String)
    }

    // PATCH /documents/{doc}
    func patchDocument(fields: [String: FirestoreValue], updateMask: [String] = []) async throws {
        var comps = URLComponents(string: "\(base)/\(documentPath)")!
        var items: [URLQueryItem] = [URLQueryItem(name: "key", value: apiKey)]
        for path in updateMask { items.append(URLQueryItem(name: "updateMask.fieldPaths", value: path)) }
        comps.queryItems = items

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["fields": encodeMap(fields)]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            throw httpError(resp, data: data)
        }
    }

    // POST /documents/{collectionId}
    // Creates a new random-ID document in the specified collection
    func createDocument(collection: String, fields: [String: FirestoreValue]) async throws -> String {
        let url = URL(string: "\(base)/\(collection)?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["fields": encodeMap(fields)]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if !(200..<300).contains(http.statusCode) {
            throw httpError(resp, data: data)
        }

        // Parse response to get document ID
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return name
    }

    // GET /documents/{collectionId}
    // Lists documents in the specified collection
    func listDocuments(collection: String) async throws -> [DocEnvelope] {
        let urlStr = "\(base)/\(collection)?key=\(apiKey)&pageSize=300"
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if !(200..<300).contains(http.statusCode) {
            throw httpError(resp, data: data)
        }

        struct ListResponse: Decodable {
            let documents: [DocEnvelope]?
        }

        let listResp = try JSONDecoder().decode(ListResponse.self, from: data)
        return listResp.documents ?? []
    }


    // MARK: - Encode/decode helpers
    private func httpError(_ resp: URLResponse?, data: Data) -> NSError {
        let body = String(data: data, encoding: .utf8) ?? ""
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        return NSError(domain: "FirestoreREST", code: code, userInfo: ["body": body])
    }

    // Convert our value tree to Any for JSONSerialization
    private func encodeMap(_ map: [String: FirestoreValue]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in map { out[k] = encodeValue(v) }
        return out
    }

    private func encodeValue(_ v: FirestoreValue) -> Any {
        switch v {
        case .string(let s): return ["stringValue": s]
        case .integer(let n): return ["integerValue": String(n)]
        case .null:           return ["nullValue": "NULL_VALUE"]
        case .timestamp(let t): return ["timestampValue": t]
        case .map(let m):     return ["mapValue": ["fields": encodeMap(m)]]
        case .boolean(let b):    return ["booleanValue": b]
        }
    }
}

// MARK: - AnyDecodable (tiny helper to parse Firestore JSON)
struct AnyDecodable: Decodable {
    let raw: Any
    var string: String? { raw as? String }
    var dict: [String: AnyDecodable]? { raw as? [String: AnyDecodable] }
    var bool: Bool? { raw as? Bool }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { raw = s; return }
        if let i = try? c.decode(Int.self) { raw = i; return }
        if let d = try? c.decode([String: AnyDecodable].self) { raw = d; return }
        if let a = try? c.decode([AnyDecodable].self) { raw = a; return }
        if let b = try? c.decode(Bool.self) { raw = b; return }
        raw = NSNull()
    }

    var firestoreValue: FirestoreREST.FirestoreValue {
        if let b = bool { return .boolean(b) }
        if let s = string { return .string(s) }

        if let d = dict {
            if d["nullValue"]?.string != nil { return .null }
            if let s = d["stringValue"]?.string { return .string(s) }
            if let i = d["integerValue"]?.string, let n = Int64(i) { return .integer(n) }
            if let t = d["timestampValue"]?.string { return .timestamp(t) }
            if let b = d["booleanValue"]?.bool { return .boolean(b) }

            if let fields = d["mapValue"]?.dict?["fields"]?.dict {
                return .map(fields.mapValues { $0.firestoreValue })
            }
        }

        return .null
    }
}

extension FirestoreREST {
    var exposedProjectId: String { projectId }
    var exposedDocumentPath: String { documentPath }
    var exposedBaseURL: String { base }
}
