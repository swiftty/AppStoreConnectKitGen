import Foundation
import AppStoreConnectGenKit

extension EndpointRenderer {
    // swiftlint:disable:next function_body_length
    func declForGET(_ endpoint: OpenAPIEndpoint) -> Decl? {
        guard let get = endpoint.get else { return nil }

        var parametersDecl = StructDecl(
            access: .public,
            name: "Parameters",
            inheritances: ["Hashable"],
            members: [],
            initializers: [],
            functions: []
        )
        let params = buildParameters(get.content.parameters)
        // swiftlint:disable:next large_tuple
        var queryItemComponents: [(key: String?, name: String, repr: Repr, required: Bool)] = []
        for (name, root, nested) in params {
            if nested.isEmpty {
                func customInitialValue(_ repr: Repr) -> String? {
                    if repr is ArrayRepr {
                        return "[]"
                    } else {
                        return nil
                    }
                }

                var prop = root!
                prop.required = false
                let repr = findRepr(for: prop.schema, with: name)
                let type = repr.renderType(context: context)
                parametersDecl.members.append(MemberDecl(
                    access: .public,
                    keyword: .var,
                    name: name,
                    type: "\(type.withRequired(prop.required))",
                    value: prop.required ?? false ? customInitialValue(repr).map { .assignment($0) } : nil,
                    doc: prop.description)
                )
                if let nested = repr.buildDecl(context: context) {
                    parametersDecl.nested.append(nested)
                }
                queryItemComponents.append((nil, name, repr, prop.required ?? false))
            } else {
                let type = TypeName(name)
                var nested = declForNestedParameter(nested, for: name, with: context,
                                                    queryItemComponents: &queryItemComponents)
                if let root = root {
                    let repr = findRepr(for: root.schema, with: "")
                    let type = repr.renderType(context: context).withRequired(root.required)
                    nested.subscripts = [
                        SubscriptDecl(
                            access: .public,
                            arguments: [],
                            returnType: "\(type)",
                            getter: """
                            self[Relation<\(type)>(key: "\(name)")]
                            """,
                            setter: """
                            self[Relation<\(type)>(key: "\(name)")] = newValue
                            """
                        )
                    ] + nested.subscripts
                    queryItemComponents.append((name, name + "[]", repr, root.required ?? false))
                }
                parametersDecl.members.append(MemberDecl(
                    access: .public,
                    keyword: .var,
                    name: name,
                    type: "\(type)",
                    value: .assignment("\(type)()"),
                    doc: root?.description)
                )
                parametersDecl.nested.append(nested)
            }
        }
        var methodDecl = declForMethod(get, name: "GET", parameters: endpoint.parameters ?? [])
        methodDecl.inheritances.append("Endpoint")
        methodDecl.members.append(MemberDecl(
            access: .public,
            keyword: .var,
            name: "parameters",
            type: "Parameters",
            value: .assignment("Parameters()")
        ))
        methodDecl.extensions.append(parametersDecl)
        func buildQueryItem(key: String? = nil, name: String, repr: Repr, required: Bool) -> String {
            var value: String {
                switch repr {
                case is ArrayRepr:
                    return """
                    parameters.\(name)\(required ? "" : "?").map { "\\($0)" }.joined(separator: ",")
                    """

                default:
                    return """
                    parameters.\(name).map { "\\($0)" }
                    """
                }
            }
            return """
            URLQueryItem(name: "\(key ?? name)",
                         value: \(value))
            """
        }

        methodDecl.functions = [
            FunctionDecl(
                access: .public,
                name: "request",
                arguments: [
                    ArgumentDecl(
                        name: "baseURL",
                        alt: "with",
                        type: "URL"
                    )
                ],
                parameterModifiers: [.throws],
                returnType: "URLRequest?",
                body: """
                var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
                components?.path = path

                components?.queryItems = [
                \(queryItemComponents.map(buildQueryItem).joined(separator: ",\n").indent(to: 4))
                ].filter { $0.value != nil }
                if components?.queryItems?.isEmpty ?? false {
                    components?.queryItems = nil
                }

                var urlRequest = components?.url.map { URLRequest(url: $0) }
                urlRequest?.httpMethod = "GET"
                return urlRequest
                """
            )
        ] + methodDecl.functions
        return methodDecl
    }
}

// swiftlint:disable:next large_tuple
private typealias ParameterPack = (name: String,
                                   root: OpenAPIEndpoint.Parameter?,
                                   nested: [OpenAPIEndpoint.Parameter])

