import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct OneOfRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema

    init?(schema: JSONSchema) {
        guard case .one = schema.value else { return nil }
        self.schema = schema
    }

    func render(key: String, context: inout Context) throws -> RenderResult? {
        let typeName = schema.identifier(as: key)
        context.nesting.append(typeName)
        defer { context.nesting.removeLast() }

        let children: [(IdentifierName, RenderResult)] = try schema.subschemas
            .compactMap { schema in
                guard let renderer = context.schemaRenderer(for: schema),
                      let result = try renderer.render(key: key, context: &context) else {
                    return nil
                }
                return (IdentifierName(result.type), result)
            }

        let enumDecl = try EnumDeclSyntax("\(accessLevel) enum \(define: typeName): Hashable, Codable") {
            for (identifier, (type, _)) in children {
                try EnumCaseDeclSyntax("""
                case \(identifier)(\(type: type))
                """)
            }

            try InitializerDeclSyntax("public init(from decoder: any Decoder) throws") {
                """
                self = try {
                    var lastError: Error!
                """

                for (identifier, (type, _)) in children {
                    """
                        do {
                            return .\(identifier)(try \(define: type)(from: decoder))
                        } catch {
                            lastError = error
                        }
                    """
                }

                """
                    throw lastError
                }()
                """
            }
            .with(\.leadingTrivia, .newlines(2))

            try FunctionDeclSyntax("\(accessLevel) func encode(to encoder: Encoder) throws") {
                try SwitchExprSyntax("switch self") {
                    for (identifier, _) in children {
                        """
                        case .\(identifier)(let value):
                            try value.encode(to: encoder)
                        """
                    }
                }
            }
            .with(\.leadingTrivia, .newlines(2))

            MemberBlockItemListSyntax {
                for (_, (_, content)) in children where !content.isEmpty {
                    "\(raw: content)"
                }
            }
            .with(\.leadingTrivia, .newlines(2))
        }

        return (typeName, enumDecl.formatted().description)
    }
}
