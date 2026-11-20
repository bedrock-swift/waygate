<div align="center">

# WayGate

A Swift library for the Minecraft: Bedrock Edition protocol.

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange?style=flat-square&logo=swift)](https://www.swift.org)

<img src="assets/waygate.png" width="640" alt="An orange swift carrying an envelope toward a gate">

</div>

## Features

- Bedrock packet headers and batched transport framing
- Legacy Bedrock login with Mojang certificate-chain verification
- Snappy compression
- P-384 key exchange and encrypted packet sessions over RakNet
- Resource pack metadata, transfer packets, and archive hashing
- Raw RakNet relay for a fixed upstream

Use `BedrockLoginServer(trust: try .mojang())` with `BedrockListener` to authenticate legacy Bedrock login chains. WayGate checks the client data signature, negotiates encryption and publishes a session with the verified identity.

Resource pack codecs default to the Bedrock 26.60 layout. Pass `.legacy` when using them with a legacy session.

Use `BedrockLoginServer.multiplayer(keys: try await MinecraftLoginKeys())` for Bedrock 26.60. The key cache verifies multiplayer tokens against Mojang's signing keys and refreshes those keys as they rotate.

After login, pass a `ResourcePackNegotiation` to `BedrockSession.negotiateResourcePacks`. The method returns any packets that followed the client's final confirmation in the same batch.

## Development

Build with Swift 6.1 or later. The demo binds to IPv4 loopback.

```sh
swift test
swift run waygate listen 19142
swift run waygate listen-legacy 19142
swift run waygate 19142 127.0.0.1 19132
```