private func buildParameters(_ parameters: [OpenAPIEndpoint.Parameter]?) -> [ParameterPack] {
    var used: Set<String> = []
    var parameters = parameters?
        .filter { used.insert($0.name).inserted }
        .sorted(by: { $0.name < $1.name }) ?? []

    var result: [ParameterPack] = []
    while !parameters.isEmpty {
        if let p = consumeParameter(&parameters) {
            result.append(p)
        }
    }

    return result
}

private func consumeParameter(_ parameters: inout [OpenAPIEndpoint.Parameter]) -> ParameterPack? {
    let param = parameters.removeFirst()
    let isNested = param.name.contains("[")
    let name = isNested
        ? param.name.components(separatedBy: "[")[0]
        : param.name

    enum Match {
        case exact
        case prefix
    }
    func matchName(_ target: String) -> Match? {
        if target == name {
            return .exact
        }
        if target.hasPrefix(name + "[") {
            return .prefix
        }
        return nil
    }

    var root: OpenAPIEndpoint.Parameter? = isNested ? nil : param
    var nested: [OpenAPIEndpoint.Parameter] = isNested ? [param] : []
    while let p = parameters.first, let match = matchName(p.name) {
        parameters.removeFirst()

        switch match {
        case .exact:
            assert(root == nil)
            root = p

        case .prefix:
            nested.append(p)
        }
    }

    return (name, root, nested)
}

// swiftlint:disable:next function_body_length
private func declForNestedParameter(
    _ nestedParameters: [OpenAPIEndpoint.Parameter],
    for keyName: String,
    with context: SwiftCodeBuilder.Context,
    // swiftlint:disable:next large_tuple
    queryItemComponents: inout [(key: String?, name: String, repr: Repr, required: Bool)]
) -> StructDecl {
    func makeKey(_ target: String) -> String {
        let key = String(target.components(separatedBy: "[")[1].dropLast())
        return key.components(separatedBy: ".")
            .map { $0.upperInitialLetter() }
            .joined()
            .lowerInitialLetter()
    }

    func nestedRelationDecl(_ p: OpenAPIEndpoint.Parameter) -> Decl? {
        let name = makeKey(p.name)
        let repr = findRepr(for: p.schema, with: name)
        return repr.buildDecl(context: context)
    }

    func relationMemberDecl(_ p: OpenAPIEndpoint.Parameter) -> MemberDecl {
        let name = makeKey(p.name)
        let repr = findRepr(for: p.schema, with: name)
        let innerType = repr.renderType(context: context)
        let type = TypeName(rawValue: "Relation<\(innerType.withRequired(false))>")
        let variable = Variable(key: name, type: type,
                                required: true, deprecated: p.schema.deprecated,
                                description: p.description)

        func doc() -> String? {
            let required = p.required ?? false
            return variable.description.map {
                $0 + (required ? " **(required)**" : "")
            } ?? (required ? "**(required)**" : nil)
        }

        queryItemComponents.append((p.name, keyName + "[.\(variable.escapedKey)]", repr, false))

        return MemberDecl(
            access: .public,
            modifier: .static,
            keyword: .var,
            name: variable.escapedKey,
            type: "\(variable.type)",
            value: .computed("""
            .init(key: "\(p.name)")
            """),
            doc: doc()
        )
    }

    return StructDecl(
        access: .public,
        name: "\(TypeName(keyName))",
        inheritances: ["Hashable"],
        subscripts: [
            SubscriptDecl(
                access: .public,
                generics: "T: Hashable",
                arguments: [
                    ArgumentDecl(
                        name: "relation",
                        alt: "_",
                        type: "Relation<T>"
                    )
                ],
                returnType: "T",
                getter: "values[relation]?.base as! T",
                setter: "values[relation] = AnyHashable(newValue)"
            )
        ].compactMap { $0 },
        members: [
            MemberDecl(
                access: .private,
                keyword: .var,
                name: "values",
                type: "[AnyHashable: AnyHashable]",
                value: .assignment("[:]")
            )
        ],
        initializers: [],
        functions: [],
        nested: nestedParameters.compactMap(nestedRelationDecl) + [
            StructDecl(
                access: .public,
                name: "Relation<T>",
                inheritances: ["Hashable"],
                subscripts: [
                ],
                members: nestedParameters.map(relationMemberDecl) + [
                    MemberDecl(
                        access: .internal,
                        keyword: .let,
                        name: "key",
                        type: "String"
                    )
                ],
                initializers: [],
                functions: [
                    FunctionDecl(
                        access: .public,
                        name: "hash",
                        arguments: [
                            ArgumentDecl(
                                name: "hasher",
                                alt: "into",
                                type: "inout Hasher"
                            )
                        ],
                        body: "hasher.combine(key)"
                    )
                ],
                nested: [],
                extensions: []
            )
        ],
        extensions: []
    )
}
