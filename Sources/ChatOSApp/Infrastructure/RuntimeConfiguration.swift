import Foundation

enum RuntimeConfiguration {
    static var apiBaseURL: URL {
        let environmentValue = ProcessInfo.processInfo.environment["CHATOS_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue,
           !environmentValue.isEmpty,
           let url = URL(string: environmentValue) {
            return url
        }
        return URL(string: "http://127.0.0.1:9080/api/chatos")!
    }

    static var projectConversationID: String {
        nonEmptyEnvironmentValue("CHATOS_PROJECT_CONVERSATION_ID")
            ?? "conversation-test-project"
    }

    static var localConnectorCloudBaseURL: URL {
        environmentURL("CHATOS_LOCAL_CONNECTOR_CLOUD_BASE_URL")
            ?? URL(string: "http://127.0.0.1:39230")!
    }

    static var nativeConnectorStateURL: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return root
            .appendingPathComponent("ChatOSSwift", isDirectory: true)
            .appendingPathComponent("NativeConnector", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }

    static var contactConversationID: String {
        nonEmptyEnvironmentValue("CHATOS_CONTACT_CONVERSATION_ID")
            ?? "conversation-contact"
    }

    private static func nonEmptyEnvironmentValue(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func environmentURL(_ key: String) -> URL? {
        nonEmptyEnvironmentValue(key).flatMap(URL.init(string:))
    }
}
