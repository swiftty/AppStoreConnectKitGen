import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct ObjectRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema
    var objectContext: JSONSchema.ObjectContext

    init?(schema: JSONSchema) {
        guard let objectContext = schema.objectContext else { return nil }
        self.schema = schema
        self.objectContext = objectContext
    }

    // swiftlint:disable:next function_body_length
    func render(key: String, context: inout Context) throws -> RenderResult? {
        let typeName = schema.identifier(as: key)
        context.nesting.append(typeName)
        defer { context.nesting.removeLast() }

        let children: [IdentifierName: RenderResult] = Dictionary(
            uniqueKeysWithValues: try objectContext.properties
                .compactMap { key, schema in
                    guard let renderer = context.schemaRenderer(for: schema),
                          let result = try renderer.render(key: key, context: &context) else {
                        return nil
                    }
                    return (IdentifierName(key), result)
                }
        )

        let structDecl = try StructDeclSyntax("""
        \(accessLevel) struct \(define: typeName): Hashable, Codable
        """) {
            for (key, (type, _)) in children {
                try VariableDeclSyntax("""
                \(accessLevel) var \(key): \(type: type)
                """)
            }

            let arguments = FunctionParameterListSyntax {
                for (key, (type, _)) in children {
                    FunctionParameterSyntax("\(key): \(type: type)\(raw: type.optional ? " = nil" : "")")
                        .with(\.leadingTrivia, [.newlines(1)])
                }
            }
            try InitializerDeclSyntax("""
            \(accessLevel) init(\(arguments)\n)
            """) {
                CodeBlockItemListSyntax {
                    for (key, _) in children {
                        """
                        self.\(key) = \(key)
                        """
                    }
                }
            }
            .with(\.leadingTrivia, [.newlines(2)])

            if !children.isEmpty {
                try EnumDeclSyntax("""
                private enum CodingKeys: String, CodingKey
                """) {
                    for (key, _) in children {
                        if key.isRenamed {
                            try EnumCaseDeclSyntax("case \(key) = \"\(raw: key.rawValue)\"")
                        } else {
                            try EnumCaseDeclSyntax("case \(key)")
                        }
                    }
                }
                .with(\.leadingTrivia, [.newlines(2)])
            }

            MemberBlockItemListSyntax {
                for (_, (_, content)) in children where !content.isEmpty {
                    "\(raw: content)"
                }
            }
            .with(\.leadingTrivia, [.newlines(2)])
        }

        return (typeName, structDecl.formatted().description)
    }

    private func renderProperty(
        key: String, schema: JSONSchema,
        context: inout Context, contents: inout [String]
    ) throws -> String? {
        guard let renderer = context.schemaRenderer(for: schema),
              let (type, content) = try renderer.render(key: key, context: &context) else {
            return nil
        }

        contents.append(content)
        return type.description
    }
}
