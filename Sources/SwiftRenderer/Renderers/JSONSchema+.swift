import OpenAPIKit30

extension JSONSchema {
    func identifier(reserved key: String) -> TypeIdentifierName {
        .init(reserved: key, optional: !required)
    }

    func identifier(as key: String) -> TypeIdentifierName {
        .init(title ?? key, optional: !required)
    }
}
