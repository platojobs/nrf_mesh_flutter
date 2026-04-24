import Flutter
import UIKit
import NordicMesh
import CoreBluetooth

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
    fileprivate let meshManager = MeshNetworkManager(using: LocalStorage(fileName: "nrf_mesh_flutter_meshdata.json"))
    private var nordicNetwork: NordicMesh.MeshNetwork?
    fileprivate var flutterApi: MeshFlutterApi?
    private var nodes: [ProvisionedNode] = []
    private var nextUnicast: Int64 = 1
    private var networkName: String = "default"
    private var groups: [MeshGroup] = []

    // BLE
    private lazy var centralManager: CBCentralManager = CBCentralManager(delegate: self, queue: nil)
    private var scanning: Bool = false
    private var peripheralsById: [String: CBPeripheral] = [:]
    private var proxyBearer: GattBearer?
    private var proxyConnected: Bool = false
    private var provisioningPeripheral: CBPeripheral?
    private var provisioningConnected: Bool = false

    // Provisioning (full flow)
    fileprivate var provisioningManagersByDeviceId: [String: ProvisioningManager] = [:]
    fileprivate var provisioningResultByDeviceId: [String: Result<ProvisionedNode, Error>] = [:]
    fileprivate var provisioningSemaphoresByDeviceId: [String: DispatchSemaphore] = [:]
    fileprivate var provisioningRequestedParamsByDeviceId: [String: ProvisioningParameters] = [:]
    fileprivate var provisioningUuidBytesByDeviceId: [String: [Int64]] = [:]
    fileprivate var provisioningDelegatesByDeviceId: [String: AnyObject] = [:]

    fileprivate enum PendingOob {
        case numeric(maxDigits: UInt8, callback: (BigUInt) -> Void)
        case alphanumeric(maxChars: UInt8, callback: (String) -> Void)
        case staticKey(expectedLength: Int, callback: (Data) -> Void)
    }
    fileprivate var pendingOobByDeviceId: [String: PendingOob] = [:]

    // Bluetooth Mesh Proxy Service UUID (0x1828)
    private let meshProxyService = CBUUID(string: "1828")
    private let meshProvisioningService = CBUUID(string: "1827")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PlatoJobsMeshPlugin()
        instance.meshManager.delegate = instance
        instance.flutterApi = MeshFlutterApi(binaryMessenger: registrar.messenger())
        MeshApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }

    private func defaultFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("nrf_mesh_flutter_network.json")
    }

    private func exportToURL(_ url: URL) throws -> Bool {
        var root: [String: Any] = [:]
        root["name"] = networkName
        root["nextUnicast"] = nextUnicast
        root["nodes"] = nodes.map { nodeToDict($0) }
        root["groups"] = groups.map { groupToDict($0) }
        let data = try JSONSerialization.data(withJSONObject: root, options: [])
        try data.write(to: url, options: .atomic)
        return true
    }

    private func importFromURL(_ url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = json as? [String: Any] else { return false }
        networkName = root["name"] as? String ?? "default"
        nextUnicast = (root["nextUnicast"] as? NSNumber)?.int64Value ?? 1
        nodes = (root["nodes"] as? [[String: Any]] ?? []).map { nodeFromDict($0) }
        groups = (root["groups"] as? [[String: Any]] ?? []).map { groupFromDict($0) }
        return true
    }

    private func nodeToDict(_ n: ProvisionedNode) -> [String: Any] {
        var o: [String: Any] = [:]
        o["nodeId"] = n.nodeId ?? ""
        o["name"] = n.name ?? ""
        o["unicastAddress"] = n.unicastAddress ?? 0
        o["uuid"] = n.uuid ?? []
        o["provisioned"] = n.provisioned ?? true
        o["elements"] = (n.elements ?? []).map { e -> [String: Any] in
            var eo: [String: Any] = [:]
            eo["address"] = e.address ?? 0
            eo["models"] = (e.models ?? []).map { m -> [String: Any] in
                var mo: [String: Any] = [:]
                mo["modelId"] = m.modelId ?? 0
                mo["modelName"] = m.modelName ?? ""
                mo["publishable"] = m.publishable ?? true
                mo["subscribable"] = m.subscribable ?? true
                mo["boundAppKeyIndexes"] = m.boundAppKeyIndexes ?? []
                mo["subscriptions"] = m.subscriptions ?? []
                if let pub = m.publication {
                    mo["publication"] = [
                        "address": pub.address ?? 0,
                        "appKeyIndex": pub.appKeyIndex ?? 0,
                        "ttl": pub.ttl as Any
                    ]
                }
                return mo
            }
            return eo
        }
        return o
    }

    private func nodeFromDict(_ o: [String: Any]) -> ProvisionedNode {
        let elementsDict = o["elements"] as? [[String: Any]] ?? []
        let elements: [Element] = elementsDict.map { eo in
            var e = Element()
            e.address = (eo["address"] as? NSNumber)?.int64Value ?? 0
            let modelsDict = eo["models"] as? [[String: Any]] ?? []
            e.models = modelsDict.map { mo in
                var m = Model()
                m.modelId = (mo["modelId"] as? NSNumber)?.int64Value ?? 0
                m.modelName = mo["modelName"] as? String ?? ""
                m.publishable = mo["publishable"] as? Bool ?? true
                m.subscribable = mo["subscribable"] as? Bool ?? true
                m.boundAppKeyIndexes = mo["boundAppKeyIndexes"] as? [Int64] ?? []
                m.subscriptions = mo["subscriptions"] as? [Int64] ?? []
                if let po = mo["publication"] as? [String: Any] {
                    var pub = Publication()
                    pub.address = (po["address"] as? NSNumber)?.int64Value ?? 0
                    pub.appKeyIndex = (po["appKeyIndex"] as? NSNumber)?.int64Value ?? 0
                    pub.ttl = (po["ttl"] as? NSNumber)?.int64Value
                    m.publication = pub
                }
                return m
            }
            return e
        }

        return ProvisionedNode(
            nodeId: o["nodeId"] as? String ?? "",
            name: o["name"] as? String ?? "",
            unicastAddress: (o["unicastAddress"] as? NSNumber)?.int64Value ?? 0,
            uuid: o["uuid"] as? [Int64] ?? [],
            elements: elements,
            provisioned: (o["provisioned"] as? Bool) ?? true
        )
    }

    private func groupToDict(_ g: MeshGroup) -> [String: Any] {
        [
            "groupId": g.groupId ?? "",
            "name": g.name ?? "",
            "address": g.address ?? 0,
            "nodeIds": g.nodeIds ?? []
        ]
    }

    private func groupFromDict(_ o: [String: Any]) -> MeshGroup {
        MeshGroup(
            groupId: o["groupId"] as? String ?? "",
            name: o["name"] as? String ?? "",
            address: (o["address"] as? NSNumber)?.int64Value ?? 0,
            nodeIds: o["nodeIds"] as? [String] ?? []
        )
    }

    func createNetwork(name: String) throws -> MeshNetwork {
        // Create a new Mesh Network in the Nordic manager and persist it.
        _ = meshManager.clear()
        let network = meshManager.createNewMeshNetwork(withName: name, by: "Provisioner")
        // Required for correct parsing of incoming Status messages.
        meshManager.localElements = []
        nordicNetwork = network
        _ = meshManager.save()
        networkName = name
        nodes.removeAll()
        groups.removeAll()
        nextUnicast = 1
        return MeshNetwork(
            networkId: name,
            name: name,
            networkKeys: [],
            appKeys: [],
            nodes: [],
            groups: [],
            provisioner: Provisioner(
                name: "Provisioner",
                provisionerId: UUID().uuidString,
                addressRange: [1, 0x0100]
            )
        )
    }

    func loadNetwork() throws -> MeshNetwork {
        // Prefer loading Mesh DB (Configuration Database Profile 1.0.1) from Nordic storage.
        if (try? meshManager.load()) == true, let loaded = meshManager.meshNetwork {
            nordicNetwork = loaded
            // Required for correct parsing of incoming Status messages.
            meshManager.localElements = []
            networkName = loaded.meshName
        } else if let url = defaultFileURL(),
                  (try? importFromURL(url)) == true {
            // Legacy fallback loaded into memory.
        }
        let name = nordicNetwork?.meshName ?? networkName
        return MeshNetwork(
            networkId: name,
            name: name,
            networkKeys: [],
            appKeys: [],
            nodes: nodes,
            groups: groups,
            provisioner: Provisioner(
                name: "Provisioner",
                provisionerId: UUID().uuidString,
                addressRange: [1, 0x0100]
            )
        )
    }

    func saveNetwork() throws -> Bool {
        // Save Nordic Mesh DB if available; otherwise keep legacy json.
        if meshManager.isNetworkCreated {
            return meshManager.save()
        }
        guard let url = defaultFileURL() else { return false }
        return try exportToURL(url)
    }

    func exportNetwork(path: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        if meshManager.isNetworkCreated {
            let data = meshManager.export()
            try data.write(to: url, options: .atomic)
            return true
        }
        return try exportToURL(url)
    }

    func importNetwork(path: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        // First try Mesh DB 1.0.1 import; fallback to legacy json.
        if let _ = try? meshManager.import(from: data) {
            nordicNetwork = meshManager.meshNetwork
            // Required for correct parsing of incoming Status messages.
            meshManager.localElements = []
            networkName = nordicNetwork?.meshName ?? networkName
            _ = meshManager.save()
            return true
        }
        return try importFromURL(url)
    }

    func startScan() throws {
        scanning = true
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [meshProxyService, meshProvisioningService], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        }
    }

    func stopScan() throws {
        scanning = false
        centralManager.stopScan()
    }

    func provisionDevice(device: FlutterUnprovisionedDevice, params: ProvisioningParameters) throws -> ProvisionedNode {
        guard meshManager.isNetworkCreated, let meshNetwork = meshManager.meshNetwork else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Mesh DB is not loaded (createNetwork/importNetwork first)"
            ])
        }
        guard let deviceId = device.deviceId, !deviceId.isEmpty else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing deviceId"
            ])
        }
        guard let uuidBytes = device.uuid, uuidBytes.count == 16 else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Device UUID must be 16 bytes"
            ])
        }
        guard let peripheral = peripheralsById[deviceId] else {
            throw NSError(domain: "nrf_mesh_flutter", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Peripheral not found for deviceId (scan first)"
            ])
        }

        // Convert 16 bytes to UUID.
        let nsData = Data(uuidBytes.map { UInt8(truncatingIfNeeded: $0) })
        let uuid = nsData.withUnsafeBytes { raw -> UUID in
            let b = raw.bindMemory(to: UInt8.self)
            let a0 = b[0], a1 = b[1], a2 = b[2], a3 = b[3]
            let a4 = b[4], a5 = b[5]
            let a6 = b[6], a7 = b[7]
            let a8 = b[8], a9 = b[9], a10 = b[10], a11 = b[11], a12 = b[12], a13 = b[13], a14 = b[14], a15 = b[15]
            return UUID(uuid: (a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15))
        }

        // Create UnprovisionedDevice + bearer.
        let unprov = NordicMesh.UnprovisionedDevice(name: device.name, uuid: uuid)
        let bearer = PBGattBearer(target: peripheral)
        bearer.dataDelegate = meshManager
        bearer.delegate = self
        bearer.open()

        // Create provisioning manager.
        let pm = try meshManager.provision(unprovisionedDevice: unprov, over: bearer)
        let delegate = ProvisioningDelegateAdapter(plugin: self, deviceId: deviceId)
        pm.delegate = delegate
        pm.networkKey = meshNetwork.networkKeys.first
        pm.unicastAddress = pm.suggestedUnicastAddress
        provisioningManagersByDeviceId[deviceId] = pm
        provisioningDelegatesByDeviceId[deviceId] = delegate
        provisioningResultByDeviceId.removeValue(forKey: deviceId)
        provisioningRequestedParamsByDeviceId[deviceId] = params
        provisioningUuidBytesByDeviceId[deviceId] = device.uuid
        let sem = DispatchSemaphore(value: 0)
        provisioningSemaphoresByDeviceId[deviceId] = sem

        flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
            deviceId: deviceId,
            type: .started,
            message: "Provisioning started",
            progress: 0,
            attentionTimer: nil
        )) { _ in }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try pm.identify(andAttractFor: 0)
            } catch {
                self.provisioningResultByDeviceId[deviceId] = .failure(error)
                sem.signal()
            }
        }

        // Wait until provisioning completes (delegate will signal result).
        let deadline: DispatchTime = .now() + 120.0
        if sem.wait(timeout: deadline) == .timedOut {
            provisioningManagersByDeviceId.removeValue(forKey: deviceId)
            pendingOobByDeviceId.removeValue(forKey: deviceId)
            throw NSError(domain: "nrf_mesh_flutter", code: 408, userInfo: [
                NSLocalizedDescriptionKey: "Provisioning timeout"
            ])
        }

        provisioningManagersByDeviceId.removeValue(forKey: deviceId)
        pendingOobByDeviceId.removeValue(forKey: deviceId)
        provisioningRequestedParamsByDeviceId.removeValue(forKey: deviceId)
        provisioningUuidBytesByDeviceId.removeValue(forKey: deviceId)
        provisioningSemaphoresByDeviceId.removeValue(forKey: deviceId)
        provisioningDelegatesByDeviceId.removeValue(forKey: deviceId)
        switch provisioningResultByDeviceId.removeValue(forKey: deviceId) {
        case .success(let node):
            return node
        case .failure(let err):
            throw err
        case .none:
            throw NSError(domain: "nrf_mesh_flutter", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Provisioning unknown failure"
            ])
        }
    }

    func sendMessage(message: MeshMessage) throws {
        guard proxyConnected, meshManager.isNetworkCreated else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Proxy is not connected or Mesh DB not loaded"
            ])
        }
        guard let net = meshManager.meshNetwork else {
            throw NSError(domain: "nrf_mesh_flutter", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Mesh network not available"
            ])
        }
        guard let opcode = message.opcode, let dst = message.address else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing opcode or address"
            ])
        }
        guard let appKeyIndex = message.appKeyIndex else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Missing appKeyIndex"
            ])
        }
        let keyIndex = KeyIndex(UInt16(truncatingIfNeeded: appKeyIndex))
        guard let appKey = net.applicationKeys.first(where: { $0.index == keyIndex }) else {
            throw NSError(domain: "nrf_mesh_flutter", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "AppKey not found for index \(appKeyIndex)"
            ])
        }
        
        let rawBytesAny = message.parameters?["bytes"] ?? []
        let bytes: [UInt8]
        if let b = rawBytesAny as? [Int64] {
            bytes = b.map { UInt8(truncatingIfNeeded: $0) }
        } else if let b = rawBytesAny as? [Int] {
            bytes = b.map { UInt8(truncatingIfNeeded: $0) }
        } else if let b = rawBytesAny as? [NSNumber] {
            bytes = b.map { UInt8(truncatingIfNeeded: $0.intValue) }
        } else {
            bytes = []
        }
        
        let msg = RawAccessMessage(opCode: UInt32(truncatingIfNeeded: opcode), parameters: Data(bytes))
        let destination = MeshAddress(Address(UInt16(truncatingIfNeeded: dst)))
        
        // MeshNetworkManager uses async/await; Pigeon HostApi is sync.
        let sem = DispatchSemaphore(value: 0)
        var out: Result<Void, Error>?
        do {
            _ = try meshManager.send(msg, to: destination, using: appKey) { result in
                out = result
                sem.signal()
            }
        } catch {
            throw error
        }
        if sem.wait(timeout: .now() + 10.0) == .timedOut {
            throw NSError(domain: "nrf_mesh_flutter", code: 408, userInfo: [
                NSLocalizedDescriptionKey: "Send message timeout"
            ])
        }
        switch out {
        case .success:
            return
        case .failure(let err):
            throw err
        case .none:
            throw NSError(domain: "nrf_mesh_flutter", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Send message unknown failure"
            ])
        }
    }
    func getNodes() throws -> [ProvisionedNode] {
        if meshManager.isNetworkCreated, let net = meshManager.meshNetwork {
            return net.nodes.compactMap { self.convertNordicNodeToPigeon($0) }
        }
        return nodes
    }

    func removeNode(nodeId: String) throws {
        if meshManager.isNetworkCreated, let net = meshManager.meshNetwork {
            if let uuid = UUID(uuidString: nodeId), let node = net.node(withUuid: uuid) {
                try net.remove(node: node)
                _ = meshManager.save()
                return
            }
            if let addrInt = Int(nodeId, radix: 16) {
                let addr = Address(UInt16(truncatingIfNeeded: addrInt))
                if let node = net.node(withAddress: addr) {
                    try net.remove(node: node)
                    _ = meshManager.save()
                    return
                }
            }
        }
        // Legacy in-memory removal.
        nodes.removeAll { $0.nodeId == nodeId }
    }

    func createGroup(name: String) throws -> MeshGroup {
        if meshManager.isNetworkCreated, let net = meshManager.meshNetwork {
            let addr = nextAvailableGroupAddress(in: net)
            let group = try Group(name: name, address: addr)
            try net.add(group: group)
            _ = meshManager.save()
            return MeshGroup(
                groupId: group.uuid.uuidString,
                name: group.name,
                address: Int64(group.address.address),
                nodeIds: []
            )
        }

        // Legacy in-memory fallback.
        let group = MeshGroup(
            groupId: UUID().uuidString,
            name: name,
            address: 0xC000,
            nodeIds: []
        )
        groups.append(group)
        return group
    }

    func getGroups() throws -> [MeshGroup] {
        if meshManager.isNetworkCreated, let net = meshManager.meshNetwork {
            return net.groups.map {
                MeshGroup(
                    groupId: $0.uuid.uuidString,
                    name: $0.name,
                    address: Int64($0.address.address),
                    nodeIds: []
                )
            }
        }
        return groups
    }

    func addNodeToGroup(nodeId: String, groupId: String) throws {
        // Subscription is handled via Config Model ops in M2.
        // Keep a best-effort in-memory mapping for legacy mode.
        if !meshManager.isNetworkCreated {
            for idx in groups.indices where groups[idx].groupId == groupId {
                var ids = Set(groups[idx].nodeIds ?? [])
                ids.insert(nodeId)
                groups[idx].nodeIds = Array(ids)
            }
        }
    }

    // MARK: - M2: Configuration foundation

    func fetchCompositionData(destination: Int64, page: Int64) throws -> Bool {
        guard proxyConnected, meshManager.isNetworkCreated, let net = meshManager.meshNetwork else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Proxy is not connected or Mesh DB not loaded"
            ])
        }
        // Ensure we can resolve the node.
        let dst = Address(UInt16(truncatingIfNeeded: destination))
        guard net.node(withAddress: dst) != nil else {
            throw NSError(domain: "nrf_mesh_flutter", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Node not found for destination \(destination)"
            ])
        }

        let msg = ConfigCompositionDataGet(page: UInt8(truncatingIfNeeded: page))
        _ = try sendConfig(msg, destination: dst)
        _ = meshManager.save()
        return true
    }

    func addAppKey(appKeyIndex: Int64, keyHex: String) throws -> Bool {
        guard meshManager.isNetworkCreated, let net = meshManager.meshNetwork else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Mesh DB is not loaded"
            ])
        }
        guard let keyData = Data(hexString: keyHex.replacingOccurrences(of: " ", with: "")) else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid AppKey hex"
            ])
        }
        guard keyData.count == 16 else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "AppKey must be 16 bytes"
            ])
        }

        let idx = KeyIndex(UInt16(truncatingIfNeeded: appKeyIndex))
        if let existing = net.applicationKeys.first(where: { $0.index == idx }) {
            existing.key = keyData
        } else {
            let key = try ApplicationKey(name: "AppKey \(idx)", index: idx, key: keyData)
            try net.add(applicationKey: key)
        }
        _ = meshManager.save()
        return true
    }

    func addNetworkKey(netKeyIndex: Int64, keyHex: String) throws -> Bool {
        guard meshManager.isNetworkCreated, let net = meshManager.meshNetwork else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Mesh DB is not loaded"
            ])
        }
        guard let keyData = Data(hexString: keyHex.replacingOccurrences(of: " ", with: "")) else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid NetworkKey hex"
            ])
        }
        guard keyData.count == 16 else {
            throw NSError(domain: "nrf_mesh_flutter", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "NetworkKey must be 16 bytes"
            ])
        }

        let idx = KeyIndex(UInt16(truncatingIfNeeded: netKeyIndex))
        if let existing = net.networkKeys.first(where: { $0.index == idx }) {
            existing.key = keyData
        } else {
            let key = try NetworkKey(name: "NetKey \(idx)", index: idx, key: keyData)
            try net.add(networkKey: key)
        }
        _ = meshManager.save()
        return true
    }

    func getNetworkKeys() throws -> [NetworkKey] {
        guard meshManager.isNetworkCreated, let net = meshManager.meshNetwork else { return [] }
        return net.networkKeys.map {
            NetworkKey(
                keyId: $0.uuid.uuidString,
                key: $0.key.hexUpper,
                index: Int64($0.index),
                enabled: true
            )
        }
    }

    func getAppKeys() throws -> [AppKey] {
        guard meshManager.isNetworkCreated, let net = meshManager.meshNetwork else { return [] }
        return net.applicationKeys.map {
            AppKey(
                keyId: $0.uuid.uuidString,
                key: $0.key.hexUpper,
                index: Int64($0.index),
                enabled: true
            )
        }
    }

    // Configuration (P1 - minimal, in-memory)
    private func updateModel(
        elementAddress: Int64,
        modelId: Int64,
        _ updater: (inout Model) -> Void
    ) -> Bool {
        var changed = false
        for nodeIdx in nodes.indices {
            var node = nodes[nodeIdx]
            guard var elements = node.elements else { continue }
            for elIdx in elements.indices {
                var el = elements[elIdx]
                if el.address != elementAddress { continue }
                guard var models = el.models else { continue }
                for mIdx in models.indices {
                    var m = models[mIdx]
                    if m.modelId != modelId { continue }
                    updater(&m)
                    models[mIdx] = m
                    changed = true
                }
                el.models = models
                elements[elIdx] = el
            }
            node.elements = elements
            nodes[nodeIdx] = node
        }
        return changed
    }

    func bindAppKey(elementAddress: Int64, modelId: Int64, appKeyIndex: Int64) throws -> Bool {
        if proxyConnected, meshManager.isNetworkCreated {
            guard let (appKey, model) = resolveAppKeyAndSigModel(
                elementAddress: elementAddress,
                modelId: modelId,
                appKeyIndex: appKeyIndex
            ) else { return false }
            guard let msg = ConfigModelAppBind(applicationKey: appKey, to: model) else { return false }
            _ = try sendConfig(msg, destination: model.parentElement!.unicastAddress)
            _ = meshManager.save()
            return true
        }
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.boundAppKeyIndexes ?? [])
            set.insert(appKeyIndex)
            m.boundAppKeyIndexes = Array(set).sorted()
        }
    }

    func unbindAppKey(elementAddress: Int64, modelId: Int64, appKeyIndex: Int64) throws -> Bool {
        if proxyConnected, meshManager.isNetworkCreated {
            guard let (appKey, model) = resolveAppKeyAndSigModel(
                elementAddress: elementAddress,
                modelId: modelId,
                appKeyIndex: appKeyIndex
            ) else { return false }
            guard let msg = ConfigModelAppUnbind(applicationKey: appKey, to: model) else { return false }
            _ = try sendConfig(msg, destination: model.parentElement!.unicastAddress)
            _ = meshManager.save()
            return true
        }
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.boundAppKeyIndexes ?? [])
            set.remove(appKeyIndex)
            m.boundAppKeyIndexes = Array(set).sorted()
        }
    }

    func addSubscription(elementAddress: Int64, modelId: Int64, address: Int64) throws -> Bool {
        if proxyConnected, meshManager.isNetworkCreated {
            guard let model = resolveSigModel(elementAddress: elementAddress, modelId: modelId) else { return false }
            guard let group = resolveOrCreateGroup(address: address) else { return false }
            guard let msg = ConfigModelSubscriptionAdd(group: group, to: model) else { return false }
            _ = try sendConfig(msg, destination: model.parentElement!.unicastAddress)
            _ = meshManager.save()
            return true
        }
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.subscriptions ?? [])
            set.insert(address)
            m.subscriptions = Array(set).sorted()
        }
    }

    func removeSubscription(elementAddress: Int64, modelId: Int64, address: Int64) throws -> Bool {
        if proxyConnected, meshManager.isNetworkCreated {
            guard let model = resolveSigModel(elementAddress: elementAddress, modelId: modelId) else { return false }
            guard let group = resolveOrCreateGroup(address: address) else { return false }
            guard let msg = ConfigModelSubscriptionDelete(group: group, from: model) else { return false }
            _ = try sendConfig(msg, destination: model.parentElement!.unicastAddress)
            _ = meshManager.save()
            return true
        }
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.subscriptions ?? [])
            set.remove(address)
            m.subscriptions = Array(set).sorted()
        }
    }

    func setPublication(elementAddress: Int64, modelId: Int64, publishAddress: Int64, appKeyIndex: Int64, ttl: Int64?) throws -> Bool {
        if proxyConnected, meshManager.isNetworkCreated {
            guard let (appKey, model) = resolveAppKeyAndSigModel(
                elementAddress: elementAddress,
                modelId: modelId,
                appKeyIndex: appKeyIndex
            ) else { return false }
            let destination = MeshAddress(Address(UInt16(truncatingIfNeeded: publishAddress)))
            let publish = Publish(
                to: destination,
                using: appKey,
                usingFriendshipMaterial: false,
                ttl: UInt8((ttl ?? 0).clamped(to: 0...255)),
                period: .disabled,
                retransmit: .disabled
            )
            guard let msg = ConfigModelPublicationSet(publish, to: model) else { return false }
            _ = try sendConfig(msg, destination: model.parentElement!.unicastAddress)
            _ = meshManager.save()
            return true
        }
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var pub = Publication()
            pub.address = publishAddress
            pub.appKeyIndex = appKeyIndex
            pub.ttl = ttl
            m.publication = pub
        }
    }

    func connectProxy(deviceId: String, proxyUnicastAddress: Int64) throws -> Bool {
        // deviceId is expected to be CBPeripheral.identifier.uuidString from scan callbacks.
        guard let uuid = UUID(uuidString: deviceId) else { return false }

        // Close previous bearer if any.
        proxyBearer?.close()
        proxyBearer = nil
        proxyConnected = false

        // Create bearer. It will retrieve the peripheral by UUID internally once Bluetooth is on.
        let bearer = GattBearer(targetWithIdentifier: uuid)
        bearer.dataDelegate = meshManager
        bearer.delegate = self
        meshManager.transmitter = bearer
        proxyBearer = bearer

        // Open and wait (briefly) for bearerDidOpen.
        bearer.open()
        return waitUntil(timeoutSeconds: 10.0) { self.proxyConnected }
    }

    func disconnectProxy() throws -> Bool {
        proxyBearer?.close()
        proxyBearer = nil
        return true
    }

    func isProxyConnected() throws -> Bool {
        return proxyConnected
    }

    func connectProvisioning(deviceId: String) throws -> Bool {
        guard let uuid = UUID(uuidString: deviceId) else { return false }
        provisioningPeripheral = nil
        provisioningConnected = false

        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let p = peripherals.first else { return false }
        provisioningPeripheral = p
        p.delegate = self
        centralManager.connect(p, options: nil)

        flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
            deviceId: deviceId,
            type: .started,
            message: "PB-GATT connecting",
            progress: 0,
            attentionTimer: nil
        )) { _ in }

        return waitUntil(timeoutSeconds: 10.0) { self.provisioningConnected }
    }

    func disconnectProvisioning() throws -> Bool {
        if let p = provisioningPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        provisioningPeripheral = nil
        provisioningConnected = false
        return true
    }

    func isProvisioningConnected() throws -> Bool {
        return provisioningConnected
    }

    func provideProvisioningOobNumeric(deviceId: String, value: Int64) throws -> Bool {
        guard let pending = pendingOobByDeviceId[deviceId] else { return false }
        switch pending {
        case .numeric(_, let callback):
            guard let big = BigUInt(decimalString: String(value)) else { return false }
            callback(big)
            pendingOobByDeviceId.removeValue(forKey: deviceId)
            return true
        default:
            return false
        }
    }

    func provideProvisioningOobAlphaNumeric(deviceId: String, value: String) throws -> Bool {
        guard let pending = pendingOobByDeviceId[deviceId] else { return false }
        switch pending {
        case .alphanumeric(_, let callback):
            callback(value)
            pendingOobByDeviceId.removeValue(forKey: deviceId)
            return true
        default:
            return false
        }
    }

    func supportsRxSourceAddress() throws -> Bool {
        // iOS delegate provides `sentFrom source` for incoming Access messages.
        return true
    }

    func clearSecureStorage() throws {
        // iOS secure mesh state is managed by the underlying library.
        // This is a no-op for now (kept for API parity and debugging hooks).
    }

    func setExperimentalRxMetadataEnabled(enabled: Bool) throws {
        // No-op on iOS.
    }
}

