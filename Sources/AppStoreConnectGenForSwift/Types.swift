// swiftlint:disable file_length
import Foundation
import AppStoreConnectGenKit

struct SortKey: Equatable, Comparable {
    let key: String

    static let highPriorities = [
        "id",
        "type",
        "attributes",
        "relationships",
        "width",
        "height"
    ]

    static func < (lhs: SortKey, rhs: SortKey) -> Bool {
        let lhsIndex = highPriorities.firstIndex(of: lhs.key)
        let rhsIndex = highPriorities.firstIndex(of: rhs.key)
        if let lhs = lhsIndex {
            if let rhs = rhsIndex {
                return lhs < rhs
            }
            return true
        }
        if rhsIndex != nil {
            return false
        }
        return lhs.key < rhs.key
    }
}

struct TypeName: RawRepresentable, Hashable, CustomStringConvertible {
    let rawValue: String
    var description: String { rawValue }

    init(rawValue: String) {
        self.rawValue = keywords.contains(rawValue)
        ? "`\(rawValue)`"
        : rawValue
    }

    init(_ key: String) {
        let key = key.upperInitialLetter()
        self.init(rawValue: key)
    }

    func withRequired(_ flag: Bool?) -> TypeName {
        TypeName(rawValue: rawValue + (flag == true ? "" : "?"))
    }
}

struct IdentifierName: RawRepresentable, Hashable, CustomStringConvertible {
    let rawValue: String
    var description: String { rawValue }

    init(rawValue: String) {
        if !rawValue.contains("-") {
            self.rawValue = rawValue
        } else {
            // special case for containing `-`
            self.rawValue = rawValue.replacingOccurrences(of: "-", with: "_").lowercased()
        }
    }

    init(_ key: String) {
        self.init(rawValue: (Self.reservedNames[key] ?? key).lowerInitialLetter())
    }

    static let reservedNames = [
        "URL": "url"
    ]
}

struct Variable {
    let key: String
    let type: TypeName
    let required: Bool
    let deprecated: Bool
    let description: String?
    let reserved: Bool

    var escapedKey: String {
        reserved ? "`\(key)`" : key
    }

    init(key: String, type: TypeName, required: Bool, deprecated: Bool, description: String?) {
        self.key = key
        self.type = type
        self.required = required
        self.deprecated = deprecated
        self.description = description
        self.reserved = keywords.contains(key)
    }
}

protocol Repr {
    init?(_ schema: OpenAPISchema, for key: String)

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName
    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl?
}

extension Repr {
    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl? { nil }
}

func findRepr(for prop: OpenAPISchema, with key: String) -> Repr {
    let targets = [
        StructRepr.self,
        EnumRepr.self,
        ArrayRepr.self,
        OneOfRepr.self,
        AnyKeyRepr.self,
        StringRepr.self,
        BooleanRepr.self,
        IntegerRepr.self,
        FloatingRepr.self,
        RefRepr.self,
        UndefinedRepr.self
    ] as [Repr.Type]

    return targets.lazy
        .compactMap { $0.init(prop, for: key) }
        .first ?? {
            fatalError("missing \(key) : \(prop)")
        }()
}

struct StructRepr: Repr {
    let properties: [String: OpenAPISchema]
    let required: Set<String>
    let key: String

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .object(let properties, let required) = schema.value else {
            return nil
        }
        self.properties = properties
        self.required = required
        self.key = key
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(key)
    }

    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl? {
        // swiftlint:disable:next large_tuple
        var result: [(
            key: String,
            variable: Variable,
            decl: Decl?
        )] = []
        for (key, value) in properties.sorted(by: { SortKey(key: $0.key) < SortKey(key: $1.key) }) {
            let required = required.contains(key)

            let repr = findRepr(for: value, with: key)
            let variable = Variable(key: key, type: repr.renderType(context: context),
                                    required: required, deprecated: value.deprecated,
                                    description: value.description)

            result.append((key, variable, repr.buildDecl(context: context)))
        }

        let name = "\(renderType(context: context))"

        return StructDecl(
            access: .public,
            name: name,
            inheritances: (context.inherits[name] ?? []) + ["Hashable", "Codable", "Sendable"],
            members: declForProperties(from: result.map(\.variable)),
            initializers: [declForInitializer(from: result.map(\.variable))],
            functions: [],
            nested: [
                declForCodingKeys(from: result.map { ($0.variable.escapedKey, $0.key) })
            ] + result.compactMap(\.decl),
            extensions: []
        )
    }
}

