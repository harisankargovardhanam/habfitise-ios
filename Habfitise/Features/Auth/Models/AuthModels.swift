import Foundation
import CryptoKit

struct AuthCredentials: Equatable {
    let email: String
    let password: String
}

struct AuthSessionInfo: Equatable {
    let userID: String
    let email: String?
}

enum AuthNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            guard let character = charset.randomElement() else { continue }
            result.append(character)
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
