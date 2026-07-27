import Foundation
import Darwin
import Security

public enum HookBridgeCredential {
    public static let tokenFileName = "bridge-token"

    public static func supportDirectory(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory.appendingPathComponent(
            "Library/Application Support/ClaudeIsland",
            isDirectory: true
        )
    }

    public static func tokenURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        supportDirectory(homeDirectory: homeDirectory)
            .appendingPathComponent(tokenFileName, isDirectory: false)
    }

    public static func helperExecutableURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "ClaudeIslandHook", withExtension: nil) {
            return bundled
        }
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let sibling = executable.deletingLastPathComponent().appendingPathComponent("ClaudeIslandHook")
        return FileManager.default.isExecutableFile(atPath: sibling.path) ? sibling : nil
    }

    @discardableResult
    public static func ensureToken(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> String {
        let fileManager = FileManager.default
        let directory = supportDirectory(homeDirectory: homeDirectory)
        try ensurePrivateDirectory(directory, fileManager: fileManager)

        let url = tokenURL(homeDirectory: homeDirectory)
        if fileManager.fileExists(atPath: url.path) {
            let token = try readValidatedToken(at: url, fileManager: fileManager)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return token
        }

        var generator = SystemRandomNumberGenerator()
        let token = (0 ..< 32)
            .map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }
            .joined()
        let descriptor = url.path.withCString {
            Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        }
        if descriptor == -1 {
            if errno == EEXIST {
                return try readValidatedToken(at: url, fileManager: fileManager)
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: Data((token + "\n").utf8))
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            try? fileManager.removeItem(at: url)
            throw error
        }
        return token
    }

    public static func readToken(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> String {
        try readValidatedToken(
            at: tokenURL(homeDirectory: homeDirectory),
            fileManager: .default
        )
    }

    public static func removeToken(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let url = tokenURL(homeDirectory: homeDirectory)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }
        // Secure overwrite before deletion to mitigate forensic recovery on APFS
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? Int, size > 0 {
            let overwriteSize = min(size, 4096)
            var randomData = Data(count: overwriteSize)
            randomData.withUnsafeMutableBytes { ptr in
                _ = SecRandomCopyBytes(kSecRandomDefault, ptr.count, ptr.baseAddress!)
            }
            try randomData.write(to: url, options: .atomic)
        }
        try fileManager.removeItem(at: url)
    }

    private static func ensurePrivateDirectory(_ url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw CredentialError.invalidSupportDirectory }
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                throw CredentialError.invalidSupportDirectory
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private static func readValidatedToken(at url: URL, fileManager: FileManager) throws -> String {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw CredentialError.invalidTokenFile
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= 256,
              let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.count == 64,
              token.unicodeScalars.allSatisfy({ scalar in
                  (48 ... 57).contains(scalar.value) || (97 ... 102).contains(scalar.value)
              })
        else {
            throw CredentialError.invalidToken
        }
        return token
    }

    private enum CredentialError: LocalizedError {
        case invalidSupportDirectory
        case invalidTokenFile
        case invalidToken

        var errorDescription: String? {
            switch self {
            case .invalidSupportDirectory:
                "Claude Island's support path is not a private directory."
            case .invalidTokenFile:
                "Claude Island's bridge credential is not a regular file."
            case .invalidToken:
                "Claude Island's bridge credential is invalid."
            }
        }
    }
}
