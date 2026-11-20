<div align="center">

# WayGate

A Swift library for the Minecraft: Bedrock Edition protocol.

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange?style=flat-square&logo=swift)](https://www.swift.org)

<img src="assets/waygate.png" width="640" alt="An orange swift carrying an envelope toward a gate">

</div>

## Features

- Bedrock packet headers and batched transport framing
- Protocol 819 server-side login with Mojang certificate-chain verification
- Snappy compression
- P-384 key exchange and encrypted packet sessions over RakNet
- Resource pack negotiation and transfer packets for protocol 819, including archive hashing and chunk lookup
- Raw RakNet relay for a fixed upstream

Use `BedrockLoginServer(trust: try .mojang())` with `BedrockListener` to authenticate legacy Bedrock login chains. WayGate checks the client data signature, negotiates encryption and publishes a session with the verified identity. Applications can supply a custom identity verifier and handle resource packs and world entry.

## Development

Build with Swift 6.1 or later. Both demo modes bind to IPv4 loopback.

```sh
swift test
swift run waygate listen 19142
swift run waygate 19142 127.0.0.1 19132
```
