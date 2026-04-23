enum RxMetadataStatus {
  available,
  unavailable,
}

/// A raw incoming Access-layer message plus best-effort metadata.
///
/// This is intended to be stable across native library changes. Some metadata
/// may be unavailable depending on platform and configuration.
class RxAccessMessage {
  final int opcode;
  final List<int> parameters;
  final int? source;
  final int? destination;
  final RxMetadataStatus metadataStatus;

  const RxAccessMessage({
    required this.opcode,
    required this.parameters,
    required this.source,
    required this.destination,
    required this.metadataStatus,
  });
}

