import Testing
import WayGate

@Test func encodesPlayerAndVehiclePredictionCorrections() throws {
    let player = CorrectPlayerMovePrediction(prediction: .player, position: .zero, delta: .zero, onGround: true, tick: 300)
    let playerBytes: [UInt8] = Array(repeating: 0, count: 34) + [1, 0xac, 2]
    let playerPacket = try BedrockPacket(id: 161, payload: playerBytes)
    #expect(try player.packet() == playerPacket)
    #expect(try CorrectPlayerMovePrediction(decoding: playerPacket) == player)

    let vehicle = CorrectPlayerMovePrediction(
        prediction: .vehicle, position: .zero, delta: .zero, vehicleAngularVelocity: -2, onGround: false, tick: 9
    )
    let vehicleBytes: [UInt8] = [1] + Array(repeating: 0, count: 32) + [1, 0, 0, 0, 0xc0, 0, 9]
    let vehiclePacket = try BedrockPacket(id: 161, payload: vehicleBytes)
    #expect(try vehicle.packet() == vehiclePacket)
    #expect(try CorrectPlayerMovePrediction(decoding: vehiclePacket) == vehicle)
    let invalid = try BedrockPacket(id: 161, payload: [0] + vehicleBytes.dropFirst())
    #expect(throws: BedrockError.malformed) { try CorrectPlayerMovePrediction(decoding: invalid) }
}
