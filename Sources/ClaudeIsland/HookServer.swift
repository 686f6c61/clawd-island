@preconcurrency import Network
import ClaudeIslandCore
import Foundation

final class HookServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "tech.00b.claude-island.bridge", qos: .userInitiated)
    private var listener: NWListener?
    private var bridgeSecret: String?
    private let replayGuard = HookBridgeReplayGuard()
    private weak var store: IslandStore?

    init(store: IslandStore) {
        self.store = store
    }

    func start() {
        do {
            bridgeSecret = try HookBridgeCredential.ensureToken()
            guard let port = NWEndpoint.Port(rawValue: HookSettingsInstaller.port) else {
                throw ServerError.invalidPort
            }
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.store?.setServerStatus("Local bridge ready")
                    case let .failed(error):
                        self?.store?.setServerStatus("Bridge error: \(error.localizedDescription)")
                    case .cancelled:
                        self?.store?.setServerStatus("Local bridge stopped")
                    default:
                        break
                    }
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            Task { @MainActor in
                store?.setServerStatus("Bridge error: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    static func probe() async -> Bool {
        guard let secret = try? HookBridgeCredential.readToken(),
              let url = URL(string: "http://127.0.0.1:\(HookSettingsInstaller.port)/health")
        else { return false }
        let emptyBody = Data()
        guard let proof = try? HookBridgeAuthentication.makeRequestProof(
            method: "GET",
            path: "/health",
            body: emptyBody,
            secret: secret
        ) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.setValue(proof.nonce, forHTTPHeaderField: HookBridgeAuthentication.nonceHeader)
        request.setValue(proof.timestamp, forHTTPHeaderField: HookBridgeAuthentication.timestampHeader)
        request.setValue(proof.signature, forHTTPHeaderField: HookBridgeAuthentication.requestSignatureHeader)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 1.5
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  data == Data("{\"status\":\"ok\"}".utf8),
                  let signature = http.value(forHTTPHeaderField: HookBridgeAuthentication.responseSignatureHeader)
            else { return false }
            return HookBridgeAuthentication.verifyResponse(
                status: http.statusCode,
                body: data,
                requestNonce: proof.nonce,
                signature: signature,
                secret: secret
            )
        } catch {
            return false
        }
    }

    private func accept(_ connection: NWConnection) {
        guard isLoopback(connection.endpoint) else {
            connection.cancel()
            return
        }
        guard let bridgeSecret else {
            connection.cancel()
            return
        }
        HTTPConnection(
            connection: connection,
            queue: queue,
            bridgeSecret: bridgeSecret,
            replayGuard: replayGuard
        ) { [weak self] request, responder in
            guard let self else {
                responder(HookDecision.empty)
                return
            }
            do {
                let event = try HookEvent(data: request.body)
                Task { @MainActor [weak self] in
                    guard let store = self?.store else {
                        responder(HookDecision.empty)
                        return
                    }
                    let deferred = store.handle(event: event, reply: responder)
                    if !deferred { responder(HookDecision.empty) }
                }
            } catch {
                responder(HookDecision.empty)
            }
        }.start()
    }

    private func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        let value = String(describing: host)
        return value == "127.0.0.1" || value == "::1" || value == "localhost"
    }

    private enum ServerError: LocalizedError {
        case invalidPort
        var errorDescription: String? { "Invalid local bridge port" }
    }
}

private struct HTTPRequest: Sendable {
    let body: Data
}

private final class HookBridgeReplayGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var acceptedNonces: [String: Date] = [:]
    private let retention: TimeInterval = 120

    func consume(_ nonce: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        acceptedNonces = acceptedNonces.filter { now.timeIntervalSince($0.value) <= retention }
        guard acceptedNonces[nonce] == nil else { return false }
        acceptedNonces[nonce] = now
        return true
    }
}