private final class ProvisioningDelegateAdapter: ProvisioningDelegate {
    private weak var plugin: PlatoJobsMeshPlugin?
    private let deviceId: String

    init(plugin: PlatoJobsMeshPlugin, deviceId: String) {
        self.plugin = plugin
        self.deviceId = deviceId
    }

    func authenticationActionRequired(_ action: AuthAction) {
        guard let plugin else { return }

        switch action {
        case .provideStaticKey(let callback):
            let hex = (plugin.provisioningRequestedParamsByDeviceId[deviceId]?.oobData ?? "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = Data(hexString: hex), !data.isEmpty {
                callback(data)
            } else {
                plugin.pendingOobByDeviceId[deviceId] = .staticKey(expectedLength: 16, callback: callback)
                plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                    deviceId: deviceId,
                    type: .oobInputRequested,
                    message: "Static OOB: missing/invalid hex key (provide 16/32 bytes).",
                    progress: 20,
                    attentionTimer: nil
                )) { _ in }
            }

        case .provideNumeric(let maxDigits, let outputAction, let callback):
            plugin.pendingOobByDeviceId[deviceId] = .numeric(maxDigits: maxDigits, callback: callback)
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .oobInputRequested,
                message: "Output OOB (numeric): enter the value displayed by the device (maxDigits=\(maxDigits), action=\(outputAction)).",
                progress: 20,
                attentionTimer: nil
            )) { _ in }

        case .provideAlphanumeric(let maxChars, let callback):
            plugin.pendingOobByDeviceId[deviceId] = .alphanumeric(maxChars: maxChars, callback: callback)
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .oobInputRequested,
                message: "Output OOB (alphanumeric): enter the value displayed by the device (maxChars=\(maxChars)).",
                progress: 20,
                attentionTimer: nil
            )) { _ in }

        case .displayNumber(let value, let inputAction):
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .oobOutputRequested,
                message: "Input OOB: display this number to the user: \(value) (action=\(inputAction)).",
                progress: 20,
                attentionTimer: nil
            )) { _ in }

        case .displayAlphanumeric(let text):
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .oobOutputRequested,
                message: "Input OOB: display this text to the user: \(text).",
                progress: 20,
                attentionTimer: nil
            )) { _ in }
        }
    }

    func inputComplete() {
        plugin?.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
            deviceId: deviceId,
            type: .oobOutputRequested,
            message: "Input complete",
            progress: 60,
            attentionTimer: nil
        )) { _ in }
    }

    func provisioningState(of unprovisionedDevice: NordicMesh.UnprovisionedDevice, didChangeTo state: ProvisioningState) {
        guard let plugin, let pm = plugin.provisioningManagersByDeviceId[deviceId] else { return }

        switch state {
        case .requestingCapabilities:
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .started,
                message: "Requesting capabilities",
                progress: 1,
                attentionTimer: nil
            )) { _ in }

        case .capabilitiesReceived(let caps):
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .capabilitiesReceived,
                message: "Capabilities received",
                progress: 5,
                attentionTimer: nil
            )) { _ in }

            let algorithm: Algorithm = caps.algorithms.contains(.BTM_ECDH_P256_HMAC_SHA256_AES_CCM)
                ? .BTM_ECDH_P256_HMAC_SHA256_AES_CCM
                : .BTM_ECDH_P256_CMAC_AES128_AES_CCM
            let publicKey: PublicKey = .noOobPublicKey

            let method = Int(plugin.provisioningRequestedParamsByDeviceId[deviceId]?.oobMethod ?? 0)
            let auth: AuthenticationMethod
            switch method {
            case 1:
                auth = .staticOob
            case 2:
                if caps.outputOobActions.contains(.outputNumeric) {
                    auth = .outputOob(action: .outputNumeric, size: min(caps.outputOobSize, 8))
                } else if caps.outputOobActions.contains(.outputAlphanumeric) {
                    auth = .outputOob(action: .outputAlphanumeric, size: min(caps.outputOobSize, 8))
                } else {
                    auth = .noOob
                }
            case 3:
                if caps.inputOobActions.contains(.inputNumeric) {
                    auth = .inputOob(action: .inputNumeric, size: min(caps.inputOobSize, 8))
                } else if caps.inputOobActions.contains(.inputAlphanumeric) {
                    auth = .inputOob(action: .inputAlphanumeric, size: min(caps.inputOobSize, 8))
                } else if caps.inputOobActions.contains(.push) {
                    auth = .inputOob(action: .push, size: min(caps.inputOobSize, 1))
                } else {
                    auth = .noOob
                }
            default:
                auth = .noOob
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try pm.provision(usingAlgorithm: algorithm, publicKey: publicKey, authenticationMethod: auth)
                } catch {
                    plugin.provisioningResultByDeviceId[self.deviceId] = .failure(error)
                    plugin.provisioningSemaphoresByDeviceId[self.deviceId]?.signal()
                }
            }

        case .provisioning:
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .started,
                message: "Provisioning in progress",
                progress: 40,
                attentionTimer: nil
            )) { _ in }

        case .complete:
            _ = plugin.meshManager.save()
            // Prefer returning the node as read from Mesh DB (elements/models filled).
            let out: ProvisionedNode
            if let net = plugin.meshManager.meshNetwork,
               let unicast = pm.unicastAddress ?? pm.suggestedUnicastAddress,
               let node = net.node(withAddress: unicast),
               let mapped = plugin.convertNordicNodeToPigeon(node) {
                out = mapped
            } else {
                let addr: Int64 = Int64(pm.unicastAddress ?? pm.suggestedUnicastAddress ?? 0)
                out = ProvisionedNode(
                    nodeId: deviceId,
                    name: unprovisionedDevice.name ?? "Node",
                    unicastAddress: addr,
                    uuid: plugin.provisioningUuidBytesByDeviceId[deviceId] ?? [],
                    elements: [],
                    provisioned: true
                )
            }
            plugin.provisioningResultByDeviceId[deviceId] = .success(out)
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .provisioningCompleted,
                message: "Provisioning completed",
                progress: 100,
                attentionTimer: nil
            )) { _ in }
            plugin.provisioningSemaphoresByDeviceId[deviceId]?.signal()

        case .failed(let error):
            plugin.provisioningResultByDeviceId[deviceId] = .failure(error)
            plugin.flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: deviceId,
                type: .failed,
                message: "Provisioning failed: \(error.localizedDescription)",
                progress: nil,
                attentionTimer: nil
            )) { _ in }
            plugin.provisioningSemaphoresByDeviceId[deviceId]?.signal()

        case .ready:
            break
        }
    }
}


