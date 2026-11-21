public struct SetLocalPlayerAsInitialized: Equatable, Sendable {
    public static let packetID: UInt16 = 113
    public let entityRuntimeID: UInt64
    public init(entityRuntimeID: UInt64) {
        self.entityRuntimeID = entityRuntimeID
    }
  public init(decoding payload: [UInt8]) throws {
    
 var reader = BedrockReader(payload[...])
  let value = try reader.varULong()
    
  guard reader.isEmpty else { throw BedrockError.malformed }
  self.entityRuntimeID = value
  }
  public init(decoding packet: BedrockPacket) throws {
    
  guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
  try self.init(decoding: packet.payload)
  }
    
  public func encode() -> [UInt8] {
    
  var payload: [UInt8] = []
  payload.appendVarULong(entityRuntimeID)
  return payload
  }
public func packet() throws -> BedrockPacket {
  
  try BedrockPacket(id: Self.packetID, payload: encode())
}
}
