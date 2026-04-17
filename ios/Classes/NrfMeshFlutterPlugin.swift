import Flutter
import UIKit
import nRFMeshProvision

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin, MeshApi {
    private var meshNetwork: nRFMeshProvision.MeshNetwork?
    private var flutterApi: MeshFlutterApi?

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
        return ProvisionedNode(
            nodeId: device.deviceId ?? "",
            name: params.deviceName ?? "Node",
            unicastAddress: 1,
            uuid: device.uuid,
            elements: [],
            provisioned: true
        )
    }

    func sendMessage(message: MeshMessage) throws { }
    func getNodes() throws -> [ProvisionedNode] { [] }
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
}
