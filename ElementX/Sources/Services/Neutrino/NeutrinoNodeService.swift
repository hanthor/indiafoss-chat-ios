//
// Copyright 2026 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import NeutrinoKit

/// The embedded mesh homeserver, running inside this app the way the Android
/// sibling runs it inside `services/neutrino`: one node per install, storage
/// under the app's support directory, client-server API on loopback for the
/// Rust SDK to sign into.
///
/// Wi-Fi only on iOS for now — the medium is built without its BLE feature
/// (that backend is Android JNI); discovery is mDNS, which on a device needs
/// the `com.apple.developer.networking.multicast` entitlement. Nothing here
/// starts at launch: the node spins up the first time the mesh flow asks for
/// it, so an attendee who signs into the venue homeserver instead never pays
/// for a node they don't run.
final class NeutrinoNodeService {
    static let shared = NeutrinoNodeService()

    /// Loopback address the embedded client-server API binds. The Rust SDK is
    /// pointed at `http://127.0.0.1:8118` as its homeserver URL.
    static let clientServerURL = "http://127.0.0.1:8118"

    private var handle: NeutrinoHandle?

    private init() {}

    /// Idempotent: the running handle is reused. Returns the node's
    /// `server_name` (the stable mesh identity) once the server is up.
    func start() async throws -> String {
        if let handle, let name = handle.serverName() {
            return name
        }

        let storage = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("neutrino", isDirectory: true).path

        let config = NeutrinoConfig(
            bindAddr: "127.0.0.1:8118",
            localpart: "n",
            serverName: nil,
            storageDir: storage,
            outboundConcurrency: 4,
            trustedNetwork: false,
            lbFederationPort: 8418,
            logDir: nil,
            deliveryReceipts: true
        )

        let handle = startBle(config: config)
        self.handle = handle

        // Same readiness dance as the Android splash: identity first, then the
        // listener. 30s is generous; first start includes key generation.
        for _ in 0..<300 {
            if let error = handle.lastError() {
                self.handle = nil
                throw NeutrinoNodeError.startFailed(error)
            }
            if let name = handle.serverName() {
                return name
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        self.handle = nil
        throw NeutrinoNodeError.startTimedOut
    }
}

enum NeutrinoNodeError: LocalizedError {
    case startFailed(String)
    case startTimedOut

    var errorDescription: String? {
        switch self {
        case .startFailed(let reason): "The mesh node refused to start: \(reason)"
        case .startTimedOut: "The mesh node did not become ready in time"
        }
    }
}
