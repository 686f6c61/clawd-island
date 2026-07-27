import ClaudeIslandCore
import CommonCrypto
import Foundation
import LocalAuthentication
import Security

/// SPKI SHA-256 hash for certificate pinning of api.anthropic.com.
/// Regenerate when the certificate changes:
///   openssl s_client -servername api.anthropic.com -connect api.anthropic.com:443 </dev/null 2>/dev/null \
///     | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256
private let anthropicSPKIHash = "cb37cd6f56d170d17e1f516db38e35563d0c22ebb17a97562a6a8a27f6d557a5"

enum ClaudeUsageClient {
    static func fetch(allowsKeychainPrompt: Bool) async throws -> ClaudeUsageSnapshot {
        let accessToken = try await Task.detached(priority: .utility) {
            try readAccessToken(allowsKeychainPrompt: allowsKeychainPrompt)
        }.value

        guard let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw ClaudeUsageClientError.invalidEndpoint
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        let delegate = PinningDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageClientError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200 ... 299:
            return try ClaudeUsageSnapshot.decodeAPIResponse(from: data)
        case 401, 403:
            throw ClaudeUsageClientError.loginExpired
        default:
            throw ClaudeUsageClientError.httpStatus(httpResponse.statusCode)
        }
    }

    private static func readAccessToken(allowsKeychainPrompt: Bool) throws -> String {
        let authenticationContext = LAContext()
        authenticationContext.interactionNotAllowed = !allowsKeychainPrompt
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Claude Code-credentials",
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
            kSecUseAuthenticationContext: authenticationContext,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed || status == errSecUserCanceled {
            throw ClaudeUsageClientError.keychainAuthorizationRequired
        }
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            throw ClaudeUsageClientError.credentialsUnavailable
        }
        guard data.count < 2_000_000 else {
            throw ClaudeUsageClientError.invalidCredentials
        }
        let credentials = try JSONDecoder().decode(CredentialEnvelope.self, from: data)
        guard let token = credentials.claudeAiOauth?.accessToken, !token.isEmpty else {
            throw ClaudeUsageClientError.invalidCredentials
        }
        return token
    }

    private struct CredentialEnvelope: Decodable {
        let claudeAiOauth: ClaudeOAuthCredential?
    }

    private struct ClaudeOAuthCredential: Decodable {
        let accessToken: String
    }
}

/// NSObject-based delegate for URLSession to perform certificate pinning.
private final class PinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var secError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &secError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let publicKey = SecTrustCopyKey(serverTrust) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var hashData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        hashData.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            publicKeyData.withUnsafeBytes { dataPtr in
                CC_SHA256(dataPtr.baseAddress, CC_LONG(dataPtr.count), base.assumingMemoryBound(to: UInt8.self))
            }
        }

        let computedHash = hashData.map { String(format: "%02x", $0) }.joined()

        if computedHash == anthropicSPKIHash {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

enum ClaudeUsageClientError: LocalizedError {
    case credentialsUnavailable
    case invalidCredentials
    case keychainAuthorizationRequired
    case invalidEndpoint
    case invalidResponse
    case loginExpired
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .credentialsUnavailable:
            "Claude Code login was not found in Keychain."
        case .invalidCredentials:
            "Claude Code credentials could not be read."
        case .keychainAuthorizationRequired:
            "Click Refresh to allow Claude Island to read usage from your Keychain."
        case .invalidEndpoint, .invalidResponse:
            "Claude usage returned an invalid response."
        case .loginExpired:
            "Open Claude Code once to refresh its login."
        case let .httpStatus(status):
            "Claude usage is temporarily unavailable (HTTP \(status))."
        }
    }
}
