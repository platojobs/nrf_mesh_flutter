import 'package:flutter/services.dart';
import 'dart:async';

/// Base exception type for structured failures originating from mesh workflows.
sealed class PlatoJobsMeshException implements Exception {
  /// Human-readable explanation suitable for logs / UI (sanitize secrets).
  const PlatoJobsMeshException(this.message, {this.code, this.details});

  /// Operator-facing description.
  final String message;

  /// Optional stable code from native (`PlatformException.code`, timeouts, etc.).
  final String? code;

  /// Raw diagnostic payload when available.
  final Object? details;

  @override
  String toString() =>
      'PlatoJobsMeshException(${code ?? runtimeType}): $message';
}

/// Wraps non-specific platform channel failures.
class PlatoJobsMeshPlatformException extends PlatoJobsMeshException {
  /// Creates platform-side mesh failure with optional structured details.
  const PlatoJobsMeshPlatformException(
    super.message, {
    super.code,
    super.details,
  });
}

/// Raised when mesh operations exceed configured async timeouts.
class PlatoJobsMeshTimeoutException extends PlatoJobsMeshException {
  /// Timeout-oriented mesh failure.
  const PlatoJobsMeshTimeoutException(
    super.message, {
    super.code,
    super.details,
  });
}

/// BLE/Mesh permission or authorization failures surfaced from OS.
class PlatoJobsMeshPermissionException extends PlatoJobsMeshException {
  /// Permission-specific mesh failure.
  const PlatoJobsMeshPermissionException(
    super.message, {
    super.code,
    super.details,
  });
}

/// Transport-layer failures (GATT drops, proxy loss, channel errors).
class PlatoJobsMeshConnectionException extends PlatoJobsMeshException {
  /// Connection-oriented mesh failure.
  const PlatoJobsMeshConnectionException(
    super.message, {
    super.code,
    super.details,
  });
}

/// Programming errors / illegal sequencing (e.g. mesh not initialized).
class PlatoJobsMeshInvalidStateException extends PlatoJobsMeshException {
  /// Invalid lifecycle usage mesh failure.
  const PlatoJobsMeshInvalidStateException(
    super.message, {
    super.code,
    super.details,
  });
}

/// Converts arbitrary errors ([PlatformException], timeouts, etc.) into [PlatoJobsMeshException].
PlatoJobsMeshException platoJobsMeshMapException(Object error) {
  if (error is PlatoJobsMeshException) return error;
  if (error is TimeoutException) {
    return PlatoJobsMeshTimeoutException(error.message ?? '操作超时');
  }
  if (error is PlatformException) {
    final code = error.code;
    final message = error.message ?? '平台调用失败';
    final details = error.details;

    if (code == 'channel-error') {
      return PlatoJobsMeshConnectionException(
        '通道连接失败（可能是插件未正确注册或通道名不一致）',
        code: code,
        details: details,
      );
    }
    if (code == 'null-error') {
      return PlatoJobsMeshPlatformException(
        '平台返回了空值（Dart 侧期望非空返回）',
        code: code,
        details: details,
      );
    }

    final lower = message.toLowerCase();
    if (lower.contains('permission') || lower.contains('not authorized')) {
      return PlatoJobsMeshPermissionException(
        message,
        code: code,
        details: details,
      );
    }
    if (lower.contains('133') || lower.contains('gatt')) {
      return PlatoJobsMeshConnectionException(
        '蓝牙连接失败（常见为 GATT 133/连接不稳定/系统栈问题）: $message',
        code: code,
        details: details,
      );
    }
    if (lower.contains('mtu')) {
      return PlatoJobsMeshConnectionException(
        'MTU 协商失败或 MTU 不足: $message',
        code: code,
        details: details,
      );
    }
    if (lower.contains('invalid') || lower.contains('state')) {
      return PlatoJobsMeshInvalidStateException(
        message,
        code: code,
        details: details,
      );
    }
    return PlatoJobsMeshPlatformException(
      message,
      code: code,
      details: details,
    );
  }

  return PlatoJobsMeshPlatformException(error.toString());
}