private struct RawAccessMessage: NordicMesh.MeshMessage {
    let opCode: UInt32
    let parameters: Data?
    let security: MeshMessageSecurity = .low
    let isSegmented: Bool = false
    
    init(opCode: UInt32, parameters: Data) {
        self.opCode = opCode
        self.parameters = parameters
    }
    
    init?(parameters: Data) {
        // This type is intended for outbound raw messages only.
        return nil
    }
}

private extension Data {
    init?(hexString: String) {
        let s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        guard s.count % 2 == 0 else { return nil }
        var data = Data(capacity: s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            let byteString = s[i..<j]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            i = j
        }
        self = data
    }

    var hexUpper: String {
        map { String(format: "%02X", $0) }.joined()
    }
}

// MARK: - MeshNetworkDelegate (incoming access messages)

extension PlatoJobsMeshPlugin: MeshNetworkDelegate {
    public func meshNetworkManager(
        _ manager: MeshNetworkManager,
        didReceiveMessage message: NordicMesh.MeshMessage,
        sentFrom source: Address,
        to destination: MeshAddress
    ) {
        let opcode = Int64(message.opCode)
        let bytes = Array(message.parameters ?? Data()).map { Int64($0) }
        let pigeon = MeshMessage(
            opcode: opcode,
            address: Int64(source),
            appKeyIndex: nil,
            parameters: [
                "bytes": bytes
            ]
        )
        flutterApi?.onMessageReceived(message: pigeon) { _ in }

        flutterApi?.onRxAccessMessage(
            event: RxAccessMessage(
                opcode: opcode,
                parameters: bytes,
                source: Int64(source),
                destination: Int64(destination.address),
                metadataStatus: .available
            )
        ) { _ in }
    }
}

