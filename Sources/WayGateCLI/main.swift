import RakNet
import WayGate

enum CLIError: Error {
    case usage
    case upstreamNotFound
}

let args = Array(CommandLine.arguments.dropFirst())
try await run(args)

func run(_ args: [String]) async throws {
    let loopback: UInt32 = 0x7f000001
    if args.count == 2, let port = UInt16(args[1]), port != 0, args[0] == "listen" || args[0] == "listen-legacy" {
        let login: BedrockLoginServer
        let gameVersion: String
        if args[0] == "listen-legacy" {
            login = BedrockLoginServer(trust: try .mojang())
            gameVersion = "1.21.94"
        } else {
            login = try await .multiplayer(keys: MinecraftLoginKeys())
            gameVersion = "1.26.60"
        }
        let guid = UInt64.random(in: 1...UInt64(Int64.max))
        let fields = [
            "MCPE", "WayGate", String(login.protocolVersion), gameVersion, "0", "128",
            String(guid), "Login Preview", "Survival", "1", String(port), "0"
        ]
        let advertisement = Array((fields.joined(separator: ";") + ";").utf8)
        let address = RakNetEndpoint.ipv4(IPv4Endpoint(address: loopback, port: port))
        let listener = try BedrockListener(on: address, login: login, guid: guid, advertisement: advertisement)
        defer { listener.close() }
        print("WayGate listening for Bedrock login on 127.0.0.1:" + String(port))
        for try await session in listener.connections {
            print("Bedrock login accepted")
            await session.close()
        }
        return
    }

    guard args.count == 3, let localPort = UInt16(args[0]), localPort != 0,
          let upstreamPort = UInt16(args[2]), upstreamPort != 0 else {
        print("usage: waygate listen port")
        print("       waygate listen-legacy port")
        print("       waygate listen-port upstream-host upstream-port")
        throw CLIError.usage
    }
    let endpoints = try await RakNetEndpoint.resolve(args[1], port: upstreamPort)
    guard let upstream = endpoints.first else { throw CLIError.upstreamNotFound }
    let proxy = try RakNetProxy(on: .ipv4(IPv4Endpoint(address: loopback, port: localPort)), upstream: upstream)
    print("WayGate listening on 127.0.0.1:" + String(proxy.localAddress.port))
    try await proxy.run()
}
