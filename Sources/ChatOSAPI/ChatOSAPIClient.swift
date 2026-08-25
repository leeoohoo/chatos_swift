import ChatOSCore
import Foundation

public actor ChatOSAPIClient {
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var clientSurface: String

        public init(
            baseURL: URL,
            clientSurface: String = "local-connector-desktop"
        ) {
            self.baseURL = baseURL
            self.clientSurface = clientSurface
        }
    }

    private let configuration: Configuration
    private let transport: any HTTPTransport
    private let credentialStore: (any CredentialStoring)?
    private let decoder: JSONDecoder
    private var accessToken: String?

    public init(
        configuration: Configuration,
        accessToken: String? = nil,
        credentialStore: (any CredentialStoring)? = nil,
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.configuration = configuration
        self.accessToken = accessToken?.trimmedNonEmpty
        self.credentialStore = credentialStore
        self.transport = transport
        self.decoder = JSONDecoder()
    }

    public func setAccessToken(_ token: String?) async throws {
        accessToken = token?.trimmedNonEmpty
        if let accessToken {
            try await credentialStore?.saveAccessToken(accessToken)
        } else {
            try await credentialStore?.deleteAccessToken()
        }
    }

    public func currentAccessToken() -> String? {
        accessToken
    }

    public func webSocketURL(path: String, ticket: String) -> URL? {
        let base = configuration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard var components = URLComponents(string: base + cleanedPath) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "ws_ticket", value: ticket)]
        return components.url
    }

    func request<Response: Decodable & Sendable>(
        _ endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Response {
        guard let url = makeURL(endpoint: endpoint) else {
            throw ChatOSAPIError.invalidEndpoint
        }

        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Chatos-Client-Surface": configuration.clientSurface,
        ]
        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }

        let response = try await transport.send(
            HTTPRequest(url: url, method: method, headers: headers, body: body)
        )
        if let refreshedToken = response.headers["x-access-token"]?.trimmedNonEmpty {
            accessToken = refreshedToken
            try await credentialStore?.saveAccessToken(refreshedToken)
        }
        if response.statusCode == 401 {
            accessToken = nil
            try? await credentialStore?.deleteAccessToken()
            throw ChatOSAPIError.unauthorized
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ChatOSAPIError.server(
                statusCode: response.statusCode,
                message: APIErrorPayload.message(from: response.body)
            )
        }

        do {
            return try decoder.decode(Response.self, from: response.body)
        } catch {
            throw ChatOSAPIError.decoding(error.localizedDescription)
        }
    }

    private func makeURL(endpoint: String) -> URL? {
        let base = configuration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        return URL(string: base + cleanedEndpoint)
    }
}

private struct APIErrorPayload: Decodable {
    var message: String?
    var error: String?

    static func message(from data: Data) -> String {
        guard let payload = try? JSONDecoder().decode(Self.self, from: data) else {
            return String(decoding: data, as: UTF8.self)
        }
        return payload.message ?? payload.error ?? "Request failed"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