struct EnumRepr: Repr {
    let cases: Set<String>
    let key: String

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .enum(let cases) = schema.value else {
            return nil
        }
        self.cases = cases
        self.key = key
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(key)
    }

    // swiftlint:disable:next function_body_length
    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl? {
        var duplicatedKeys: Set<String> = []
        let caseValues: [(key: IdentifierName, raw: String)] = cases
            .sorted(by: >)
            .map { value in
                var rawKey = value.camelcased()
                if rawKey.hasPrefix("-") {
                    rawKey = String(rawKey.dropFirst()) + "Desc"
                }
                let key: IdentifierName
                if duplicatedKeys.insert(rawKey.lowercased()).inserted {
                    key = IdentifierName(rawKey)
                } else {
                    key = IdentifierName(rawValue: rawKey)
                }
                return (key, value)
            }
            .sorted(by: { $0.key.rawValue < $1.key.rawValue })

        let name = "\(renderType(context: context))"

        // do not generate `rawValue` for resource type
        if key == "type", cases.count == 1 {
            return EnumDecl(
                access: .public,
                name: name,
                inheritances: (context.inherits[name] ?? []) + ["String", "Hashable", "Codable", "Sendable"],
                cases: caseValues.map {
                    CaseDecl(name: $0.key.rawValue, value: $0.key.rawValue == $0.raw ? nil : .string($0.raw))
                }
            )
        } else {
            return StructDecl(
                access: .public,
                name: name,
                inheritances: (context.inherits[name] ?? []) + ["Hashable", "Codable", "RawRepresentable", "CustomStringConvertible", "Sendable"],
                members: caseValues.map {
                    MemberDecl(
                        access: .public,
                        modifier: .static,
                        keyword: .var,
                        name: $0.key.rawValue,
                        type: "Self",
                        value: .computed(".init(rawValue: \"\($0.raw)\")")
                    )
                } + [
                    MemberDecl(
                        access: .public,
                        keyword: .var,
                        name: "description",
                        type: "String",
                        value: .computed("rawValue")
                    ),
                    MemberDecl(
                        access: .public,
                        keyword: .var,
                        name: "rawValue",
                        type: "String"
                    )
                ],
                initializers: [
                    InitializerDecl(
                        access: .public,
                        arguments: [
                            ArgumentDecl(name: "rawValue", type: "String")
                        ],
                        body: "self.rawValue = rawValue"
                    )
                ],
                functions: []
            )
        }
    }
}

struct ArrayRepr: Repr {
    let repr: Repr

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .array(let prop) = schema.value else { return nil }
        self.repr = findRepr(for: prop, with: key)
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: "[\(repr.renderType(context: context))]")
    }

    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl? {
        repr.buildDecl(context: context)
    }
}

