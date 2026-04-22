import Flutter
import UIKit
import NordicMesh
import CoreBluetooth

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
    private let meshManager = MeshNetworkManager(using: LocalStorage(fileName: "nrf_mesh_flutter_meshdata.json"))
    private var nordicNetwork: NordicMesh.MeshNetwork?
    private var flutterApi: MeshFlutterApi?
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

    // Bluetooth Mesh Proxy Service UUID (0x1828)
    private let meshProxyService = CBUUID(string: "1828")

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
            centralManager.scanForPeripherals(withServices: [meshProxyService], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        }
    }

    func stopScan() throws {
        scanning = false
        centralManager.stopScan()
    }

    func provisionDevice(device: UnprovisionedDevice, params: ProvisioningParameters) throws -> ProvisionedNode {
        let unicast = nextUnicast
        nextUnicast += 1

        let elementAddress = unicast
        let genericOnOffServer: Int64 = 0x1000
        let genericLevelServer: Int64 = 0x1002

        var onOff = Model()
        onOff.modelId = genericOnOffServer
        onOff.modelName = "Generic OnOff Server"
        onOff.publishable = true
        onOff.subscribable = true
        onOff.boundAppKeyIndexes = []
        onOff.subscriptions = []
        onOff.publication = nil

        var level = Model()
        level.modelId = genericLevelServer
        level.modelName = "Generic Level Server"
        level.publishable = true
        level.subscribable = true
        level.boundAppKeyIndexes = []
        level.subscriptions = []
        level.publication = nil

        var element = Element()
        element.address = elementAddress
        element.models = [onOff, level]

        let node = ProvisionedNode(
            nodeId: device.deviceId ?? "",
            name: params.deviceName ?? "Node",
            unicastAddress: unicast,
            uuid: device.uuid,
            elements: [element],
            provisioned: true
        )
        nodes.append(node)
        return node
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
    func getNodes() throws -> [ProvisionedNode] { nodes }
    func removeNode(nodeId: String) throws { }

    func createGroup(name: String) throws -> MeshGroup {
        let group = MeshGroup(
            groupId: UUID().uuidString,
            name: name,
            address: 0xC000,
            nodeIds: []
        )
        groups.append(group)
        return group
    }

    func getGroups() throws -> [MeshGroup] { groups }
    func addNodeToGroup(nodeId: String, groupId: String) throws { }

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
    }
}

// MARK: - CBCentralManagerDelegate

extension PlatoJobsMeshPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if scanning, central.state == .poweredOn {
            central.scanForPeripherals(withServices: [meshProxyService], options: [
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

        let dev = UnprovisionedDevice(
            deviceId: deviceId,
            name: peripheral.name ?? "Proxy",
            rssi: Int64(RSSI.intValue),
            uuid: [] // Not a mesh UUID; keep empty for now.
        )
        flutterApi?.onDeviceDiscovered(device: dev) { _ in }
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