// MARK: - CBCentralManagerDelegate

extension PlatoJobsMeshPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if scanning, central.state == .poweredOn {
            central.scanForPeripherals(withServices: [meshProxyService, meshProvisioningService], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        peripheralsById[deviceId] = peripheral

        let advUuids = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let svc: String
        if advUuids.contains(meshProvisioningService) {
            svc = "1827"
        } else if advUuids.contains(meshProxyService) {
            svc = "1828"
        } else {
            svc = ""
        }

        let dev = FlutterUnprovisionedDevice(
            deviceId: deviceId,
            name: peripheral.name ?? "Proxy",
            rssi: Int64(RSSI.intValue),
            uuid: [], // Not a mesh UUID; keep empty for now.
            serviceUuid: svc
        )
        flutterApi?.onDeviceDiscovered(device: dev) { _ in }
    }
}

// MARK: - CBPeripheralDelegate (PB-GATT provisioning bearer groundwork)

extension PlatoJobsMeshPlugin: CBPeripheralDelegate {
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral.identifier.uuidString == provisioningPeripheral?.identifier.uuidString {
            provisioningConnected = true
            peripheral.discoverServices([meshProvisioningService])
            flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: peripheral.identifier.uuidString,
                type: .capabilitiesReceived,
                message: "PB-GATT connected; discovering provisioning service",
                progress: 10,
                attentionTimer: nil
            )) { _ in }
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier.uuidString == provisioningPeripheral?.identifier.uuidString {
            provisioningConnected = false
            flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: peripheral.identifier.uuidString,
                type: .failed,
                message: "PB-GATT connect failed: \(error?.localizedDescription ?? "unknown")",
                progress: nil,
                attentionTimer: nil
            )) { _ in }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier.uuidString == provisioningPeripheral?.identifier.uuidString {
            provisioningConnected = false
            flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: peripheral.identifier.uuidString,
                type: .failed,
                message: "PB-GATT disconnected",
                progress: nil,
                attentionTimer: nil
            )) { _ in }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral.identifier.uuidString == provisioningPeripheral?.identifier.uuidString else { return }
        if let error {
            flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
                deviceId: peripheral.identifier.uuidString,
                type: .failed,
                message: "Service discovery failed: \(error.localizedDescription)",
                progress: nil,
                attentionTimer: nil
            )) { _ in }
            return
        }
        let hasProvisioning = (peripheral.services ?? []).contains(where: { $0.uuid == meshProvisioningService })
        flutterApi?.onProvisioningEvent(event: ProvisioningEvent(
            deviceId: peripheral.identifier.uuidString,
            type: hasProvisioning ? .capabilitiesReceived : .failed,
            message: hasProvisioning ? "Provisioning service discovered" : "Provisioning service not found",
            progress: hasProvisioning ? 20 : nil,
            attentionTimer: nil
        )) { _ in }
    }
}

