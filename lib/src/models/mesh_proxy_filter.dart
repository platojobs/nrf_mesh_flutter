/// Explicit Proxy Filter type used by Proxy Configuration messages.
enum MeshProxyFilterType {
  /// Accept traffic only for addresses present in the filter list.
  whitelist,

  /// Reject traffic for addresses present in the filter list.
  blacklist;

  /// Stable integer code used by the platform bridge.
  int get code => switch (this) {
    MeshProxyFilterType.whitelist => 0,
    MeshProxyFilterType.blacklist => 1,
  };

  /// Parses a bridge integer code back to a Dart enum value.
  static MeshProxyFilterType fromCode(int code) {
    return switch (code) {
      0 => MeshProxyFilterType.whitelist,
      1 => MeshProxyFilterType.blacklist,
      _ => throw ArgumentError.value(code, 'code', 'Unsupported proxy filter type'),
    };
  }
}
