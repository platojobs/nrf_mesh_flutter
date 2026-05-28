/// Snapshot of high-level mesh feature support exposed by the current bridge.
///
/// This keeps capability probing in one place so apps can branch on feature
/// availability without making several native round-trips.
class MeshCapabilities {
  /// Creates a capability snapshot from explicit feature-support values.
  const MeshCapabilities({
    required this.rxSourceAddress,
    required this.rxAppKeyIndex,
    required this.proxyFilter,
  });

  /// Whether inbound Access messages can carry a reliable source address.
  final bool rxSourceAddress;

  /// Whether inbound metadata may include the decrypted Application Key index.
  final bool rxAppKeyIndex;

  /// How much Proxy Filter control the Flutter bridge exposes.
  final MeshProxyFilterCapability proxyFilter;

  /// Builds a capabilities snapshot from the current bridge-level boolean probes.
  factory MeshCapabilities.fromSupportFlags({
    required bool rxSourceAddress,
    required bool rxAppKeyIndex,
    required bool supportsProxyFilter,
    bool supportsAutomaticProxyFilter = false,
  }) {
    return MeshCapabilities(
      rxSourceAddress: rxSourceAddress,
      rxAppKeyIndex: rxAppKeyIndex,
      proxyFilter:
          supportsProxyFilter
              ? MeshProxyFilterCapability.explicitControl
              : supportsAutomaticProxyFilter
              ? MeshProxyFilterCapability.automaticOnly
              : MeshProxyFilterCapability.unsupported,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCapabilities &&
          runtimeType == other.runtimeType &&
          rxSourceAddress == other.rxSourceAddress &&
          rxAppKeyIndex == other.rxAppKeyIndex &&
          proxyFilter == other.proxyFilter;

  @override
  int get hashCode =>
      Object.hash(rxSourceAddress, rxAppKeyIndex, proxyFilter);

  @override
  String toString() =>
      'MeshCapabilities(rxSourceAddress: $rxSourceAddress, rxAppKeyIndex: $rxAppKeyIndex, proxyFilter: $proxyFilter)';
}

/// Proxy Filter support level aligned with the plugin roadmap.
enum MeshProxyFilterCapability {
  /// No Proxy Filter management is surfaced to Flutter.
  unsupported,

  /// The native SDK manages Proxy Filter internally, but Flutter cannot change it.
  automaticOnly,

  /// Flutter may explicitly configure Proxy Filter behavior through the bridge.
  explicitControl,
}
