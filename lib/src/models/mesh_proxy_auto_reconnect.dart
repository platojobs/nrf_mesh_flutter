/// Configures Dart-side best-effort proxy auto-reconnect.
///
/// This policy stays entirely in Flutter/Dart space and does not require extra
/// native SDK support. When enabled, the manager remembers the last successful
/// or requested Proxy target, periodically checks whether the bearer is still
/// connected, and retries `connectProxy` after unexpected disconnects.
class MeshProxyAutoReconnectPolicy {
  /// Disabled policy used by default to preserve existing behaviour.
  static const MeshProxyAutoReconnectPolicy disabled =
      MeshProxyAutoReconnectPolicy(enabled: false);

  /// Creates a best-effort proxy auto-reconnect policy.
  const MeshProxyAutoReconnectPolicy({
    this.enabled = false,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.healthCheckInterval = const Duration(seconds: 5),
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than zero');

  /// Whether the manager should monitor the current proxy bearer and retry.
  final bool enabled;

  /// Maximum reconnect attempts for one unexpected disconnect episode.
  final int maxAttempts;

  /// Delay between reconnect attempts.
  final Duration retryDelay;

  /// Polling interval used to detect unexpected proxy bearer loss.
  final Duration healthCheckInterval;

  /// Returns a copy with selected fields replaced.
  MeshProxyAutoReconnectPolicy copyWith({
    bool? enabled,
    int? maxAttempts,
    Duration? retryDelay,
    Duration? healthCheckInterval,
  }) {
    return MeshProxyAutoReconnectPolicy(
      enabled: enabled ?? this.enabled,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      healthCheckInterval: healthCheckInterval ?? this.healthCheckInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MeshProxyAutoReconnectPolicy &&
        other.enabled == enabled &&
        other.maxAttempts == maxAttempts &&
        other.retryDelay == retryDelay &&
        other.healthCheckInterval == healthCheckInterval;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, maxAttempts, retryDelay, healthCheckInterval);

  @override
  String toString() {
    return 'MeshProxyAutoReconnectPolicy('
        'enabled: $enabled, '
        'maxAttempts: $maxAttempts, '
        'retryDelay: $retryDelay, '
        'healthCheckInterval: $healthCheckInterval)';
  }
}
