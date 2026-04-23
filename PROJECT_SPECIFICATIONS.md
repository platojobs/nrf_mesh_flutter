# nRF Mesh Flutter Plugin 项目规范与命名约定

> 本文档定义了 `nrf_mesh_flutter` Flutter 插件的架构规范、命名约定和维护指南。
> **注意**：本文档会提交到 git 仓库，应与主分支实现保持同步（尤其是 API / CI / 发布流程）。

---

## 1. 项目概述

### 1.1 包信息

| 属性 | 值 |
|------|-----|
| 包名 | `nrf_mesh_flutter` |
| 版本 | `4.0.0` |
| 作者 | PlatoJobs |
| 仓库 | https://github.com/platojobs/nrf_mesh_flutter |
| 描述 | 基于 Nordic nRF Mesh 库的 Flutter Bluetooth Mesh 插件 |

### 1.2 核心依赖

| 平台 | 库 | 版本 |
|------|------|------|
| iOS | nRFMeshProvision | ~> 4.8.0 |
| Android | no.nordicsemi.kotlin.mesh:* (Kotlin Mesh) | 0.9.2 |
| Android | no.nordicsemi.kotlin.ble:client-android | 2.0.0-alpha19 |
| Android | Android Gradle Plugin | 8.11.1 |
| Android | Kotlin Gradle Plugin | 2.2.20 |
| Android | minSdk | 24 |
| Android | compileSdk | 36 |
| Dart | pigeon (dev dependency) | ^26.3.4 |
| Dart | plugin_platform_interface | ^2.0.2 |
| Dart | SDK constraint | ^3.11.4 |
| Flutter | Flutter constraint | >=3.3.0 |

---

## 2. 架构规范

### 2.1 三层架构

```
┌─────────────────────────────────────────────┐
│              Dart Layer (lib/)              │
│  PlatoJobsNrfMeshManager (单例入口)          │
│  ├── MeshManagerApi (业务逻辑)               │
│  └── Models (数据模型)                       │
├─────────────────────────────────────────────┤
│         Platform Interface Layer             │
│  PlatoJobsMeshBridge (抽象接口)              │
│  PlatoJobsMeshBridgeImpl (Pigeon通信实现)    │
├─────────────────────────────────────────────┤
│         Native Platform Layer                │
│  iOS: PlatoJobsMeshPlugin.swift             │
│  Android: PlatoJobsMeshPlugin.kt             │
└─────────────────────────────────────────────┘
```

### 2.2 目录结构

```
nrf_mesh_flutter/
├── lib/
│   ├── platojobs_nrf_mesh.dart          # 主入口文件（历史命名，暂保留）
│   ├── src/
│   │   ├── core/
│   │   │   └── mesh_manager_api.dart     # 核心API实现
│   │   ├── models/
│   │   │   ├── mesh_network.dart         # 网络模型
│   │   │   ├── provisioned_node.dart     # 已配置节点模型
│   │   │   ├── unprovisioned_device.dart # 未配置设备模型
│   │   │   ├── mesh_group.dart           # 组模型
│   │   │   └── mesh_message.dart         # 消息模型
│   │   ├── platform/
│   │   │   └── method_channel_handler.dart
│   │   └── platform_interface/
│   │       ├── platojobs_mesh_platform.dart  # 平台接口
│   │       └── pigeon_generated.dart         # Pigeon生成代码
│   ├── platojobs_nrf_mesh_method_channel.dart   # 保留（兼容历史）
│   └── platojobs_nrf_mesh_platform_interface.dart # 保留（兼容历史）
├── ios/
│   └── Classes/
│       └── PlatoJobsMeshPlugin.swift
├── android/
│   └── src/main/kotlin/com/platojobs/nrf_mesh/
│       └── PlatoJobsMeshPlugin.kt
└── pigeon/
    └── mesh_api.dart                      # Pigeon消息定义
```

---

## 3. 命名规范

### 3.1 命名前缀规则

为避免与其他 Flutter 包的命名冲突，本项目统一使用 **PlatoJobs** 作为前缀。

| 类型 | 前缀 | 示例 |
|------|------|------|
| 包名 | - | `nrf_mesh_flutter` |
| 类名 | PlatoJobs | `PlatoJobsNrfMeshManager`, `PlatoJobsMeshBridge` |
| 文件名 | platojobs_ | `platojobs_nrf_mesh.dart`, `platojobs_mesh_platform.dart`（历史延续） |
| iOS类名 | PlatoJobs | `PlatoJobsMeshPlugin` |
| Android包名 | com.platojobs | `com.platojobs.nrf_mesh` |
| Pigeon 通道前缀 | dev.flutter.pigeon | `dev.flutter.pigeon.nrf_mesh_flutter.MeshApi.*` |

