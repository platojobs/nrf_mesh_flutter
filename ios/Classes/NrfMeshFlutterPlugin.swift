import Flutter
import UIKit
import nRFMeshProvision

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
    private var meshNetwork: nRFMeshProvision.MeshNetwork?
    private var flutterApi: MeshFlutterApi?
    private var nodes: [ProvisionedNode] = []
    private var nextUnicast: Int64 = 1
    private var networkName: String = "default"
    private var groups: [MeshGroup] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PlatoJobsMeshPlugin()
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
        try data.write(to: url, options: [.atomic])
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
            let e = Element()
            e.address = (eo["address"] as? NSNumber)?.int64Value ?? 0
            let modelsDict = eo["models"] as? [[String: Any]] ?? []
            e.models = modelsDict.map { mo in
                let m = Model()
                m.modelId = (mo["modelId"] as? NSNumber)?.int64Value ?? 0
                m.modelName = mo["modelName"] as? String ?? ""
                m.publishable = mo["publishable"] as? Bool ?? true
                m.subscribable = mo["subscribable"] as? Bool ?? true
                m.boundAppKeyIndexes = mo["boundAppKeyIndexes"] as? [Int] ?? []
                m.subscriptions = mo["subscriptions"] as? [Int] ?? []
                if let po = mo["publication"] as? [String: Any] {
                    let pub = Publication()
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
        // Placeholder: keep state in-memory for now.
        meshNetwork = nRFMeshProvision.MeshNetwork(name: name)
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
        if let url = defaultFileURL(),
           (try? importFromURL(url)) == true {
            // loaded into memory
        } else {
            networkName = meshNetwork?.name ?? "default"
        }
        let name = networkName
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
        guard let url = defaultFileURL() else { return false }
        return try exportToURL(url)
    }

    func exportNetwork(path: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        return try exportToURL(url)
    }

    func importNetwork(path: String) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        return try importFromURL(url)
    }
    func startScan() throws { }
    func stopScan() throws { }

    func provisionDevice(device: UnprovisionedDevice, params: ProvisioningParameters) throws -> ProvisionedNode {
        let unicast = nextUnicast
        nextUnicast += 1

        let elementAddress = unicast
        let genericOnOffServer: Int64 = 0x1000
        let genericLevelServer: Int64 = 0x1002

        let onOff = Model()
        onOff.modelId = genericOnOffServer
        onOff.modelName = "Generic OnOff Server"
        onOff.publishable = true
        onOff.subscribable = true
        onOff.boundAppKeyIndexes = []
        onOff.subscriptions = []
        onOff.publication = nil

        let level = Model()
        level.modelId = genericLevelServer
        level.modelName = "Generic Level Server"
        level.publishable = true
        level.subscribable = true
        level.boundAppKeyIndexes = []
        level.subscriptions = []
        level.publication = nil

        let element = Element()
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

    func sendMessage(message: MeshMessage) throws { }
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
        _ updater: (Model) -> Void
    ) -> Bool {
        var changed = false
        for nodeIdx in nodes.indices {
            let node = nodes[nodeIdx]
            guard let elements = node.elements else { continue }
            for elIdx in elements.indices {
                let el = elements[elIdx]
                if el.address != elementAddress { continue }
                guard let models = el.models else { continue }
                for mIdx in models.indices {
                    let m = models[mIdx]
                    if m.modelId != modelId { continue }
                    updater(m)
                    changed = true
                }
            }
        }
        return changed
    }

    func bindAppKey(elementAddress: Int64, modelId: Int64, appKeyIndex: Int64) throws -> Bool {
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.boundAppKeyIndexes ?? [])
            set.insert(Int(appKeyIndex))
            m.boundAppKeyIndexes = Array(set).sorted()
        }
    }

    func unbindAppKey(elementAddress: Int64, modelId: Int64, appKeyIndex: Int64) throws -> Bool {
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.boundAppKeyIndexes ?? [])
            set.remove(Int(appKeyIndex))
            m.boundAppKeyIndexes = Array(set).sorted()
        }
    }

    func addSubscription(elementAddress: Int64, modelId: Int64, address: Int64) throws -> Bool {
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.subscriptions ?? [])
            set.insert(Int(address))
            m.subscriptions = Array(set).sorted()
        }
    }

    func removeSubscription(elementAddress: Int64, modelId: Int64, address: Int64) throws -> Bool {
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            var set = Set(m.subscriptions ?? [])
            set.remove(Int(address))
            m.subscriptions = Array(set).sorted()
        }
    }

    func setPublication(elementAddress: Int64, modelId: Int64, publishAddress: Int64, appKeyIndex: Int64, ttl: Int64?) throws -> Bool {
        return updateModel(elementAddress: elementAddress, modelId: modelId) { m in
            let pub = Publication()
            pub.address = publishAddress
            pub.appKeyIndex = appKeyIndex
            pub.ttl = ttl
            m.publication = pub
        }
    }

    // Proxy connection (P1 real-transport prerequisite)
    private var proxyConnected: Bool = false

    func connectProxy(deviceId: String, proxyUnicastAddress: Int64) throws -> Bool {
        // TODO: Implement real PB-GATT / Proxy connection using nRFMeshProvision transport layer.
        proxyConnected = true
        return true
    }

    func disconnectProxy() throws -> Bool {
        proxyConnected = false
        return true
    }

    func isProxyConnected() throws -> Bool {
        return proxyConnected
    }
}
