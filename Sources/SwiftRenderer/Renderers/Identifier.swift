import Foundation
import SwiftSyntaxBuilder

struct IdentifierName: Hashable {
    var isRenamed: Bool { rawValue != description }
    var rawValue: String
    var description: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
        self.description = {
            let sanitized = rawValue
                .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)

            let words = sanitized
                .split(separator: "_")
            let camelCased = if words.count > 1 {
                words
                   .map { $0.lowercased() }
                   .enumerated()
                   .map { index, word in
                       let word = resolveReservedWord(word.lowercased())
                       return index == 0 ? word : (word.prefix(1).uppercased() + word.dropFirst())
                   }
                   .joined()
            } else {
                if words[0].first?.isUppercase ?? false {
                    resolveReservedWord(words[0].lowercased())
                } else {
                    resolveReservedWord(String(words[0]))
                }
            }

            let result = camelCased.first?.isNumber == true ? "_" + camelCased : camelCased

            return swiftKeywords.contains(result) ? "`\(result)`" : result
        }()
    }
}

struct TypeIdentifierName: Hashable {
    var rawValue: String
    var description: String

    init(reserved: String) {
        self.rawValue = reserved
        self.description = reserved
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
        self.description = {
            let result = resolveSwiftAltTypeKeyword(rawValue.prefix(1).uppercased() + rawValue.dropFirst())

            return swiftKeywords.contains(result) ? "`\(result)`" : result
        }()
    }
}


extension SyntaxStringInterpolation {
    mutating func appendInterpolation(_ value: IdentifierName!) {
        appendInterpolation(raw: value.description)
    }

    mutating func appendInterpolation(_ value: TypeIdentifierName!) {
        appendInterpolation(raw: value.description)
    }
}

// MARK: -

private let swiftKeywords: Set<String> = [
    "class", "struct", "actor", "enum", "protocol", "func", "var", "let",
    "if", "else", "while", "for", "return", "break", "continue",
    "switch", "case", "default", "import", "extension", "deinit",
    "init", "self", "super", "true", "false", "nil", "guard", "in"
]

private let swiftAltTypeKeywords: [String: String] = [
    "Type": "ObjectType"
]

private func resolveSwiftAltTypeKeyword(_ word: String) -> String {
    swiftAltTypeKeywords[word] ?? word
}

private let reservedWords: [String: String] = [
    "os": "OS",
    "tv": "TV",
    "iphone": "iPhone",
    "ipad": "iPad",
    "ios": "iOS",
    "macos": "macOS",
    "watchos": "watchOS",
    "tvos": "tvOS",
    "visionos": "visionOS",
    "self": "current"
]

private func resolveReservedWord(_ word: String) -> String {
    reservedWords[word] ?? word
}