### 3.2 类命名

| 层级 | 类名 | 说明 |
|------|------|------|
| 入口 | `PlatoJobsNrfMeshManager` | 单例管理器，提供所有Mesh功能 |
| 业务 | `MeshManagerApi` | API实现类，内部使用 |
| 接口 | `PlatoJobsMeshBridge` | 平台接口抽象类 |
| 实现 | `PlatoJobsMeshBridgeImpl` | 平台接口Pigeon实现 |
| Handler | `_PlatoJobsMeshFlutterApiHandler` | Pigeon Flutter API处理器 |

### 3.3 模型命名

| 模型 | 文件名 | 类名 |
|------|--------|------|
| Mesh网络 | mesh_network.dart | `MeshNetwork`, `NetworkKey`, `AppKey`, `Provisioner` |
| 已配置节点 | provisioned_node.dart | `ProvisionedNode`, `NodeFeatures`, `Element` |
| 未配置设备 | unprovisioned_device.dart | `UnprovisionedDevice` |
| Mesh组 | mesh_group.dart | `MeshGroup` |
| Mesh消息 | mesh_message.dart | `MeshMessage`, `UnknownMessage`, `GenericOnOffSet` |

### 3.4 方法通道命名

本项目已迁移到 **Pigeon** 作为主要跨平台通信方式，不再以自定义 `MethodChannel/EventChannel` 作为对外规范。

- **HostApi**：`MeshApi`（Dart → Native）
- **FlutterApi**：`MeshFlutterApi`（Native → Dart）
- **通道命名**：由 Pigeon 生成，形如 `dev.flutter.pigeon.nrf_mesh_flutter.MeshApi.<method>`

---

## 4. API 设计规范

### 4.1 单例模式

核心管理器使用单例模式，确保全局只有一个实例：

```dart
class PlatoJobsNrfMeshManager {
  static final PlatoJobsNrfMeshManager instance =
      PlatoJobsNrfMeshManager._internal();

  factory PlatoJobsNrfMeshManager() => instance;

  PlatoJobsNrfMeshManager._internal() {
    PlatoJobsMeshBridge.instance = PlatoJobsMeshBridgeImpl();
  }
}
```

### 4.2 Stream 处理

对于持续性的数据流（如设备扫描、消息接收），使用 Stream：

```dart
// 设备扫描
Stream<UnprovisionedDevice> scanForDevices() {
  return _meshManagerApi.scanForDevices();
}

// 消息接收
Stream<MeshMessage> get messageStream {
  return _meshManagerApi.messageStream;
}
```

### 4.3 类型别名

为避免模型类与 Pigeon 生成类冲突，采用 **按文件/领域拆分别名**（不要多个文件共用同一个 `as models`）：

```dart
import '../models/mesh_network.dart' as net_models;
import '../models/provisioned_node.dart' as node_models;

class MeshManagerApi {
  final platform.PlatoJobsMeshBridge _platform =
      platform.PlatoJobsMeshBridge.instance;

  Future<net_models.MeshNetwork> createNetwork(String name) async {
    return await _platform.createNetwork(name);
  }
}
```

---

## 5. Pigeon 使用规范

### 5.1 消息定义

Pigeon 消息定义文件位于 `pigeon/mesh_api.dart`：

```dart
@HostApi()
abstract class MeshApi {
  MeshNetwork createNetwork(String name);

  ProvisionedNode provisionDevice(
    UnprovisionedDevice device,
    ProvisioningParameters params,
  );

  // Output OOB continuation (interactive provisioning)
  bool provideProvisioningOobNumeric(String deviceId, int value);
  bool provideProvisioningOobAlphaNumeric(String deviceId, String value);
}

@FlutterApi()
abstract class MeshFlutterApi {
  void onDeviceDiscovered(UnprovisionedDevice device);
  void onMessageReceived(MeshMessage message);
  void onProvisioningEvent(ProvisioningEvent event);
}
```

### 5.2 生成命令

```bash
dart run pigeon --input pigeon/mesh_api.dart
```

### 5.3 可空字段

Pigeon 生成的消息类字段必须为可空类型，避免初始化错误：

```dart
class UnprovisionedDevice {
  final String? deviceId;
  final String? name;
  final int? rssi;
  final List<int>? uuid;
}
```

---

## 6. 平台实现规范

### 6.1 iOS (Swift)

**类名**: `PlatoJobsMeshPlugin`
**文件**: `ios/Classes/NrfMeshFlutterPlugin.swift`

