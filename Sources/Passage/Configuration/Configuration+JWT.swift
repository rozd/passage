import Foundation
import JWT

// MARK: - JWT & JWKS Configuration

public extension Passage.Configuration {

    struct JWT: Sendable {
        let jwks: JWKS

        public init(jwks: JWKS) {
            self.jwks = jwks
        }
    }

}

// MARK: - JWKS Configuration

public extension Passage.Configuration.JWT {

    struct JWKS: Sendable {
        let json: String

        public init(json: String) {
            self.json = json
        }
    }

}

// MARK: JWKS Convenience Initializers

public extension Passage.Configuration.JWT.JWKS {

    static func environment(name: String = "JWKS") throws -> Self {
        guard let json = ProcessInfo.processInfo.environment[name] else {
            throw PassageError.missingEnvironmentVariable(name: name)
        }
        return .init(json: json)
    }

    static func file(path: String) throws -> Self {
        let json = try String(contentsOfFile: path, encoding: .utf8)
        return .init(json: json)
    }

    static func fileFromEnvironment(name: String = "JWKS_FILE_PATH") throws -> Self {
        guard let path = ProcessInfo.processInfo.environment[name] else {
            throw PassageError.missingEnvironmentVariable(name: name)
        }
        return try .file(path: path)
    }

}
