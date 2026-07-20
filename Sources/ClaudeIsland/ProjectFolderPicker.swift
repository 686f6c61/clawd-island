import AppKit
import Foundation

@MainActor
enum ProjectFolderPicker {
    private static let lastBrowseDirectoryKey = "lastProjectFolderBrowseDirectory"

    static func choose(title: String, message: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = initialDirectory()

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return nil }

        let folderURL = selectedURL.standardizedFileURL
        rememberParentDirectory(of: folderURL)
        return folderURL.path
    }

    private static func initialDirectory(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> URL {
        if let savedPath = defaults.string(forKey: lastBrowseDirectoryKey) {
            let savedURL = URL(fileURLWithPath: savedPath, isDirectory: true).standardizedFileURL
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: savedURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return savedURL
            }
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    private static func rememberParentDirectory(
        of folderURL: URL,
        defaults: UserDefaults = .standard
    ) {
        let parentURL = folderURL.deletingLastPathComponent().standardizedFileURL
        defaults.set(parentURL.path, forKey: lastBrowseDirectoryKey)
    }
}