private final class HTTPConnection: @unchecked Sendable {
    private static let maximumHeaderBytes = 16_384
    private static let maximumBodyBytes = 1_048_576
    private static let maximumRequestBytes = maximumHeaderBytes + maximumBodyBytes

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let bridgeSecret: String
    private let replayGuard: HookBridgeReplayGuard
    private let onRequest: @Sendable (HTTPRequest, @escaping @Sendable (Data) -> Void) -> Void
    private var buffer = Data()
    private var responded = false
    private var authenticatedNonce: String?

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        bridgeSecret: String,
        replayGuard: HookBridgeReplayGuard,
        onRequest: @escaping @Sendable (HTTPRequest, @escaping @Sendable (Data) -> Void) -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.bridgeSecret = bridgeSecret
        self.replayGuard = replayGuard
        self.onRequest = onRequest
    }

    func start() {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receive()
            case .failed, .cancelled:
                self.connection.stateUpdateHandler = nil
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            if let data { self.buffer.append(data) }
            guard self.buffer.count <= Self.maximumRequestBytes else {
                self.send(status: 413, body: Data())
                return
            }
            switch self.parseRequest() {
            case .incomplete:
                break
            case let .failure(status):
                self.send(status: status, body: Data())
                return
            case let .request(method, path, headers, body):
                guard let nonce = headers[HookBridgeAuthentication.nonceHeader.lowercased()],
                      let timestamp = headers[HookBridgeAuthentication.timestampHeader.lowercased()],
                      let signature = headers[HookBridgeAuthentication.requestSignatureHeader.lowercased()]
                else {
                    self.send(status: 401, body: Data())
                    return
                }
                let proof = HookBridgeRequestProof(nonce: nonce, timestamp: timestamp, signature: signature)
                guard HookBridgeAuthentication.verifyRequest(
                    method: method,
                    path: path,
                    body: body,
                    proof: proof,
                    secret: self.bridgeSecret
                ), self.replayGuard.consume(nonce) else {
                    self.send(status: 401, body: Data())
                    return
                }
                self.authenticatedNonce = nonce
                guard headers["origin"] == nil else {
                    self.send(status: 403, body: Data())
                    return
                }
                if method == "GET", path == "/health" {
                    self.send(status: 200, body: Data("{\"status\":\"ok\"}".utf8))
                    return
                }
                guard method == "POST" else {
                    self.send(status: 405, body: Data())
                    return
                }
                guard path == "/hook" else {
                    self.send(status: 404, body: Data())
                    return
                }
                guard headers["content-type"]?.lowercased().hasPrefix("application/json") == true else {
                    self.send(status: 415, body: Data())
                    return
                }
                self.onRequest(HTTPRequest(body: body)) { [weak self] response in self?.send(status: 200, body: response) }
                return
            }
            if isComplete || error != nil {
                self.send(status: 400, body: Data())
            } else {
                self.receive()
            }
        }
    }

    private enum ParseResult {
        case incomplete
        case failure(Int)
        case request(method: String, path: String, headers: [String: String], body: Data)
    }

    private func parseRequest() -> ParseResult {
        let marker = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: marker) else {
            return buffer.count > Self.maximumHeaderBytes ? .failure(431) : .incomplete
        }
        guard headerRange.lowerBound <= Self.maximumHeaderBytes else { return .failure(431) }
        let headerData = buffer[..<headerRange.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else { return .failure(400) }
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .failure(400) }
        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count == 3,
              requestParts[2] == "HTTP/1.1" || requestParts[2] == "HTTP/1.0"
        else { return .failure(400) }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return .failure(400) }
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, headers[name] == nil else { return .failure(400) }
            headers[name] = value
        }
        guard headers["transfer-encoding"] == nil else { return .failure(400) }
        let method = String(requestParts[0]).uppercased()
        let contentLength: Int
        if let value = headers["content-length"] {
            guard let parsed = Int(value), parsed >= 0 else { return .failure(400) }
            contentLength = parsed
        } else if method == "POST" {
            return .failure(411)
        } else {
            contentLength = 0
        }
        guard contentLength <= Self.maximumBodyBytes else { return .failure(413) }
        let bodyStart = headerRange.upperBound
        guard buffer.count >= bodyStart + contentLength else { return .incomplete }
        guard buffer.count == bodyStart + contentLength else { return .failure(400) }
        return .request(
            method: method,
            path: String(requestParts[1]),
            headers: headers,
            body: buffer.subdata(in: bodyStart ..< bodyStart + contentLength)
        )
    }

    private func send(status: Int, body: Data) {
        guard !responded else { return }
        responded = true
        let reason = switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 411: "Length Required"
        case 413: "Content Too Large"
        case 415: "Unsupported Media Type"
        case 431: "Request Header Fields Too Large"
        default: "Error"
        }
        var authenticationHeader = ""
        if let nonce = authenticatedNonce,
           let signature = try? HookBridgeAuthentication.responseSignature(
               status: status,
               body: body,
               requestNonce: nonce,
               secret: bridgeSecret
           ) {
            authenticationHeader = "\(HookBridgeAuthentication.responseSignatureHeader): \(signature)\r\n"
        }
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\(authenticationHeader)\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            self.connection.stateUpdateHandler = nil
            self.connection.cancel()
        })
    }
}
