public import Vapor

public protocol Form: Content, Validatable {

    func validate() throws
}

// MARK: - Form Extension

extension Form {

    func validate() throws {
        // noop by default
    }
}
