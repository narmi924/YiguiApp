import Foundation

struct User: Codable, Identifiable {
    let id: String
    var email: String
    var nickname: String
    var height: Int?
    var weight: Int?
    var avatarURL: URL?
    var gender: String
    
    init(id: String = UUID().uuidString, email: String, nickname: String, height: Int? = nil, weight: Int? = nil, avatarURL: URL? = nil, gender: String = "male") {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.height = height
        self.weight = weight
        self.avatarURL = avatarURL
        self.gender = gender
    }
} 