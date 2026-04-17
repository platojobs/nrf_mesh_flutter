# PlatoJobs nRF Mesh Flutter Plugin 项目规范与命名约定

> 本文档定义了 `platojobs_nrf_mesh` Flutter 插件的架构规范、命名约定和维护指南。
> **注意**：本文档不提交到 git 仓库，仅供本地维护参考。

---

## 1. 项目概述

### 1.1 包信息

| 属性 | 值 |
|------|-----|
| 包名 | `platojobs_nrf_mesh` |
| 版本 | `0.3.0` |
| 作者 | PlatoJobs |
| 仓库 | https://github.com/platojobs/nrf_mesh_flutter |
| 描述 | 基于 Nordic nRF Mesh 库的 Flutter Bluetooth Mesh 插件 |

### 1.2 核心依赖

| 平台 | 库 | 版本 |
|------|------|------|
| iOS | nRFMeshProvision | ~> 4.8.0 |
| Android | Nordic Android-nRF-Mesh-Library | 3.4.0 |
| Dart | pigeon | ^26.3.4 |
| Dart | plugin_platform_interface | ^2.0.2 |

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
platojobs_nrf_mesh/
├── lib/
│   ├── platojobs_nrf_mesh.dart          # 主入口文件
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
│   ├── platojobs_nrf_mesh_method_channel.dart   # 保留
│   └── platojobs_nrf_mesh_platform_interface.dart # 保留
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
| 包名 | platojobs_ | `platojobs_nrf_mesh` |
| 类名 | PlatoJobs | `PlatoJobsNrfMeshManager`, `PlatoJobsMeshBridge` |
| 文件名 | platojobs_ | `platojobs_nrf_mesh.dart`, `platojobs_mesh_platform.dart` |
| iOS类名 | PlatoJobs | `PlatoJobsMeshPlugin` |
| Android包名 | com.platojobs | `com.platojobs.nrf_mesh` |
| 方法通道名 | platojobs_nrf_mesh | `platojobs_nrf_mesh` |

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

| 通道类型 | 名称 | 说明 |
|----------|------|------|
| MethodChannel | `platojobs_nrf_mesh` | 主方法通道 |
| EventChannel (扫描) | `platojobs_nrf_mesh/scan` | 设备发现事件流 |
| EventChannel (消息) | `platojobs_nrf_mesh/message` | 消息接收事件流 |

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

为避免模型类与 Pigeon 生成类冲突，使用 `as models` 别名：

```dart
import 'src/models/mesh_network.dart' as models;
import 'src/models/provisioned_node.dart' as models;

class MeshManagerApi {
  final platform.PlatoJobsMeshBridge _platform =
      platform.PlatoJobsMeshBridge.instance;

  Future<models.MeshNetwork> createNetwork(String name) async {
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
  @async
  MeshNetwork createNetwork(String name);

  @async
  UnprovisionedDevice provisionDevice(
    UnprovisionedDevice device,
    ProvisioningParameters params,
  );
}

@FlutterApi()
abstract class MeshFlutterApi {
  void onDeviceDiscovered(UnprovisionedDevice device);
  void onMessageReceived(MeshMessage message);
}
```

### 5.2 生成命令

```bash
flutter pub run pigeon --input=pigeon/mesh_api.dart \
  --dart_out=lib/src/platform_interface/pigeon_generated.dart \
  --swift_out=ios/Classes/ \
  --kotlin_out=android/src/main/kotlin/com/platojobs/nrf_mesh/
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
**包路径**: `com.platojobs.nrf_mesh.PlatoJobsMeshPlugin`

```swift
public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin {
    private var meshManager: MeshManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "platojobs_nrf_mesh",
            binaryMessenger: registrar.messenger()
        )
        // ...
    }
}
```

### 6.2 Android (Kotlin)

**类名**: `PlatoJobsMeshPlugin`
**包路径**: `com.platojobs.nrf_mesh.PlatoJobsMeshPlugin`

```kotlin
package com.platojobs.nrf_mesh

class PlatoJobsMeshPlugin :
    FlutterPlugin,
    MethodCallHandler,
    StreamHandler,
    MeshManagerDelegate {

    override fun onAttachedToEngine(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "platojobs_nrf_mesh"
        )
        // ...
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
| 0.1.0 | - | 初始版本 |
| 0.2.0 | - | 引入 Pigeon 和 platform_interface |
| 0.3.0 | - | 统一 PlatoJobs 命名前缀 |

### 7.3 更新日志

每次版本更新需在 `CHANGELOG.md` 中记录：

```markdown
## 0.3.0

### Breaking Changes
- 重命名包名：nrf_mesh_flutter -> platojobs_nrf_mesh
- 重命名核心类：NrfMeshManager -> PlatoJobsNrfMeshManager

### Features
- 统一 PlatoJobs 命名前缀避免冲突
```

---

## 8. 发布规范

### 8.1 发布前检查

- [ ] 所有测试通过 (`flutter test`)
- [ ] 代码分析无错误 (`flutter analyze`)
- [ ] 更新版本号 (pubspec.yaml)
- [ ] 更新 CHANGELOG.md
- [ ] 更新 README.md（如有 API 变更）

### 8.2 发布命令

```bash
# 登录 pub.dev
dart pub publish

# 或使用 flutter
flutter pub publish
```

### 8.3 Git 标签

```bash
git tag -a v0.3.0 -m "Version 0.3.0: PlatoJobs naming convention"
git push origin v0.3.0
```

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
- [Nordic Android nRF Mesh](https://github.com/NordicSemiconductor/Android-nRF-Mesh-Library)
- [Bluetooth Mesh 模型规范](https://www.bluetooth.com/specifications/specs/mesh-model/)

---

*本文档最后更新: 2026-04-17*
