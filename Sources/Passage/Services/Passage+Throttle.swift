public import Foundation

public extension Passage {
    enum Throttle {}
}

// MARK: - Throttle Service

public extension Passage.Throttle {
    protocol Service: Sendable {
        func check(bucket: Bucket, against rule: Rule, at now: Date) async -> Decision
        func penalize(bucket: Bucket, at now: Date) async
        func reset(bucket: Bucket) async
    }
}

// MARK: - Throttle Types

public extension Passage.Throttle {

    struct Bucket: Hashable, Sendable {
        public let scope: Scope
        public let dimension: Dimension
        public let enabled: Bool

        public init(
            scope: Scope,
            dimension: Dimension,
            enabled: Bool
        ) {
            self.scope = scope
            self.dimension = dimension
            self.enabled = enabled
        }

        public enum Scope: String, Sendable, Hashable {
            case login
        }

        public enum Dimension: Hashable, Sendable {
            case identifier(kind: Identifier.Kind, value: String)
            case source(String)
        }
    }

    struct Rule: Sendable {
        public let maxFailures: Int
        public let window: TimeInterval

        public init(maxFailures: Int, window: TimeInterval) {
            self.maxFailures = maxFailures
            self.window = window
        }
    }

    enum Decision: Sendable, Equatable {
        case allowed
        case throttled(retryAfter: TimeInterval)
    }
}

// MARK: - Default In-Memory Implementation

public extension Passage.Throttle {

    actor InMemoryService: Service {

        private var failures: [Bucket: [Date]] = [:]

        public init() {
        }

        public func check(
            bucket: Bucket,
            against rule: Rule,
            at now: Date,
        ) async -> Decision {
            guard bucket.enabled else {
                return .allowed
            }
            let cutoff = now.addingTimeInterval(-rule.window)
            let pruned = prune(bucket: bucket, olderThan: cutoff)
            guard pruned.count >= rule.maxFailures else {
                return .allowed
            }
            // Oldest in-window attempt ages out at `oldest + window`.
            let oldest = pruned.first ?? now
            let retryAfter = max(1, oldest.addingTimeInterval(rule.window).timeIntervalSince(now))
            return .throttled(retryAfter: retryAfter)
        }

        public func penalize(
            bucket: Bucket,
            at now: Date,
        ) async {
            guard bucket.enabled else {
                return
            }
            failures[bucket, default: []].append(now)
        }

        public func reset(bucket: Bucket) async {
            guard bucket.enabled else {
                return
            }
            failures.removeValue(forKey: bucket)
        }

        @discardableResult
        private func prune(bucket: Bucket, olderThan cutoff: Date) -> [Date] {
            guard let existing = failures[bucket] else { return [] }
            let kept = existing.filter { $0 > cutoff }
            if kept.isEmpty {
                failures.removeValue(forKey: bucket)
            } else {
                failures[bucket] = kept
            }
            return kept
        }
    }
}
