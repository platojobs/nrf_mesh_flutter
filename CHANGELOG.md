## 2.0.2

### Features
- iOS: real GATT Proxy connection via `NordicMesh` / `GattBearer`, `MeshNetworkManager` import/export of Mesh Configuration Database 1.0.1, and real Foundation Config messages (bind/unbind AppKey, subscription add/delete, publication set) when a proxy is connected.
- Android: when a proxy is connected, real config send no longer falls back to in-memory state on failure; errors surface to the app. When not on a live path, legacy in-memory config remains for UI dev.
- Example: new **P1 Real Flow** page (`real_p1_page.dart`) to import mesh JSON, scan, connect proxy, and run bind/sub/pub with a log console.
- iOS: fix Pigeon-generated ObjC `MeshMessage.parameters` type (`id` instead of invalid `dynamic` in headers).
- iOS: CocoaPods `nrf_mesh_flutter` pod name alignment, `use_frameworks! :linkage => :static` in example for `nRFMeshProvision` static framework.

## 2.0.1

### Features
- Add Proxy connection APIs (`connectProxy` / `disconnectProxy` / `isProxyConnected`) to unblock real transport work for P1.
- Android: start wiring Kotlin BLE + GATT bearer for Proxy connections (foundation for real Config message delivery).

## 2.0.0

### Breaking Changes
- Android: remove legacy dependency `no.nordicsemi.android:mesh` and switch to Nordic Kotlin Mesh library dependencies.

### Features
- P1 configuration APIs (bind/unbind AppKey, subscriptions, publication) are available in Dart and bridged to native.
- `getNodes()` now exposes model bindings/subscriptions/publication fields for UI and debugging.
- iOS/Android support JSON persistence for network state (save/load/export/import), including nodes/groups and configuration fields.
- Example app includes a config demo view for validating P1 flows.

## 1.1.4

### Fixes
- Publish from a clean git state (eliminate pub.dev validation warning).

## 1.1.3

### Features
- Add address + appKeyIndex fields to `MeshMessage` and pass through the Pigeon bridge for outgoing messages.
- Decode incoming messages into typed `GenericOnOffStatus` / `GenericLevelStatus` when possible (fallback to `UnknownMessage`).
- Improve Pigeon-to-Dart model conversion to populate network keys/app keys/nodes/groups when provided by the platform.

## 1.1.2

### Developer Experience
- Extend fake bridge with outbound observability (record/stream sent messages).
- Add failure/delay injection for provisioning and network import/export.
- Add in-memory export/import storage to simulate persistence in tests.

## 1.1.1

### Developer Experience
- Enhance mock bridge with a scriptable scenario API (queued device discoveries + incoming messages).
- Add sendMessage failure injection helpers for tests and UI flows.
- Update README mock section and bump install snippet.

## 1.1.0

### Developer Experience
- Add a mockable bridge (`FakePlatoJobsMeshBridge`) for UI development without Mesh hardware.
- Add unit tests covering the fake bridge and stream behavior.
- Update example app manifests for Android 12+/14+ and iOS Bluetooth usage descriptions.
- Expand README with provisioning flow + mocking + permission/background notes.

## 1.0.4

### Docs
- Fix `CHANGELOG.md` ordering (latest first).

## 1.0.3

### Docs
- 修正 `CHANGELOG.md` 版本顺序与格式（按版本号从新到旧）。

## 1.0.2

### Docs
- 更新 README：补充更明确的错误处理方式（统一异常类型）与更完整的权限说明。

## 1.0.1

### Fixes
- 移除对 `flutter_reactive_ble` 的强依赖，避免与项目中其他 BLE 插件（如 `flutter_blue_plus`）产生依赖冲突。

## 1.0.0

### Breaking Changes
- 统一跨平台通道与 Pigeon 代码生成配置（`nrf_mesh_flutter` / `com.platojobs.nrf_mesh`）。

### Features
- 统一错误映射：将平台 `PlatformException` 转换为可读的 `PlatoJobsMeshException`。
- 增加应用层 Command Queue（串行发送 + 超时 + 背压），提升高频指令稳定性。

## 0.4.0

### Features
- Migrated Android implementation to use Nordic's Kotlin Mesh Library
- Updated Android package name from `com.example.nrf_mesh_flutter` to `com.platojobs.nrf_mesh`
- Improved Android code structure and documentation
- Added comprehensive documentation for Android implementation
- Updated build.gradle.kts with correct package configuration

## 0.3.0
- Renamed core class from `NrfMeshManager` to `PlatoJobsNrfMeshManager`.
- Updated platform interface to `PlatoJobsMeshBridge`.
- Updated iOS and Android native implementation class names.

### Features
- Unified naming convention with `PlatoJobs` prefix
- Improved documentation with detailed API reference
- Added PROJECT_SPECIFICATIONS.md for maintenance guidelines
- Enhanced Pigeon code generation setup
- Updated example app to use new naming convention

## 0.2.0

- Refactored interface package using plugin_platform_interface
- Added pigeon: ^26.3.4 for automatic MethodChannel code generation
- Fixed type conversion and null safety issues
- Optimized platform interface implementation

## 0.1.0

- Initial release
- Support for mesh network management (create, load, save, export, import)
- Support for device scanning and provisioning
- Support for mesh message sending and receiving
- Support for node and group management
- Support for iOS and Android platforms
