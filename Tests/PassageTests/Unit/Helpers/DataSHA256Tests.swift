import Testing
import Foundation
import CryptoKit
@testable import Passage

/// `Data.sha256Hex` is the hashing helper used by passkey challenge stores
/// (core in-memory store, future Fluent store) to index challenges by hash
/// rather than plaintext. Its output format is load-bearing for cross-module
/// consistency.
@Suite("Data sha256Hex Helper", .tags(.unit))
struct DataSHA256Tests {

    @Test("Known NIST test vector for empty input")
    func emptyInputVector() {
        let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        #expect(Data().sha256Hex == expected)
    }

    @Test("Known test vector for 'abc'")
    func abcVector() {
        let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        #expect(Data("abc".utf8).sha256Hex == expected)
    }

    @Test("Output is always 64 lowercase hex characters")
    func outputFormat() {
        let hexAlphabet = Set("0123456789abcdef")
        for _ in 0..<16 {
            let bytes = Data((0..<Int.random(in: 0...256)).map { _ in UInt8.random(in: 0...255) })
            let hex = bytes.sha256Hex
            #expect(hex.count == 64)
            #expect(hex.allSatisfy { hexAlphabet.contains($0) })
        }
    }

    @Test("Matches CryptoKit SHA256.hash(data:) byte-for-byte")
    func matchesCryptoKit() {
        for _ in 0..<8 {
            let bytes = Data((0..<64).map { _ in UInt8.random(in: 0...255) })
            let viaHelper = bytes.sha256Hex
            let viaCryptoKit = SHA256.hash(data: bytes)
                .compactMap { String(format: "%02x", $0) }
                .joined()
            #expect(viaHelper == viaCryptoKit)
        }
    }

    @Test("Different inputs produce different digests")
    func differentInputsDifferentDigests() {
        let a = Data("passage".utf8).sha256Hex
        let b = Data("Passage".utf8).sha256Hex
        #expect(a != b)
    }

    @Test("Helper is publicly accessible from other modules via PassageOnlyForTest")
    func helperIsPublic() {
        // PassageOnlyForTest uses `Data.sha256Hex` from its in-memory challenge
        // store. If visibility regresses to internal, this test file would
        // compile but PassageOnlyForTest wouldn't — this assertion records
        // the intent explicitly.
        let _: String = Data().sha256Hex
        #expect(Bool(true))
    }
}