// MARK: - BearerDelegate (Proxy bearer lifecycle)

extension PlatoJobsMeshPlugin: BearerDelegate {
    public func bearerDidOpen(_ bearer: Bearer) {
        proxyConnected = true
    }

    public func bearer(_ bearer: Bearer, didClose error: Error?) {
        proxyConnected = false
    }
}

private extension PlatoJobsMeshPlugin {
    func convertNordicNodeToPigeon(_ node: NordicMesh.Node) -> ProvisionedNode? {
        let elements: [Element] = node.elements.map { el in
            let models: [Model] = el.models.compactMap { m in
                // Only expose SIG models here (companyIdentifier == nil) for now.
                guard m.companyIdentifier == nil else { return nil }
                var out = Model()
                out.modelId = Int64(m.modelIdentifier)
                out.modelName = m.name
                out.publishable = true
                out.subscribable = true
                out.boundAppKeyIndexes = m.boundApplicationKeys.map { Int64($0.index) }
                out.subscriptions = m.subscriptions.map { Int64($0.address.address) }
                if let pub = m.publish {
                    out.publication = Publication(
                        address: Int64(pub.publicationAddress.address),
                        appKeyIndex: Int64(pub.applicationKey.index),
                        ttl: pub.ttl == 0xFF ? nil : Int64(pub.ttl)
                    )
                } else {
                    out.publication = nil
                }
                return out
            }
            return Element(
                address: Int64(el.unicastAddress.address),
                models: models
            )
        }

        // Prefer reporting the node UUID as bytes.
        var uuid = node.uuid.uuid
        let uuidBytes: [Int64] = withUnsafeBytes(of: &uuid) { raw in
            raw.map { Int64($0) }
        }

        return ProvisionedNode(
            nodeId: node.uuid.uuidString,
            name: node.name ?? "Node",
            unicastAddress: Int64(node.unicastAddress.address),
            uuid: uuidBytes,
            elements: elements,
            provisioned: true
        )
    }

