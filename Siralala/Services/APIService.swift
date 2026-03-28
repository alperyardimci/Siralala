import Foundation

@Observable
final class APIService {
    static let shared = APIService()

    let baseURL = "http://localhost:3000/api"
    var currentUser: APIUser?

    var username: String {
        UserDefaults.standard.string(forKey: "userName") ?? ""
    }

    private init() {}

    // MARK: - Generic Request

    private func request<T: Decodable>(_ method: String, path: String, body: (any Encodable)? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let http = response as? HTTPURLResponse
            throw APIError.serverError(http?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func requestVoid(_ method: String, path: String, body: (any Encodable)? = nil) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let http = response as? HTTPURLResponse
            throw APIError.serverError(http?.statusCode ?? 0)
        }
    }

    // MARK: - Users

    func register(username: String, displayName: String) async throws -> APIUser {
        let user: APIUser = try await request("POST", path: "/users/register", body: RegisterRequest(username: username, displayName: displayName))
        currentUser = user
        return user
    }

    func getMe() async throws -> APIUser {
        let user: APIUser = try await request("GET", path: "/users/me?username=\(username.urlEncoded)")
        currentUser = user
        return user
    }

    func searchUser(code: String) async throws -> APIFriend {
        return try await request("GET", path: "/users/search?code=\(code)")
    }

    // MARK: - Friends

    func addFriend(code: String) async throws -> APIFriend {
        struct AddResponse: Decodable { let success: Bool; let friend: APIFriend }
        let resp: AddResponse = try await request("POST", path: "/friends/add", body: AddFriendRequest(username: username, friendCode: code))
        return resp.friend
    }

    func getFriends() async throws -> [APIFriend] {
        return try await request("GET", path: "/friends?username=\(username.urlEncoded)")
    }

    func removeFriend(id: Int) async throws {
        try await requestVoid("DELETE", path: "/friends/\(id)?username=\(username.urlEncoded)")
    }

    // MARK: - Groups

    func createGroup(name: String, memberUsernames: [String]) async throws -> APIGroup {
        return try await request("POST", path: "/groups", body: CreateGroupRequest(username: username, name: name, memberUsernames: memberUsernames))
    }

    func getGroups() async throws -> [APIGroup] {
        return try await request("GET", path: "/groups?username=\(username.urlEncoded)")
    }

    func deleteGroup(id: Int) async throws {
        try await requestVoid("DELETE", path: "/groups/\(id)")
    }

    func getGroupQuestions(groupId: Int) async throws -> [APIGroupQuestion] {
        return try await request("GET", path: "/groups/\(groupId)/questions?username=\(username.urlEncoded)")
    }

    // MARK: - Questions

    func shareQuestion(groupId: Int, text: String, poolName: String, items: [ShareQuestionItem], itemCount: Int) async throws {
        try await requestVoid("POST", path: "/questions", body: ShareQuestionRequest(
            username: username, groupId: groupId, text: text, poolName: poolName, items: items, itemCount: itemCount
        ))
    }

    func getPendingQuestions() async throws -> [APISharedQuestion] {
        return try await request("GET", path: "/questions/pending?username=\(username.urlEncoded)")
    }

    func getCompletedQuestions() async throws -> [APISharedQuestion] {
        return try await request("GET", path: "/questions/completed?username=\(username.urlEncoded)")
    }

    func deleteQuestion(id: Int) async throws {
        try await requestVoid("DELETE", path: "/questions/\(id)")
    }

    // MARK: - Rankings

    func submitRanking(questionId: Int, entries: [SubmitRankingEntry]) async throws {
        try await requestVoid("POST", path: "/rankings", body: SubmitRankingRequest(
            username: username, questionId: questionId, entries: entries
        ))
    }

    func getRankings(questionId: Int) async throws -> [APIRanking] {
        return try await request("GET", path: "/rankings?questionId=\(questionId)")
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz URL"
        case .serverError(let code): return "Sunucu hatası: \(code)"
        }
    }
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
