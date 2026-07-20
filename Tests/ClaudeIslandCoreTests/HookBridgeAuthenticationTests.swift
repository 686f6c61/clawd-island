import Foundation
import XCTest
@testable import ClaudeIslandCore

final class HookBridgeAuthenticationTests: XCTestCase {
    private let secret = String(repeating: "ab", count: 32)
    private let alternateSecret = String(repeating: "cd", count: 32)
    private let now = Date(timeIntervalSince1970: 1_750_000_000)
    private let nonce = String(repeating: "12", count: 32)

    func testAuthenticatesRequestAndResponseWithoutTransmittingSecret() throws {
        let body = Data(#"{"hook_event_name":"SessionStart"}"#.utf8)
        let proof = try HookBridgeAuthentication.makeRequestProof(
            method: "POST",
            path: "/hook",
            body: body,
            secret: secret,
            now: now,
            nonce: nonce
        )

        XCTAssertFalse([proof.nonce, proof.timestamp, proof.signature].contains(secret))
        XCTAssertTrue(HookBridgeAuthentication.verifyRequest(
            method: "POST",
            path: "/hook",
            body: body,
            proof: proof,
            secret: secret,
            now: now
        ))

        let response = Data(#"{"decision":"allow"}"#.utf8)
        let signature = try HookBridgeAuthentication.responseSignature(
            status: 200,
            body: response,
            requestNonce: proof.nonce,
            secret: secret
        )
        XCTAssertTrue(HookBridgeAuthentication.verifyResponse(
            status: 200,
            body: response,
            requestNonce: proof.nonce,
            signature: signature,
            secret: secret
        ))
    }

    func testRejectsTamperingWrongSourceAndExpiredRequests() throws {
        let body = Data("original".utf8)
        let proof = try HookBridgeAuthentication.makeRequestProof(
            method: "POST",
            path: "/hook",
            body: body,
            secret: secret,
            now: now,
            nonce: nonce
        )

        XCTAssertFalse(HookBridgeAuthentication.verifyRequest(
            method: "POST",
            path: "/hook",
            body: Data("tampered".utf8),
            proof: proof,
            secret: secret,
            now: now
        ))
        XCTAssertFalse(HookBridgeAuthentication.verifyRequest(
            method: "POST",
            path: "/hook",
            body: body,
            proof: proof,
            secret: alternateSecret,
            now: now
        ))
        XCTAssertFalse(HookBridgeAuthentication.verifyRequest(
            method: "POST",
            path: "/hook",
            body: body,
            proof: proof,
            secret: secret,
            now: now.addingTimeInterval(31)
        ))
    }

    func testResponseSignatureIsBoundToNonceStatusAndBody() throws {
        let body = Data("response".utf8)
        let signature = try HookBridgeAuthentication.responseSignature(
            status: 200,
            body: body,
            requestNonce: nonce,
            secret: secret
        )

        XCTAssertFalse(HookBridgeAuthentication.verifyResponse(
            status: 401,
            body: body,
            requestNonce: nonce,
            signature: signature,
            secret: secret
        ))
        XCTAssertFalse(HookBridgeAuthentication.verifyResponse(
            status: 200,
            body: Data("changed".utf8),
            requestNonce: nonce,
            signature: signature,
            secret: secret
        ))
        XCTAssertFalse(HookBridgeAuthentication.verifyResponse(
            status: 200,
            body: body,
            requestNonce: String(repeating: "34", count: 32),
            signature: signature,
            secret: secret
        ))
    }
}
