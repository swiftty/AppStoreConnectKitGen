import Foundation
import OpenAPIKit30

public typealias OpenAPIEndpoints = [String: OpenAPIEndpoint]

public struct OpenAPIEndpoint: Decodable {
    public var get: RequestMethod<Operations.GET>?
    public var post: RequestMethod<Operations.POST>?
    public var patch: RequestMethod<Operations.PATCH>?
    public var delete: RequestMethod<Operations.DELETE>?
    public var parameters: [Parameter]?

    public var hasMethod: Bool {
        return get != nil
            || post != nil
            || patch != nil
            || delete != nil
    }

    public init(from decoder: any Decoder) throws {
        let path = try OpenAPI.PathItem(from: decoder)
        get = path.get.map { .init($0, buildContent: Operations.GET.init) }
        post = path.post.map { .init($0, buildContent: Operations.POST.init) }
        patch = path.patch.map { .init($0, buildContent: Operations.PATCH.init) }
        delete = path.delete.map { .init($0, buildContent: Operations.DELETE.init) }
        parameters = path.parameters.compactMap(\.parameterValue).compactMap { .init($0) }
    }
}

public protocol RequestMethodProviding {
    init(_ operation: OpenAPI.Operation)
}

extension OpenAPIEndpoint {
    public struct RequestMethod<T> {
        public var tags: Set<String>
        public var deprecated: Bool
        public var responses: [String: Response]
        public var content: T

        private enum CodingKeys: String, CodingKey {
            case tags, responses, deprecated
        }

        public init(_ operation: OpenAPI.Operation, buildContent: (OpenAPI.Operation) -> T) {
            tags = Set(operation.tags ?? [])
            responses = operation.responses.reduce(into: [:]) { result, next in
                if let value = next.value.responseValue {
                    result[next.key.rawValue] = .init(value)
                }
            }
            deprecated = operation.deprecated
            content = buildContent(operation)
        }
    }
}

extension OpenAPIEndpoint {
    public enum Operations {
        public struct GET {
            public var parameters: [Parameter]

            init(_ operation: OpenAPI.Operation) {
                parameters = operation.parameters
                    .compactMap(\.parameterValue)
                    .compactMap(OpenAPIEndpoint.Parameter.init)
            }
        }

        public struct POST {
            public var requestBody: RequestBody

            init(_ operation: OpenAPI.Operation) {
                requestBody = .init(operation.requestBody?.requestValue)
            }
        }

        public struct PATCH {
            public var requestBody: RequestBody

            init(_ operation: OpenAPI.Operation) {
                requestBody = .init(operation.requestBody?.requestValue)
            }
        }

        public struct DELETE {
            init(_ operation: OpenAPI.Operation) {}
        }
    }
}

extension OpenAPIEndpoint {
    public struct Parameter {
        public var name: String
        public var `in`: Location
        public var description: String?
        public var schema: OpenAPISchema
        public var required: Bool?

        public enum Location: String, Decodable {
            case path, query
        }

        init?(_ parameter: OpenAPI.Parameter) {
            guard let location = Location(rawValue: parameter.location.rawValue),
                  let schema = parameter.schemaOrContent.schemaValue
            else { return nil }
            name = parameter.name
            `in` = location
            description = parameter.description
            required = parameter.required
            self.schema = .init(schema)
        }
    }

    public struct RequestBody {
        public var description: String?
        public var content: [String: Content]
        public var required: Bool?

        public struct Content {
            public var schema: OpenAPISchema
        }

        init(_ body: OpenAPI.Request?) {
            description = body?.description
            required = body?.required ?? false
            content = body?.content.reduce(into: [:]) { result, next in
                result[next.key.rawValue] = switch next.value.schema {
                case .a(let ref):
                    Content(schema: .init(ref))

                case .b(let schema):
                    Content(schema: .init(schema))

                case nil:
                    nil
                }
            } ?? [:]
        }
    }
}

extension OpenAPIEndpoint {
    public struct Response {
        public var description: String?
        public var content: [String: Content]

        public struct Content {
            public var schema: OpenAPISchema
        }

        init(_ response: OpenAPI.Response) {
            description = response.description
            content = response.content.reduce(into: [:]) { result, next in
                result[next.key.rawValue] = switch next.value.schema {
                case .a(let ref):
                    Content(schema: .init(ref))

                case .b(let schema):
                    Content(schema: .init(schema))

                case nil:
                    nil
                }
            }
        }
    }
}
