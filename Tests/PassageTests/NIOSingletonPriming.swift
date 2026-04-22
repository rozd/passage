import NIOPosix
public import Testing

/// Trait that forces NIO's `MultiThreadedEventLoopGroup.singleton` to initialise
/// under Swift's thread-safe `static let` once-machinery before the first test
/// runs. Subsequent concurrent accesses observe already-initialised state, so
/// ThreadSanitizer no longer flags NIO's internal `dispatch_once` as a race.
///
/// Apply to any `@Suite` whose tests call `withApp`, `Application.make(.testing)`,
/// or otherwise touch `MultiThreadedEventLoopGroup.singleton`.
/// See GitHub Actions run 24766052401 for the symptom this closes.
public struct PrimeNIOSingletonsTrait: SuiteTrait, TestTrait {
    public let isRecursive = true

    public func prepare(for test: Test) async throws {
        _ = Self.primed
    }

    // Top-level `let` uses Swift's `swift_once`: the first touch runs the body;
    // concurrent callers block until it returns, establishing the happens-before
    // edge TSan needs. After initialisation, this is a plain cached load.
    private static let primed: Void = {
        _ = MultiThreadedEventLoopGroup.singleton
    }()
}

extension Trait where Self == PrimeNIOSingletonsTrait {
    /// Primes NIO's singleton event-loop-group before tests run, closing a TSan
    /// race window on `MultiThreadedEventLoopGroup.singleton`'s `dispatch_once`.
    public static var primeNIOSingletons: Self { .init() }
}
