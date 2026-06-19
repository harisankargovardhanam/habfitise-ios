import Foundation

struct AuthCredentials: Equatable {
    let email: String
    let password: String
}

struct AuthSessionInfo: Equatable {
    let userID: String
    let email: String?
}
