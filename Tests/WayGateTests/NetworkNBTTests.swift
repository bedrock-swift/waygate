import Testing
@testable import WayGate

@Test func readsOneNamedNetworkNBTCompound() throws {
    let bytes: [UInt8] = [
        10, 1, 114, 3, 1, 105, 3, 9, 1, 108, 1, 4, 7, 8,
        10, 1, 99, 8, 1, 115, 3, 97, 98, 99, 0, 0
    ]
    let compound = try NetworkNBT(bytes: bytes)
    var reader = BedrockReader((bytes + [99])[...])
    #expect(try NetworkNBT(reading: &reader) == compound)
    #expect(try reader.byte() == 99)
    #expect(try NetworkNBT(bytes: [10, 0, 0]) == .empty)
    #expect(throws: BedrockError.malformed) { try NetworkNBT(bytes: bytes + [99]) }
}

@Test func rejectsUnterminatedAndOverlyNestedNBT() throws {
    let malformed: [[UInt8]] = [
        [10, 0, 1, 0, 42],
        [10, 0, 9, 0, 0, 2, 0],
        [10, 0, 4, 0] + Array(repeating: 255, count: 9) + [2, 0]
    ]
    for bytes in malformed {
        #expect(throws: BedrockError.malformed) { try NetworkNBT(bytes: bytes) }
    }
    let nested: [UInt8] = (0..<66).flatMap { _ in [10, 0] } + Array(repeating: 0, count: 66)
    #expect(throws: BedrockError.limitExceeded) { try NetworkNBT(bytes: nested) }
}
