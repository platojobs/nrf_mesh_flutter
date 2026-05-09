/// Indicates whether metadata fields on [RxAccessMessage] were populated by native.
enum RxMetadataStatus {
  /// Source / destination fields should be trusted when non-null.
  available,

  /// Native stack could not expose routing metadata for this PDU.
  unavailable,
}

/// A raw incoming Access-layer message plus best-effort metadata.
///
/// This is intended to be stable across native library changes. Some metadata
/// may be unavailable depending on platform and configuration.
class RxAccessMessage {
  /// Mesh opcode (UInt24 semantics collapsed into Dart [int]).
  final int opcode;

  /// Access parameters excluding opcode/network headers.
  final List<int> parameters;

  /// Best-effort source unicast address when known.
  final int? source;

  /// Best-effort destination address (unicast/group/virtual) when known.
  final int? destination;

  /// Whether [source]/[destination] should be interpreted as populated.
  final RxMetadataStatus metadataStatus;

  /// Incoming RX event forwarded from native mesh stacks.
  const RxAccessMessage({
    required this.opcode,
    required this.parameters,
    required this.source,
    required this.destination,
    required this.metadataStatus,
  });
}