    // Best-effort helper for allocating group addresses.
    // Nordic iOS library doesn't expose a convenience, so we scan for the next free group address.
    func nextAvailableGroupAddress(in net: MeshNetwork) -> Address {
        let used = Set(net.groups.map { $0.address })
        var a = Address(0xC000)
        while used.contains(a) && a.address < 0xFEFF {
            a = Address(a.address + 1)
        }
        return a
    }

    func waitUntil(timeoutSeconds: TimeInterval, predicate: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if predicate() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return predicate()
    }

    func sendConfig(_ message: AcknowledgedConfigMessage, destination: Address) throws -> ConfigResponse {
        // MeshNetworkManager uses async/await; Pigeon HostApi is sync, so bridge with semaphore.
        let sem = DispatchSemaphore(value: 0)
        var out: Result<ConfigResponse, Error>?
        Task {
            do {
                let resp = try await meshManager.send(message, to: destination)
                out = .success(resp)
            } catch {
                out = .failure(error)
            }
            sem.signal()
        }
        // Hard timeout to avoid hanging the Flutter thread forever.
        if sem.wait(timeout: .now() + 10.0) == .timedOut {
            throw NSError(domain: "nrf_mesh_flutter", code: 408, userInfo: [
                NSLocalizedDescriptionKey: "Config message timeout"
            ])
        }
        switch out {
        case .success(let resp): return resp
        case .failure(let err): throw err
        case .none:
            throw NSError(domain: "nrf_mesh_flutter", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Config message unknown failure"
            ])
        }
    }

    func resolveSigModel(elementAddress: Int64, modelId: Int64) -> NordicMesh.Model? {
        guard let net = meshManager.meshNetwork else { return nil }
        let addr = Address(UInt16(truncatingIfNeeded: elementAddress))
        guard let node = net.node(withAddress: addr) else { return nil }
        // Find the element with exact unicast address.
        guard let element = node.elements.first(where: { $0.unicastAddress == addr }) else { return nil }
        return element.models.first(where: { $0.modelIdentifier == UInt16(modelId) && $0.companyIdentifier == nil })
    }

    func resolveAppKeyAndSigModel(
        elementAddress: Int64,
        modelId: Int64,
        appKeyIndex: Int64
    ) -> (ApplicationKey, NordicMesh.Model)? {
        guard let net = meshManager.meshNetwork else { return nil }
        guard let model = resolveSigModel(elementAddress: elementAddress, modelId: modelId) else { return nil }
        let keyIndex = KeyIndex(UInt16(truncatingIfNeeded: appKeyIndex))
        guard let appKey = net.applicationKeys.first(where: { $0.index == keyIndex }) else { return nil }
        return (appKey, model)
    }

    func resolveOrCreateGroup(address: Int64) -> Group? {
        guard let net = meshManager.meshNetwork else { return nil }
        let a = Address(UInt16(truncatingIfNeeded: address))
        if let g = net.group(withAddress: a) {
            return g
        }
        do {
            let g = try Group(name: String(format: "Group %04X", a), address: a)
            try net.add(group: g)
            return g
        } catch {
            return nil
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
