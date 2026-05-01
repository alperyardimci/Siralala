import Foundation

@Observable
final class APIService {
    static let shared = APIService()

    let baseURL = "https://firebase-nu-swart.vercel.app/api"
    var currentUser: APIUser?

    // MARK: - Cache
    private var cache: [String: (data: Any, time: Date)] = [:]
    private let cacheTTL: TimeInterval = 30 // seconds

    private func cached<T>(_ key: String) -> T? {
        guard let entry = cache[key],
              Date().timeIntervalSince(entry.time) < cacheTTL,
              let data = entry.data as? T else { return nil }
        return data
    }

    private func setCache<T>(_ key: String, _ data: T) {
        cache[key] = (data: data, time: Date())
    }

    func invalidateCache(_ key: String? = nil) {
        if let key { cache.removeValue(forKey: key) } else { cache.removeAll() }
    }

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
        let key = "me_\(username)"
        if let c: APIUser = cached(key) { currentUser = c; return c }
        let user: APIUser = try await request("GET", path: "/users/me?username=\(username.urlEncoded)")
        currentUser = user
        setCache(key, user)
        return user
    }

    func searchUser(code: String) async throws -> APIFriend {
        return try await request("GET", path: "/users/search?code=\(code)")
    }

    // MARK: - Friends

    func addFriend(code: String) async throws -> APIFriend {
        struct AddResponse: Decodable { let success: Bool; let friend: APIFriend }
        let resp: AddResponse = try await request("POST", path: "/friends/add", body: AddFriendRequest(username: username, friendCode: code))
        invalidateCache("friends_\(username)")
        return resp.friend
    }

    func getFriends() async throws -> [APIFriend] {
        let key = "friends_\(username)"
        if let c: [APIFriend] = cached(key) { return c }
        let result: [APIFriend] = try await request("GET", path: "/friends?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    func removeFriend(id: String) async throws {
        try await requestVoid("DELETE", path: "/friends/\(id)?username=\(username.urlEncoded)")
        invalidateCache("friends_\(username)")
    }

    // MARK: - Groups

    func createGroup(name: String, memberUsernames: [String]) async throws -> APIGroup {
        let group: APIGroup = try await request("POST", path: "/groups", body: CreateGroupRequest(username: username, name: name, memberUsernames: memberUsernames))
        invalidateCache("groups_\(username)")
        return group
    }

    func getGroups() async throws -> [APIGroup] {
        let key = "groups_\(username)"
        if let c: [APIGroup] = cached(key) { return c }
        let result: [APIGroup] = try await request("GET", path: "/groups?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    func deleteGroup(id: String) async throws {
        try await requestVoid("DELETE", path: "/groups/\(id)")
        invalidateCache("groups_\(username)")
    }

    func addGroupMember(groupId: String, memberUsername: String) async throws {
        try await requestVoid("POST", path: "/groups/\(groupId)/members", body: ["username": memberUsername])
        invalidateCache("groups_\(username)")
    }

    func getGroupQuestions(groupId: String) async throws -> [APIGroupQuestion] {
        let key = "gq_\(groupId)"
        if let c: [APIGroupQuestion] = cached(key) { return c }
        let result: [APIGroupQuestion] = try await request("GET", path: "/groups/\(groupId)/questions?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    // MARK: - Shared Pools

    func sharePool(groupId: String, name: String, items: [ShareQuestionItem]) async throws {
        try await requestVoid("POST", path: "/pools/share", body: SharePoolRequest(
            username: username, groupId: groupId, name: name, items: items
        ))
        invalidateCache("sharedPools_\(username)")
        invalidateCache("gp_\(groupId)")
    }

    func getGroupPools(groupId: String) async throws -> [APISharedPool] {
        let key = "gp_\(groupId)"
        if let c: [APISharedPool] = cached(key) { return c }
        let result: [APISharedPool] = try await request("GET", path: "/groups/\(groupId)/pools")
        setCache(key, result)
        return result
    }

    func getAllSharedPools() async throws -> [APISharedPool] {
        let key = "sharedPools_\(username)"
        if let c: [APISharedPool] = cached(key) { return c }
        let result: [APISharedPool] = try await request("GET", path: "/pools/shared?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    func getPoolItems(poolId: String) async throws -> [APIQuestionItem] {
        let key = "poolItems_\(poolId)"
        if let c: [APIQuestionItem] = cached(key) { return c }
        let result: [APIQuestionItem] = try await request("GET", path: "/pools/\(poolId)/items")
        setCache(key, result)
        return result
    }

    // MARK: - Questions

    func shareQuestion(groupId: String, text: String, poolName: String, items: [ShareQuestionItem], itemCount: Int, maxAttempts: Int = 1) async throws {
        try await requestVoid("POST", path: "/questions", body: ShareQuestionRequest(
            username: username, groupId: groupId, text: text, poolName: poolName, items: items, itemCount: itemCount, maxAttempts: maxAttempts
        ))
        invalidateCache("pending_\(username)")
        invalidateCache("gq_\(groupId)")
    }

    func getPendingQuestions() async throws -> [APISharedQuestion] {
        let key = "pending_\(username)"
        if let c: [APISharedQuestion] = cached(key) { return c }
        let result: [APISharedQuestion] = try await request("GET", path: "/questions/pending?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    func getCompletedQuestions() async throws -> [APISharedQuestion] {
        let key = "completed_\(username)"
        if let c: [APISharedQuestion] = cached(key) { return c }
        let result: [APISharedQuestion] = try await request("GET", path: "/questions/completed?username=\(username.urlEncoded)")
        setCache(key, result)
        return result
    }

    func dismissQuestion(id: String) async throws {
        struct DismissBody: Encodable { let username: String }
        try await requestVoid("POST", path: "/questions/\(id)/dismiss", body: DismissBody(username: username))
        invalidateCache("pending_\(username)")
        invalidateCache("completed_\(username)")
    }

    func deleteQuestion(id: String) async throws {
        try await requestVoid("DELETE", path: "/questions/\(id)?username=\(username.urlEncoded)")
        invalidateCache("pending_\(username)")
        invalidateCache("completed_\(username)")
    }

    func deleteSharedPool(id: String) async throws {
        try await requestVoid("DELETE", path: "/pools/\(id)?username=\(username.urlEncoded)")
        invalidateCache("sharedPools_\(username)")
    }

    // MARK: - Rankings

    func submitRanking(questionId: String, entries: [SubmitRankingEntry]) async throws {
        try await requestVoid("POST", path: "/rankings", body: SubmitRankingRequest(
            username: username, questionId: questionId, entries: entries
        ))
        invalidateCache("pending_\(username)")
        invalidateCache("completed_\(username)")
        invalidateCache("rankings_\(questionId)")
    }

    func getRankings(questionId: String) async throws -> [APIRanking] {
        let key = "rankings_\(questionId)"
        if let c: [APIRanking] = cached(key) { return c }
        let result: [APIRanking] = try await request("GET", path: "/rankings?questionId=\(questionId)")
        setCache(key, result)
        return result
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
