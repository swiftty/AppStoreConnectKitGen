import OpenAPIKit30
import SwiftSyntax
import SwiftSyntaxBuilder

struct StructRenderer: ComponentRenderer {
    var accessLevel: AccessLevel = .public
    var schema: JSONSchema
    var objectContext: JSONSchema.ObjectContext

    init?(schema: JSONSchema) {
        guard let objectContext = schema.objectContext else { return nil }
        self.schema = schema
        self.objectContext = objectContext
    }

    func render(key: OpenAPI.ComponentKey, context: inout Context) throws -> RenderResult? {
        var children: [Types.IdentifierName: RenderResult] = [:]
        let typeName = Types.TypeIdentifierName(schema.title ?? key.rawValue)
        context.nesting.append(typeName.description)
        defer { context.nesting.removeLast() }

        children = Dictionary(
            uniqueKeysWithValues: try objectContext.properties
                .compactMap { key, schema in
                    guard let renderer = context.schemaRenderer(for: schema),
                          let (type, content) = try renderer.render(key: .init(stringLiteral: key), context: &context) else {
                        return nil
                    }
                    return (Types.IdentifierName(key), (type, content))
                }
        )

        let structDecl = try StructDeclSyntax("""
        \(accessLevel) struct \(typeName): Hashable
        """) {
            for (key, (type, _)) in children {
                try VariableDeclSyntax("""
                \(accessLevel) var \(key): \(raw: type)
                """)
            }
        }

        if !children.isEmpty {
            do {
                let extensionDecl = try ExtensionDeclSyntax("""
                \(accessLevel) extension \(raw: context.nesting.joined(separator: ".")): Codable
                """) {
                    try EnumDeclSyntax("""
                    private enum CodingKeys: String, CodingKey
                    """) {
                        for (key, _) in children {
                            try EnumCaseDeclSyntax("case \(key) = \"\(raw: key.rawValue)\"")
                        }
                    }
                }
                context.extensions.append(extensionDecl.formatted().description)
            }
            do {
                let extensionDecl = try ExtensionDeclSyntax("""
                \(accessLevel) extension \(raw: context.nesting.joined(separator: "."))
                """) {
                    for (_, (_, content)) in children {
                        "\(raw: content)"
                    }
                }
                context.extensions.append(extensionDecl.formatted().description)
            }
        }

        return (typeName.description, structDecl.formatted().description)
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
