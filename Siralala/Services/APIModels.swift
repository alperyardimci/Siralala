import Foundation
import UIKit

/// Flexible ID that decodes from both Int and String JSON values
struct FlexID: Codable, Hashable, Equatable, CustomStringConvertible {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = String(intVal)
        } else {
            value = try container.decode(String.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    var description: String { value }

    static func == (lhs: FlexID, rhs: FlexID) -> Bool { lhs.value == rhs.value }
}

struct APIUser: Codable {
    let id: FlexID
    let username: String
    let displayName: String
    let friendCode: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case friendCode = "friend_code"
    }
}

struct APIFriend: Codable, Identifiable, Hashable {
    let id: FlexID
    let username: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }
}

struct APIGroup: Codable, Identifiable {
    let id: FlexID
    let name: String
    var members: [APIFriend]
}

struct APISharedQuestion: Codable, Identifiable {
    let id: FlexID
    let text: String
    let poolName: String
    let itemCount: Int
    let creatorName: String
    let groupName: String
    var items: [APIQuestionItem]
    var completionCount: Int
    var maxAttempts: Int
    var userAttemptCount: Int

    enum CodingKeys: String, CodingKey {
        case id, text, items
        case poolName = "pool_name"
        case itemCount = "item_count"
        case creatorName = "creator_name"
        case groupName = "group_name"
        case completionCount = "completion_count"
        case maxAttempts = "max_attempts"
        case userAttemptCount = "user_attempt_count"
    }

    init(id: FlexID, text: String, poolName: String, itemCount: Int, creatorName: String, groupName: String, items: [APIQuestionItem], completionCount: Int, maxAttempts: Int = 1, userAttemptCount: Int = 0) {
        self.id = id; self.text = text; self.poolName = poolName; self.itemCount = itemCount
        self.creatorName = creatorName; self.groupName = groupName; self.items = items
        self.completionCount = completionCount; self.maxAttempts = maxAttempts; self.userAttemptCount = userAttemptCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(FlexID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        poolName = try c.decode(String.self, forKey: .poolName)
        itemCount = try c.decode(Int.self, forKey: .itemCount)
        creatorName = try c.decode(String.self, forKey: .creatorName)
        groupName = try c.decode(String.self, forKey: .groupName)
        items = try c.decode([APIQuestionItem].self, forKey: .items)
        completionCount = try c.decodeIfPresent(Int.self, forKey: .completionCount) ?? 0
        maxAttempts = try c.decodeIfPresent(Int.self, forKey: .maxAttempts) ?? 1
        userAttemptCount = try c.decodeIfPresent(Int.self, forKey: .userAttemptCount) ?? 0
    }
}

struct APIGroupQuestion: Codable, Identifiable {
    let id: FlexID
    let text: String
    let poolName: String
    let itemCount: Int
    let creatorId: FlexID
    let creatorName: String
    let groupName: String
    var items: [APIQuestionItem]
    var completionCount: Int
    var maxAttempts: Int
    var userAttemptCount: Int
    var userRanked: Bool

    enum CodingKeys: String, CodingKey {
        case id, text, items
        case poolName = "pool_name"
        case itemCount = "item_count"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case groupName = "group_name"
        case completionCount = "completion_count"
        case maxAttempts = "max_attempts"
        case userAttemptCount = "user_attempt_count"
        case userRanked = "user_ranked"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(FlexID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        poolName = try c.decode(String.self, forKey: .poolName)
        itemCount = try c.decode(Int.self, forKey: .itemCount)
        creatorId = try c.decode(FlexID.self, forKey: .creatorId)
        creatorName = try c.decode(String.self, forKey: .creatorName)
        groupName = try c.decode(String.self, forKey: .groupName)
        items = try c.decode([APIQuestionItem].self, forKey: .items)
        completionCount = try c.decodeIfPresent(Int.self, forKey: .completionCount) ?? 0
        maxAttempts = try c.decodeIfPresent(Int.self, forKey: .maxAttempts) ?? 1
        userAttemptCount = try c.decodeIfPresent(Int.self, forKey: .userAttemptCount) ?? 0
        userRanked = try c.decodeIfPresent(Bool.self, forKey: .userRanked) ?? false
    }

    var asSharedQuestion: APISharedQuestion {
        APISharedQuestion(id: id, text: text, poolName: poolName, itemCount: itemCount, creatorName: creatorName, groupName: groupName, items: items, completionCount: completionCount, maxAttempts: maxAttempts, userAttemptCount: userAttemptCount)
    }
}

struct APIQuestionItem: Codable, Identifiable {
    let id: FlexID
    let name: String
    let imageData: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case imageData = "image_data"
        case sortOrder = "sort_order"
    }

    var uiImage: UIImage? {
        guard let base64 = imageData, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

struct APIRanking: Codable, Identifiable {
    let id: FlexID
    let participantName: String
    var entries: [APIRankingEntry]

    enum CodingKeys: String, CodingKey {
        case id, entries
        case participantName = "participant_name"
    }
}

struct APIRankingEntry: Codable {
    let rank: Int
    let itemId: FlexID
    let itemName: String
    let itemImage: String?

    enum CodingKeys: String, CodingKey {
        case rank
        case itemId = "item_id"
        case itemName = "item_name"
        case itemImage = "item_image"
    }

    var uiImage: UIImage? {
        guard let base64 = itemImage, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

// Shared Pools
struct APISharedPool: Codable, Identifiable {
    let id: FlexID
    let name: String
    let creatorId: FlexID?
    let creatorName: String
    let groupName: String?
    let groupId: FlexID?
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case groupName = "group_name"
        case groupId = "group_id"
        case itemCount = "item_count"
    }
}

// Request bodies
struct RegisterRequest: Encodable {
    let username: String
    let displayName: String
}

struct AddFriendRequest: Encodable {
    let username: String
    let friendCode: String
}

struct CreateGroupRequest: Encodable {
    let username: String
    let name: String
    let memberUsernames: [String]
}

struct ShareQuestionRequest: Encodable {
    let username: String
    let groupId: String
    let text: String
    let poolName: String
    let items: [ShareQuestionItem]
    let itemCount: Int
    let maxAttempts: Int
}

struct ShareQuestionItem: Encodable {
    let name: String
    let imageData: String?
}

struct SubmitRankingRequest: Encodable {
    let username: String
    let questionId: String
    let entries: [SubmitRankingEntry]
}

struct SubmitRankingEntry: Encodable {
    let itemId: String
    let rank: Int
}

struct SharePoolRequest: Encodable {
    let username: String
    let groupId: String
    let name: String
    let items: [ShareQuestionItem]
}