struct OneOfRepr: Repr {
    let props: [OpenAPISchema]
    let key: String

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .oneOf(let props) = schema.value else { return nil }
        self.props = props
        self.key = key
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(key)
    }

    // swiftlint:disable:next function_body_length
    func buildDecl(context: SwiftCodeBuilder.Context) -> Decl? {
        // swiftlint:disable:next large_tuple
        var result: [(
            key: IdentifierName,
            type: TypeName,
            decl: Decl?
        )] = []
        var used: Set<TypeName> = []
        for prop in props {
            func altName() -> String {
                switch prop.value {
                case .object: return "object"
                default: return ""
                }
            }
            let repr = findRepr(for: prop, with: altName())
            let type = repr.renderType(context: context)
            guard used.insert(type).inserted else { continue }
            result.append((IdentifierName(type.rawValue), type, repr.buildDecl(context: context)))
        }

        return EnumDecl(
            access: .public,
            name: "\(renderType(context: context))",
            inheritances: ["Hashable", "Codable", "Sendable"],
            cases: result.map {
                CaseDecl(name: $0.key.rawValue, value: .arguments([ArgumentDecl(name: "", type: "\($0.type)")]))
            },
            initializers: [
                InitializerDecl(
                    access: .public,
                    arguments: [
                        ArgumentDecl(name: "decoder", alt: "from", type: "Decoder")
                    ],
                    modifiers: [.throws],
                    body: """
                    self = try {
                        var lastError: Error!
                    \(result.map {
                        """
                            do {
                                return .\($0.key)(try \($0.type)(from: decoder))
                            } catch {
                                lastError = error
                            }
                        """
                    }.joined(separator: "\n"))
                        throw lastError
                    }()
                    """
                )
            ],
            functions: [
                FunctionDecl(
                    access: .public,
                    name: "encode",
                    arguments: [
                        ArgumentDecl(name: "encoder", alt: "to", type: "Encoder")
                    ],
                    parameterModifiers: [.throws],
                    body: """
                    switch self {
                    \(result.map {
                        """
                        case .\($0.key)(let value):
                            try value.encode(to: encoder)
                        """
                    }.joined(separator: "\n\n"))
                    }
                    """
                )
            ],
            nested: result.compactMap(\.decl),
            extensions: []
        )
    }
}

struct AnyKeyRepr: Repr {
    let repr: Repr

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .anyKey(let value) = schema.value else { return nil }
        self.repr = findRepr(for: value, with: key)
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: "[String: \(repr.renderType(context: context))]")
    }
}

struct StringRepr: Repr {
    let format: OpenAPISchema.Property.StringFormat?

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .string(let format) = schema.value else { return nil }
        self.format = format
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: {
            switch format {
            case .date, .dateTime: return "String"
            case .uri, .uriReference: return "URL"
            case .email, .number, .duration: return "String"
            case .binary: return "Data"
            case nil: return "String"
            }
        }())
    }
}

struct BooleanRepr: Repr {
    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .boolean = schema.value else { return nil }
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: "Bool")
    }
}

struct IntegerRepr: Repr {
    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .integer = schema.value else { return nil }
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: "Int")
    }
}

struct FloatingRepr: Repr {
    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .number = schema.value else { return nil }
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        TypeName(rawValue: "Float")
    }
}

struct RefRepr: Repr {
    let ref: OpenAPISchema.Ref

    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .ref(let ref) = schema.value else { return nil }
        self.ref = ref
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        if let schema = context.resolver(ref) {
            return findRepr(for: schema, with: schema.title ?? ref.key).renderType(context: context)
        }
        return TypeName(ref.key)
    }
}

struct UndefinedRepr: Repr {
    init?(_ schema: OpenAPISchema, for key: String) {
        guard case .undefined = schema.value else { return nil }
    }

    func renderType(context: SwiftCodeBuilder.Context) -> TypeName {
        return TypeName("Data")
    }
}

private func declForProperties(from props: [Variable]) -> [MemberDecl] {
    props.map {
        MemberDecl(
            annotations: $0.deprecated ? [.deprecated()] : [],
            access: .public,
            keyword: .var,
            name: $0.escapedKey,
            type: "\($0.type.withRequired($0.required))",
            doc: $0.description
        )
    }
}

private func declForCodingKeys(from props: [(key: String, value: String)]) -> Decl {
    EnumDecl(
        access: .private,
        name: "CodingKeys",
        inheritances: ["String", "CodingKey"],
        cases: props.map { key, value in
            CaseDecl(name: key, value: key == value ? nil : .string(value))
        }
    )
}

private func declForInitializer(from props: [Variable]) -> InitializerDecl {
    InitializerDecl(
        access: .public,
        arguments: props.map {
            ArgumentDecl(
                name: $0.reserved ? "_\($0.key)" : $0.key,
                alt: $0.reserved ? $0.key : nil,
                type: "\($0.type.withRequired($0.required))",
                initial: $0.required ? nil : "nil"
            )
        },
        body: props
            .map { "self.\($0.escapedKey) = \($0.reserved ? "_\($0.key)" : $0.key)" }
            .joined(separator: "\n")
    )
}
