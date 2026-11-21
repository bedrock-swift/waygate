import Testing
import WayGate

@Test func encodesInitialWorldAndPlayerState() throws {
    var world = StartGame.World(name: "Test")
    world.seed = 41
    world.dimension = 1
    world.generator = 2
    world.spawn = SIMD3(8, 64, -8)
    world.multiplayerGame = true
    world.gameRules = [.init(name: "a", value: .integer(258))]
    world.experiments = [.init(name: "e", enabled: true)]
    world.forceExperimentalGameplay = false
    var start = StartGame(
        player: .init(uniqueID: -2, runtimeID: 4_294_967_297, gameMode: 1, position: SIMD3(1, 64, -2)), world: world
    )
    start.time = 100
    start.blocks = [.init(name: "b", properties: .empty)]
    start.useBlockNetworkIDHashes = true
    start.worldID = "w"
    let wire: [UInt8] = [
        0x03, 0x81, 0x80, 0x80, 0x80, 0x10, 0x02, 0, 0, 0x80, 0x3f, 0, 0, 0x80, 0x42,
        0, 0, 0, 0xc0, 0, 0, 0, 0, 0, 0, 0, 0, 0x29, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0x02, 0x04, 0, 0, 0, 0x10, 0x80,
        0x01, 0x0f, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0x01, 0, 0, 0, 0, 0, 0x01, 0x01, 0x61, 0,
        0x02, 0x02, 0x01, 0, 0, 0x01, 0, 0, 0, 0x01, 0x65, 0x01, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0x07, 0x31, 0x2e, 0x32, 0x36, 0x2e, 0x36, 0x30, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0x01, 0, 0, 0, 0, 0, 0, 0x04, 0x54, 0x65, 0x73,
        0x74, 0, 0, 0, 0, 0x64, 0, 0, 0, 0, 0, 0, 0, 0, 0x01,
        0x01, 0x62, 0x0a, 0, 0, 0, 0, 0x07, 0x31, 0x2e, 0x32, 0x36, 0x2e, 0x36, 0x30,
        0x0a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0,
        0, 0, 0, 0x01, 0x77, 0
    ]
    let packet = try BedrockPacket(id: 11, payload: wire)
    #expect(try start.packet() == packet)
}
