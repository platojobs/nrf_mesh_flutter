import Flutter
import UIKit
import nRFMeshProvision

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
    private var meshNetwork: nRFMeshProvision.MeshNetwork?
    private var flutterApi: MeshFlutterApi?
    private var nodes: [ProvisionedNode] = []
    private var nextUnicast: Int64 = 1

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PlatoJobsMeshPlugin()
        instance.flutterApi = MeshFlutterApi(binaryMessenger: registrar.messenger())
        MeshApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }

    func createNetwork(name: String) throws -> MeshNetwork {
        // Placeholder: keep state in-memory for now.
        meshNetwork = nRFMeshProvision.MeshNetwork(name: name)
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
        let name = meshNetwork?.name ?? "default"
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

    func saveNetwork() throws -> Bool { true }
    func exportNetwork(path: String) throws -> Bool { true }
    func importNetwork(path: String) throws -> Bool { true }
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
        return MeshGroup(
            groupId: UUID().uuidString,
            name: name,
            address: 0xC000,
            nodeIds: []
        )
    }

    func getGroups() throws -> [MeshGroup] { [] }
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
}
