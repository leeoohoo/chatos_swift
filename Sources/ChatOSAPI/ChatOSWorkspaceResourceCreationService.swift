import ChatOSCore
import Foundation

public struct ChatOSWorkspaceResourceCreationService: WorkspaceResourceCreating {
    private let client: ChatOSAPIClient

    public init(client: ChatOSAPIClient) {
        self.client = client
    }

    public func createLocalProject(
        _ draft: LocalProjectCreationDraft
    ) async throws -> WorkspaceProject {
        let body = try JSONEncoder().encode(CreateLocalProjectRequest(draft: draft))
        let response: CreatedProjectDTO = try await client.request(
            "/local-connectors/projects",
            method: "POST",
            body: body
        )
        return response.domainModel
    }

    public func bindContact(projectID: String, contactID: String) async throws {
        let body = try JSONEncoder().encode(BindContactRequest(contactID: contactID))
        let _: ProjectContactLinkDTO = try await client.request(
            "/projects/\(projectID.pathEncoded)/contacts",
            method: "POST",
            body: body
        )
    }
}

private struct CreateLocalProjectRequest: Encodable {
    var name: String
    var deviceID: String
    var workspaceID: String
    var relativePath: String?

    init(draft: LocalProjectCreationDraft) {
        name = draft.name
        deviceID = draft.deviceID
        workspaceID = draft.workspaceID
        relativePath = draft.relativePath
    }

    enum CodingKeys: String, CodingKey {
        case name
        case deviceID = "device_id"
        case workspaceID = "workspace_id"
        case relativePath = "relative_path"
    }
}

private struct BindContactRequest: Encodable {
    var contactID: String

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
    }
}

private struct CreatedProjectDTO: Decodable {
    var id: String
    var name: String
    var rootPath: String?
    var displayRootPath: String?
    var latestConversationID: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case rootPath = "root_path"
        case displayRootPath = "display_root_path"
        case latestConversationID = "latest_session_id"
    }

    var domainModel: WorkspaceProject {
        WorkspaceProject(
            id: id,
            name: name,
            rootPath: rootPath,
            displayRootPath: displayRootPath ?? rootPath,
            latestConversationID: latestConversationID
        )
    }
}

private struct ProjectContactLinkDTO: Decodable {
    var contactID: String?

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
    }
}

private extension String {
    var pathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? self
    }
}

private extension CharacterSet {
    static let urlPathComponentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/?#")
        return set
    }()
}
