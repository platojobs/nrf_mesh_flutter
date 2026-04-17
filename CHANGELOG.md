## 0.3.0

### Breaking Changes
- Renamed package from `nrf_mesh_flutter` to `platojobs_nrf_mesh`
- Renamed core class from `NrfMeshManager` to `PlatoJobsNrfMeshManager`
- Updated platform interface to `PlatoJobsMeshBridge`
- Updated iOS and Android native implementation class names

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
