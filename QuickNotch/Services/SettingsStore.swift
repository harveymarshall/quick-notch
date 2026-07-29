import Foundation

@MainActor
enum SettingsStore {
    static let shared = SettingsStoreImpl()
}

@MainActor
final class SettingsStoreImpl {
    private let defaults = UserDefaults.standard
    private let pathKey = "notesFolderPath"

    var notesFolderPath: String {
        get { defaults.string(forKey: pathKey) ?? "" }
        set { defaults.set(newValue, forKey: pathKey) }
    }
}
