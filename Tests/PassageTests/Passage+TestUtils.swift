import Vapor
import NIOCore

// MARK: - Mock ViewRenderer for Testing

/// Mock ViewRenderer for testing that captures template names and context data
/// without requiring Leaf template rendering
final class CapturingViewRenderer: ViewRenderer, @unchecked Sendable {
    var shouldCache = false
    var eventLoop: any EventLoop

    private(set) var capturedContext: (any Encodable)?
    private(set) var templatePath: String?

    init(eventLoop: any EventLoop) {
        self.eventLoop = eventLoop
    }

    func `for`(_ request: Request) -> any ViewRenderer {
        return self
    }

    func render<E>(_ name: String, _ context: E) -> EventLoopFuture<View> where E: Encodable {
        self.capturedContext = context
        self.templatePath = name

        // Return a dummy view with the template name
        var byteBuffer = ByteBufferAllocator().buffer(capacity: name.count)
        byteBuffer.writeString("Rendered: \(name)")
        let view = View(data: byteBuffer)
        return eventLoop.future(view)
    }
}
