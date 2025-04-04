import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct EnumRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema
    var allowedValues: [String]

    init?(schema: JSONSchema) {
        guard schema.isString,
              let allowedValues = schema.allowedValues?.compactMap({ $0.value as? String }),
              !allowedValues.isEmpty else {
            return nil
        }
        self.schema = schema
        self.allowedValues = allowedValues
    }

    func render(key: String, context: inout Context) throws -> RenderResult? {
        let typeName = schema.identifier(as: key)
        context.nesting.append(typeName)
        defer { context.nesting.removeLast() }

        let identifiers = Dictionary(
            uniqueKeysWithValues: allowedValues.map { ($0, IdentifierName($0)) }
        )

        let structDecl = try StructDeclSyntax("""
        \(accessLevel) struct \(define: typeName): RawRepresentable, Hashable, Codable, Sendable
        """) {
            for value in allowedValues {
                try VariableDeclSyntax("""
                /// `\(raw: value)`
                \(accessLevel) static let \(identifiers[value]) = Self(rawValue: "\(raw: value)")
                """)
            }

            try VariableDeclSyntax("\(accessLevel) let rawValue: String")
                .with(\.leadingTrivia, [.newlines(2)])
                .with(\.trailingTrivia, [.newlines(2)])

            try InitializerDeclSyntax("\(accessLevel) init(rawValue: String)") {
                """
                self.rawValue = rawValue
                """
            }
        }

        return (typeName, structDecl.formatted().description)
    }
}