```swift
public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let api = PlatoJobsMeshPlugin()
    MeshApiSetup.setUp(binaryMessenger: messenger, api: api)
    // MeshFlutterApi is invoked from native to Dart via generated bindings.
  }
}
```

### 6.2 Android (Kotlin)

**类名**: `PlatoJobsMeshPlugin`
**包路径**: `com.platojobs.nrf_mesh`
**文件**: `android/src/main/kotlin/com/platojobs/nrf_mesh/PlatoJobsMeshPlugin.kt`

```kotlin
package com.platojobs.nrf_mesh

class PlatoJobsMeshPlugin :
  FlutterPlugin,
  MeshApi {

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    MeshApi.setUp(binding.binaryMessenger, this)
    // MeshFlutterApi is invoked from native to Dart via generated bindings.
  }
}
```

---

## 7. 版本管理规范

### 7.1 版本号格式

遵循语义化版本 (SemVer)：`MAJOR.MINOR.PATCH`

| 版本 | 说明 |
|------|------|
| MAJOR | 不兼容的 API 变更 |
| MINOR | 向后兼容的功能添加 |
| PATCH | 向后兼容的问题修复 |

### 7.2 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 3.10.0 | - | Provisioning bearer foundation (`connectProvisioning/*`) |
| 3.11.0 | - | Android: PB-GATT provisioning connection management + CI changelog check |
| 4.0.0 | 2026-04-23 | M1 完整收尾：Android full provisioning flow + Output OOB continuation APIs + Kotlin Mesh DB `getNodes()` 回读 |

### 7.3 更新日志

每次版本更新需在 `CHANGELOG.md` 中记录，且遵循以下约定：

- **顺序**：最新版本必须在最上方（严格降序）。
- **语言**：只使用英文（对齐 pub.dev 与国际社区习惯）。
- **一致性**：`CHANGELOG.md` 顶部版本号必须与 `pubspec.yaml` 的 `version:` 一致（由 CI 校验）。

```markdown
## 4.0.0

### Breaking changes
- API: add interactive Output OOB continuation methods.

### Features
- Android: full provisioning flow over PB-GATT.
```

---

## 8. 发布规范

### 8.1 发布前检查

- [ ] 所有测试通过 (`flutter test`)
- [ ] 代码分析无错误 (`flutter analyze`)
- [ ] Android 侧至少完成一次编译验证（推荐：从 `example/android` 编译 `:nrf_mesh_flutter:compileDebugKotlin`）
- [ ] 更新版本号 (pubspec.yaml)
- [ ] 更新 CHANGELOG.md
- [ ] 更新 README.md（如有 API 变更）
- [ ] `dart pub publish --dry-run` 通过

### 8.2 发布命令

```bash
# 先 dry-run
dart pub publish --dry-run

# 正式发布（非交互）
flutter pub publish --force
```

### 8.3 Git 标签

```bash
git tag v4.0.0
git push origin v4.0.0
```

### 8.4 CI（强制门禁）

仓库包含 GitHub Actions 工作流：`.github/workflows/ci.yml`，主要用于 PR 门禁：

- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- `dart pub publish --dry-run`
- `dart run tool/changelog_check.dart`（校验 changelog 顺序 + 顶部版本一致性）

---

## 9. 常见问题处理

### 9.1 命名冲突

**问题**: 与其他包存在命名冲突

**解决**: 统一使用 `PlatoJobs` 前缀

### 9.2 Pigeon 类型问题

**问题**: Pigeon 消息类字段初始化错误

**解决**: 将所有字段改为可空类型

### 9.3 平台接口未初始化

**问题**: `PlatoJobsMeshBridge instance not initialized`

**解决**: 在 `PlatoJobsNrfMeshManager._internal()` 中初始化：
```dart
PlatoJobsNrfMeshManager._internal() {
  PlatoJobsMeshBridge.instance = PlatoJobsMeshBridgeImpl();
}
```

---

## 10. 参考资料

- [Flutter Plugin 开发文档](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Pigeon 代码生成](https://pub.dev/packages/pigeon)
- [Nordic nRFMeshProvision (iOS)](https://github.com/NordicSemiconductor/IOS-nRF-Mesh-Library)
- [Nordic Kotlin Mesh](https://github.com/NordicSemiconductor/Kotlin-Bluetooth-Mesh-Library)
- [Bluetooth Mesh 模型规范](https://www.bluetooth.com/specifications/specs/mesh-model/)

---

*本文档最后更新: 2026-04-17*
*本文档最后更新: 2026-04-23*
