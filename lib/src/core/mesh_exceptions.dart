import 'package:flutter/services.dart';
import 'dart:async';

sealed class PlatoJobsMeshException implements Exception {
  const PlatoJobsMeshException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() => 'PlatoJobsMeshException(${code ?? runtimeType}): $message';
}

class PlatoJobsMeshPlatformException extends PlatoJobsMeshException {
  const PlatoJobsMeshPlatformException(
    super.message, {
    super.code,
    super.details,
  });
}

class PlatoJobsMeshTimeoutException extends PlatoJobsMeshException {
  const PlatoJobsMeshTimeoutException(super.message, {super.code, super.details});
}

class PlatoJobsMeshPermissionException extends PlatoJobsMeshException {
  const PlatoJobsMeshPermissionException(super.message, {super.code, super.details});
}

class PlatoJobsMeshConnectionException extends PlatoJobsMeshException {
  const PlatoJobsMeshConnectionException(super.message, {super.code, super.details});
}

class PlatoJobsMeshInvalidStateException extends PlatoJobsMeshException {
  const PlatoJobsMeshInvalidStateException(super.message, {super.code, super.details});
}

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
      return PlatoJobsMeshPermissionException(message, code: code, details: details);
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
      return PlatoJobsMeshInvalidStateException(message, code: code, details: details);
    }
    return PlatoJobsMeshPlatformException(message, code: code, details: details);
  }
  return PlatoJobsMeshPlatformException(error.toString());
}

