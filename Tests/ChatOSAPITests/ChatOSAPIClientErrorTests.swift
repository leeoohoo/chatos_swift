import ChatOSCore
import Foundation
import XCTest
@testable import ChatOSAPI

final class ChatOSAPIClientErrorTests: XCTestCase {
    func testHTMLGatewayFailureUsesFriendlyMessage() async throws {
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            transport: APIErrorTransport(
                response: HTTPResponse(
                    statusCode: 503,
                    headers: ["content-type": "text/html"],
                    body: Data("<html><body>Service Unavailable</body></html>".utf8)
                )
            )
        )

        do {
            let _: ErrorResponseDTO = try await client.request("/history")
            XCTFail("Expected request to fail")
        } catch let error as ChatOSAPIError {
            XCTAssertEqual(
                error,
                .server(statusCode: 503, message: "服务正在启动或暂时不可用，请稍后重试。")
            )
        }
    }

    func testNestedJSONErrorMessageIsPreserved() async throws {
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            transport: APIErrorTransport(
                response: HTTPResponse(
                    statusCode: 404,
                    headers: ["content-type": "application/json"],
                    body: Data(#"{"error":{"code":"not_found","message":"请求的资源不存在"}}"#.utf8)
                )
            )
        )

        do {
            let _: ErrorResponseDTO = try await client.request("/missing")
            XCTFail("Expected request to fail")
        } catch let error as ChatOSAPIError {
            XCTAssertEqual(
                error,
                .serverDetail(
                    statusCode: 404,
                    message: "请求的资源不存在",
                    code: "not_found",
                    challengePrompt: nil
                )
            )
        }
    }
}

private struct ErrorResponseDTO: Decodable, Sendable {}

private struct APIErrorTransport: HTTPTransport {
    var response: HTTPResponse

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        response
    }
}
