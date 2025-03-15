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

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        var children: [IdentifierName: RenderResult] = [:]
        let typeName = TypeIdentifierName(schema.title ?? key.rawValue)
        context.nesting.append(typeName.description)
        defer { context.nesting.removeLast() }

        children = Dictionary(
            uniqueKeysWithValues: try objectContext.properties
                .compactMap { key, schema in
                    guard let renderer = context.schemaRenderer(for: schema),
                          let (type, content) = try renderer.render(key: .init(stringLiteral: key), context: &context) else {
                        return nil
                    }
                    return (IdentifierName(key), (type, content))
                }
        )

        let structDecl = try StructDeclSyntax("""
        \(accessLevel) struct \(typeName): Hashable
        """) {
            for (key, (type, _)) in children {
                try VariableDeclSyntax("""
                \(accessLevel) var \(key): \(type)
                """)
            }

            let arguments = FunctionParameterListSyntax {
                for (key, (type, _)) in children {
                    FunctionParameterSyntax("\(key): \(type)")
                }
            }
            try InitializerDeclSyntax("""
            \(accessLevel) init(\(arguments))
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

            for (_, (_, content)) in children where !content.isEmpty {
                "\(raw: content)"
            }
        }

        return (typeName, structDecl.formatted().description)
    }

    private func renderProperty(
        key: String, schema: JSONSchema,
        context: inout Context, contents: inout [String]
    ) throws -> String? {
        guard let renderer = context.schemaRenderer(for: schema),
              let (type, content) = try renderer.render(key: .init(stringLiteral: key), context: &context) else {
            return nil
        }

        contents.append(content)
        return type.description
    }
}
