import Foundation
import UIKit

struct APIUser: Codable {
    let id: Int
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
    let id: Int
    let username: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }
}

struct APIGroup: Codable, Identifiable {
    let id: Int
    let name: String
    var members: [APIFriend]
}

struct APISharedQuestion: Codable, Identifiable {
    let id: Int
    let text: String
    let poolName: String
    let itemCount: Int
    let creatorName: String
    let groupName: String
    var items: [APIQuestionItem]
    var completionCount: Int

    enum CodingKeys: String, CodingKey {
        case id, text, items
        case poolName = "pool_name"
        case itemCount = "item_count"
        case creatorName = "creator_name"
        case groupName = "group_name"
        case completionCount = "completion_count"
    }
}

struct APIQuestionItem: Codable, Identifiable {
    let id: Int
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
    let id: Int
    let participantName: String
    var entries: [APIRankingEntry]

    enum CodingKeys: String, CodingKey {
        case id, entries
        case participantName = "participant_name"
    }
}

struct APIRankingEntry: Codable {
    let rank: Int
    let itemId: Int
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
    let groupId: Int
    let text: String
    let poolName: String
    let items: [ShareQuestionItem]
    let itemCount: Int
}

struct ShareQuestionItem: Encodable {
    let name: String
    let imageData: String?
}

struct SubmitRankingRequest: Encodable {
    let username: String
    let questionId: Int
    let entries: [SubmitRankingEntry]
}

struct SubmitRankingEntry: Encodable {
    let itemId: Int
    let rank: Int
}
