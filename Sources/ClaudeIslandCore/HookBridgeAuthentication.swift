import CryptoKit
import Foundation

public struct HookBridgeRequestProof: Sendable, Equatable {
    public let nonce: String
    public let timestamp: String
    public let signature: String

    public init(nonce: String, timestamp: String, signature: String) {
        self.nonce = nonce
        self.timestamp = timestamp
        self.signature = signature
    }
}

public enum HookBridgeAuthentication {
    public static let nonceHeader = "X-Claude-Island-Nonce"
    public static let timestampHeader = "X-Claude-Island-Timestamp"
    public static let requestSignatureHeader = "X-Claude-Island-Signature"
    public static let responseSignatureHeader = "X-Claude-Island-Response-Signature"
    public static let maximumClockSkew: TimeInterval = 30

    public static func makeRequestProof(
        method: String,
        path: String,
        body: Data,
        secret: String,
        now: Date = Date(),
        nonce: String? = nil
    ) throws -> HookBridgeRequestProof {
        let requestNonce = nonce ?? randomHex(byteCount: 32)
        guard isLowercaseHex(requestNonce, byteCount: 32) else {
            throw AuthenticationError.invalidNonce
        }
        let timestamp = String(Int64(now.timeIntervalSince1970.rounded(.down)))
        let signature = try authenticationCode(
            for: requestMessage(
                method: method,
                path: path,
                timestamp: timestamp,
                nonce: requestNonce,
                body: body
            ),
            secret: secret
        )
        return HookBridgeRequestProof(nonce: requestNonce, timestamp: timestamp, signature: signature)
    }

    public static func verifyRequest(
        method: String,
        path: String,
        body: Data,
        proof: HookBridgeRequestProof,
        secret: String,
        now: Date = Date(),
        allowedClockSkew: TimeInterval = maximumClockSkew
    ) -> Bool {
        guard isLowercaseHex(proof.nonce, byteCount: 32),
              let requestTime = TimeInterval(proof.timestamp),
              abs(now.timeIntervalSince1970 - requestTime) <= allowedClockSkew
        else { return false }
        return verifyAuthenticationCode(
            proof.signature,
            message: requestMessage(
                method: method,
                path: path,
                timestamp: proof.timestamp,
                nonce: proof.nonce,
                body: body
            ),
            secret: secret
        )
    }

    public static func responseSignature(
        status: Int,
        body: Data,
        requestNonce: String,
        secret: String
    ) throws -> String {
        guard isLowercaseHex(requestNonce, byteCount: 32) else {
            throw AuthenticationError.invalidNonce
        }
        return try authenticationCode(
            for: responseMessage(status: status, nonce: requestNonce, body: body),
            secret: secret
        )
    }

    public static func verifyResponse(
        status: Int,
        body: Data,
        requestNonce: String,
        signature: String,
        secret: String
    ) -> Bool {
        guard isLowercaseHex(requestNonce, byteCount: 32) else { return false }
        return verifyAuthenticationCode(
            signature,
            message: responseMessage(status: status, nonce: requestNonce, body: body),
            secret: secret
        )
    }

    private static func requestMessage(
        method: String,
        path: String,
        timestamp: String,
        nonce: String,
        body: Data
    ) -> Data {
        Data("claude-island-bridge-v1\nrequest\n\(method.uppercased())\n\(path)\n\(timestamp)\n\(nonce)\n\(hexString(SHA256.hash(data: body)))".utf8)
    }

    private static func responseMessage(status: Int, nonce: String, body: Data) -> Data {
        Data("claude-island-bridge-v1\nresponse\n\(status)\n\(nonce)\n\(hexString(SHA256.hash(data: body)))".utf8)
    }

    private static func authenticationCode(for message: Data, secret: String) throws -> String {
        guard let keyData = dataFromLowercaseHex(secret, byteCount: 32) else {
            throw AuthenticationError.invalidSecret
        }
        return hexString(HMAC<SHA256>.authenticationCode(
            for: message,
            using: SymmetricKey(data: keyData)
        ))
    }

    private static func verifyAuthenticationCode(_ signature: String, message: Data, secret: String) -> Bool {
        guard let keyData = dataFromLowercaseHex(secret, byteCount: 32),
              let signatureData = dataFromLowercaseHex(signature, byteCount: 32)
        else { return false }
        return HMAC<SHA256>.isValidAuthenticationCode(
            signatureData,
            authenticating: message,
            using: SymmetricKey(data: keyData)
        )
    }

    private static func randomHex(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return (0 ..< byteCount)
            .map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }
            .joined()
    }

    private static func hexString<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func isLowercaseHex(_ value: String, byteCount: Int) -> Bool {
        dataFromLowercaseHex(value, byteCount: byteCount) != nil
    }

    private static func dataFromLowercaseHex(_ value: String, byteCount: Int) -> Data? {
        guard value.count == byteCount * 2,
              value.unicodeScalars.allSatisfy({ scalar in
                  (48 ... 57).contains(scalar.value) || (97 ... 102).contains(scalar.value)
              })
        else { return nil }
        var data = Data(capacity: byteCount)
        var index = value.startIndex
        for _ in 0 ..< byteCount {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index ..< next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    private enum AuthenticationError: Error {
        case invalidNonce
        case invalidSecret
    }
}
