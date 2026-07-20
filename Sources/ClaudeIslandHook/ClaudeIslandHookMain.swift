import ClaudeIslandCore
import Darwin
import Foundation

@main
struct ClaudeIslandHookCLI {
    static func main() async {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard
            !input.isEmpty,
            var payload = try? JSONSerialization.jsonObject(with: input) as? [String: Any]
        else { return }

        payload["island_context"] = terminalContext()
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        let eventName = payload["hook_event_name"] as? String ?? ""
        let toolName = payload["tool_name"] as? String ?? ""
        let waitsForUser = eventName == "PermissionRequest" || (eventName == "PreToolUse" && toolName == "AskUserQuestion")

        guard let bridgeSecret = try? HookBridgeCredential.readToken(),
              let proof = try? HookBridgeAuthentication.makeRequestProof(
                  method: "POST",
                  path: "/hook",
                  body: body,
                  secret: bridgeSecret
              )
        else {
            // Never send hook content to a listener whose installation identity
            // cannot be established. Claude Code keeps its terminal fallback.
            return
        }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(HookSettingsInstaller.port)/hook")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(proof.nonce, forHTTPHeaderField: HookBridgeAuthentication.nonceHeader)
        request.setValue(proof.timestamp, forHTTPHeaderField: HookBridgeAuthentication.timestampHeader)
        request.setValue(proof.signature, forHTTPHeaderField: HookBridgeAuthentication.requestSignatureHeader)
        request.timeoutInterval = waitsForUser ? 350 : 1.2

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        configuration.timeoutIntervalForResource = request.timeoutInterval
        let session = URLSession(configuration: configuration)

        do {
            let (responseData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ..< 300).contains(http.statusCode),
                  let responseSignature = http.value(forHTTPHeaderField: HookBridgeAuthentication.responseSignatureHeader),
                  HookBridgeAuthentication.verifyResponse(
                      status: http.statusCode,
                      body: responseData,
                      requestNonce: proof.nonce,
                      signature: responseSignature,
                      secret: bridgeSecret
                  )
            else { return }
            if !responseData.isEmpty, responseData != HookDecision.empty {
                FileHandle.standardOutput.write(responseData)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        } catch {
            // Island is an optional enhancement. If the app is closed or unavailable,
            // exit successfully so Claude Code keeps its normal terminal interaction.
            return
        }
    }

    private static func terminalContext() -> [String: Any] {
        let environment = ProcessInfo.processInfo.environment
        var context: [String: Any] = [
            "helper_version": "0.1.0",
            "parent_pid": Int(getppid()),
        ]
        for key in ["TERM_PROGRAM", "TERM_PROGRAM_VERSION", "TERM_SESSION_ID", "ITERM_SESSION_ID", "LC_TERMINAL", "SHELL"] {
            if let value = environment[key], !value.isEmpty {
                context[key.lowercased()] = value
            }
        }
        return context
    }
}
