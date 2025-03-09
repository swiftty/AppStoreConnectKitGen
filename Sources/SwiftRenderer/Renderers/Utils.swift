import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import AppStoreConnectKitGen

enum AccessLevel: String {
    case `public` = "public"
    case `package` = "package"
    case `internal` = "internal"
    case `fileprivate` = "fileprivate"
    case `private` = "private"
}

extension SyntaxStringInterpolation {
    mutating func appendInterpolation(_ value: AccessLevel) {
        appendLiteral(value.rawValue)
    }
}
