/// Cross-platform summary of **GATT bearer** activity for Nordic mesh stacks.
///
/// Phase **3.1**: native code exposes separate **`isProxyConnected`** and
/// **`isProvisioningConnected`** probes; this snapshot applies one precedence
/// rule so apps do not fork logic per platform.
///
/// **Not covered:** a **`connecting`** phase is **not** observable from these
/// booleans — treat **`connectProxy`** / **`connectProvisioning`** futures as
/// local in-flight state until the next snapshot poll or success callback.
class MeshBearerSnapshot {
  /// Derived logical phase for routing mesh vs provisioning UX.
  final MeshBearerPhase phase;

  /// Native **`isProxyConnected`** value read while building this snapshot.
  final bool proxyConnected;

  /// Native **`isProvisioningConnected`** value read while building this snapshot.
  final bool provisioningConnected;

  /// Creates a snapshot from explicit phase and raw flags (tests / tooling).
  const MeshBearerSnapshot({
    required this.phase,
    required this.proxyConnected,
    required this.provisioningConnected,
  });

  /// Builds from native booleans using [MeshBearerPhase.fromNativeFlags].
  factory MeshBearerSnapshot.fromNativeFlags({
    required bool proxyConnected,
    required bool provisioningConnected,
  }) {
    return MeshBearerSnapshot(
      phase: MeshBearerPhase.fromNativeFlags(
        proxyConnected: proxyConnected,
        provisioningConnected: provisioningConnected,
      ),
      proxyConnected: proxyConnected,
      provisioningConnected: provisioningConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshBearerSnapshot &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          proxyConnected == other.proxyConnected &&
          provisioningConnected == other.provisioningConnected;

  @override
  int get hashCode => Object.hash(phase, proxyConnected, provisioningConnected);

  @override
  String toString() =>
      'MeshBearerSnapshot(phase: $phase, proxyConnected: $proxyConnected, provisioningConnected: $provisioningConnected)';
}

/// High-level bearer phase aligned with README Phase **3** roadmap vocabulary.
enum MeshBearerPhase {
  /// Neither provisioning nor mesh-proxy GATT bearer reports connected.
  disconnected,

  /// PB-GATT provisioning bearer is active.
  ///
  /// When both provisioning and proxy natives report **`true`**, this phase wins
  /// (defensive precedence for abnormal concurrent states).
  provisioning,

  /// Mesh proxy GATT bearer is active for configured mesh traffic.
  proxyReady;

  /// Maps **`isProvisioningConnected`** / **`isProxyConnected`** to one phase.
  ///
  /// **Precedence:** [provisioning] over [proxyReady] when both are **`true`**.
  static MeshBearerPhase fromNativeFlags({
    required bool proxyConnected,
    required bool provisioningConnected,
  }) {
    if (provisioningConnected) return MeshBearerPhase.provisioning;
    if (proxyConnected) return MeshBearerPhase.proxyReady;
    return MeshBearerPhase.disconnected;
  }
}
