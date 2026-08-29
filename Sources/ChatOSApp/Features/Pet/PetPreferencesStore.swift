import Foundation

@MainActor
final class PetPreferencesStore: ObservableObject {
    private enum Key {
        static let enabled = "ChatOS.pet.enabled"
        static let size = "ChatOS.pet.size"
        static let showProcess = "ChatOS.pet.showProcess"
        static let showCompletions = "ChatOS.pet.showCompletions"
        static let showAcrossSpaces = "ChatOS.pet.showAcrossSpaces"
    }

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }
    @Published var size: Double {
        didSet {
            let normalized = min(180, max(72, size))
            if normalized != size {
                size = normalized
            } else {
                defaults.set(normalized, forKey: Key.size)
            }
        }
    }
    @Published var showProcess: Bool {
        didSet { defaults.set(showProcess, forKey: Key.showProcess) }
    }
    @Published var showCompletions: Bool {
        didSet { defaults.set(showCompletions, forKey: Key.showCompletions) }
    }
    @Published var showAcrossSpaces: Bool {
        didSet { defaults.set(showAcrossSpaces, forKey: Key.showAcrossSpaces) }
    }
    @Published private(set) var resetPositionRequestID = UUID()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        self.size = defaults.object(forKey: Key.size) as? Double ?? 104
        self.showProcess = defaults.object(forKey: Key.showProcess) as? Bool ?? true
        self.showCompletions = defaults.object(forKey: Key.showCompletions) as? Bool ?? true
        self.showAcrossSpaces = defaults.object(forKey: Key.showAcrossSpaces) as? Bool ?? true
    }

    func requestPositionReset() {
        resetPositionRequestID = UUID()
    }
}
