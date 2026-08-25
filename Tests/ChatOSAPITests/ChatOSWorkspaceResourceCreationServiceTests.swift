import ChatOSCore
import Foundation
import XCTest
@testable import ChatOSAPI

final class ChatOSWorkspaceResourceCreationServiceTests: XCTestCase {
    func testCreatesLocalProjectAndBindsDefaultContact() async throws {
        let transport = ResourceCreationTransport()
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            accessToken: "token",
            transport: transport
        )
        let service = ChatOSWorkspaceResourceCreationService(client: client)

        let project = try await service.createLocalProject(.init(
            name: "Swift App",
            deviceID: "device-1",
            workspaceID: "workspace-1",
            relativePath: "projects/swift-app"
        ))
        try await service.bindContact(projectID: project.id, contactID: "contact-default")

        XCTAssertEqual(project.id, "project/1")
        XCTAssertEqual(project.rootPath, "local://connector/device-1/workspace-1/projects/swift-app")
        XCTAssertEqual(project.displayRootPath, "projects/swift-app")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.path), [
            "/api/chatos/local-connectors/projects",
            "/api/chatos/projects/project%2F1/contacts",
        ])
        XCTAssertEqual(requests.map(\.method), ["POST", "POST"])

        let projectBody = try XCTUnwrap(requests.first?.body)
        let projectJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: projectBody) as? [String: Any]
        )
        XCTAssertEqual(projectJSON["name"] as? String, "Swift App")
        XCTAssertEqual(projectJSON["device_id"] as? String, "device-1")
        XCTAssertEqual(projectJSON["workspace_id"] as? String, "workspace-1")
        XCTAssertEqual(projectJSON["relative_path"] as? String, "projects/swift-app")

        let contactBody = try XCTUnwrap(requests.last?.body)
        let contactJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: contactBody) as? [String: Any]
        )
        XCTAssertEqual(contactJSON["contact_id"] as? String, "contact-default")
    }
}

private actor ResourceCreationTransport: HTTPTransport {
    struct RecordedRequest: Sendable {
        var path: String
        var method: String
        var body: Data?
    }

    private var requests: [RecordedRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(.init(
            path: request.url.path(percentEncoded: true),
            method: request.method,
            body: request.body
        ))
        switch request.url.path(percentEncoded: true) {
        case "/api/chatos/local-connectors/projects":
            return HTTPResponse(
                statusCode: 201,
                headers: [:],
                body: Data(#"{"id":"project/1","name":"Swift App","root_path":"local://connector/device-1/workspace-1/projects/swift-app","display_root_path":"projects/swift-app","latest_session_id":null}"#.utf8)
            )
        case "/api/chatos/projects/project%2F1/contacts":
            return HTTPResponse(
                statusCode: 200,
                headers: [:],
                body: Data(#"{"contact_id":"contact-default"}"#.utf8)
            )
        default:
            return HTTPResponse(statusCode: 404, headers: [:], body: Data())
        }
    }

    func recordedRequests() -> [RecordedRequest] { requests }
}
