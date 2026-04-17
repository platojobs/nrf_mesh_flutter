import Flutter
import UIKit
import nRFMeshProvision

public class PlatoJobsMeshPlugin: NSObject, FlutterPlugin {
    private var meshManager: MeshManager?
    private var scanEventSink: FlutterEventSink?
    private var messageEventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "platojobs_nrf_mesh", binaryMessenger: registrar.messenger())
        let instance = PlatoJobsMeshPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let scanChannel = FlutterEventChannel(name: "platojobs_nrf_mesh/scan", binaryMessenger: registrar.messenger())
        scanChannel.setStreamHandler(instance)

        let messageChannel = FlutterEventChannel(name: "platojobs_nrf_mesh/message", binaryMessenger: registrar.messenger())
        messageChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "createNetwork":
            createNetwork(call: call, result: result)
        case "loadNetwork":
            loadNetwork(result: result)
        case "saveNetwork":
            saveNetwork(result: result)
        case "exportNetwork":
            exportNetwork(call: call, result: result)
        case "importNetwork":
            importNetwork(call: call, result: result)
        case "scanDevices":
            scanDevices(result: result)
        case "stopScan":
            stopScan(result: result)
        case "provisionDevice":
            provisionDevice(call: call, result: result)
        case "sendMessage":
            sendMessage(call: call, result: result)
        case "getNodes":
            getNodes(result: result)
        case "removeNode":
            removeNode(call: call, result: result)
        case "createGroup":
            createGroup(call: call, result: result)
        case "getGroups":
            getGroups(result: result)
        case "addNodeToGroup":
            addNodeToGroup(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(result: @escaping FlutterResult) {
        meshManager = MeshManager()
        meshManager?.delegate = self
        result(true)
    }

    private func createNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.createNetwork(name: name) {
            network in
            result(network.toMap())
        }
    }

    private func loadNetwork(result: @escaping FlutterResult) {
        meshManager?.loadNetwork() {
            network in
            result(network?.toMap() ?? nil)
        }
    }

    private func saveNetwork(result: @escaping FlutterResult) {
        meshManager?.saveNetwork() {
            success in
            result(success)
        }
    }

    private func exportNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.exportNetwork(to: path) {
            success in
            result(success)
        }
    }

    private func importNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.importNetwork(from: path) {
            success in
            result(success)
        }
    }

    private func scanDevices(result: @escaping FlutterResult) {
        meshManager?.startScan()
        result(true)
    }

    private func stopScan(result: @escaping FlutterResult) {
        meshManager?.stopScan()
        result(true)
    }

    private func provisionDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceMap = args["device"] as? [String: Any],
              let paramsMap = args["params"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let device = UnprovisionedDevice.fromMap(deviceMap)
        let params = ProvisioningParameters.fromMap(paramsMap)

        meshManager?.provisionDevice(device, parameters: params) {
            node in
            result(node?.toMap() ?? nil)
        }
    }

    private func sendMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messageMap = args["message"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let message = MeshMessage.fromMap(messageMap)
        meshManager?.sendMessage(message)
        result(true)
    }

    private func getNodes(result: @escaping FlutterResult) {
        let nodes = meshManager?.getNodes() ?? []
        result(nodes.map { $0.toMap() })
    }

    private func removeNode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let nodeId = args["nodeId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.removeNode(nodeId: nodeId)
        result(true)
    }

    private func createGroup(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.createGroup(name: name) {
            group in
            result(group?.toMap() ?? nil)
        }
    }

    private func getGroups(result: @escaping FlutterResult) {
        let groups = meshManager?.getGroups() ?? []
        result(groups.map { $0.toMap() })
    }

    private func addNodeToGroup(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let nodeId = args["nodeId"] as? String,
              let groupId = args["groupId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        meshManager?.addNodeToGroup(nodeId: nodeId, groupId: groupId)
        result(true)
    }
}

extension PlatoJobsMeshPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if let channelName = arguments as? String {
            if channelName == "scan" {
                scanEventSink = events
            } else if channelName == "message" {
                messageEventSink = events
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let channelName = arguments as? String {
            if channelName == "scan" {
                scanEventSink = nil
            } else if channelName == "message" {
                messageEventSink = nil
            }
        }
        return nil
    }
}

extension PlatoJobsMeshPlugin: MeshManagerDelegate {
    func meshManagerDidDiscoverDevice(_ device: UnprovisionedDevice) {
        scanEventSink?(device.toMap())
    }

    func meshManagerDidReceiveMessage(_ message: MeshMessage) {
        messageEventSink?(message.toMap())
    }
}

class MeshManager: NSObject, ScannerDelegate {
    weak var delegate: MeshManagerDelegate?
    private var meshNetwork: MeshNetwork?
    private var scanner: Scanner?

    func createNetwork(name: String, completion: @escaping (MeshNetwork) -> Void) {
        let network = MeshNetwork(name: name)
        meshNetwork = network
        completion(network)
    }

    func loadNetwork(completion: @escaping (MeshNetwork?) -> Void) {
        completion(meshNetwork)
    }

    func saveNetwork(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func exportNetwork(to path: String, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func importNetwork(from path: String, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startScan() {
        scanner = Scanner(delegate: self)
        scanner?.start()
    }

    func stopScan() {
        scanner?.stop()
    }

    func provisionDevice(_ device: UnprovisionedDevice, parameters: ProvisioningParameters, completion: @escaping (ProvisionedNode?) -> Void) {
        completion(ProvisionedNode(uuid: device.deviceId, unicastAddress: "0x0001"))
    }

    func sendMessage(_ message: MeshMessage) {
    }

    func getNodes() -> [ProvisionedNode] {
        return []
    }

    func removeNode(nodeId: String) {
    }

    func createGroup(name: String, completion: @escaping (MeshGroup?) -> Void) {
        completion(MeshGroup(groupId: UUID().uuidString, name: name, address: "0xC000"))
    }

    func getGroups() -> [MeshGroup] {
        return []
    }

    func addNodeToGroup(nodeId: String, groupId: String) {
    }

    func scanner(_ scanner: Scanner, didDiscover unprovisionedDevice: UnprovisionedDevice) {
        delegate?.meshManagerDidDiscoverDevice(unprovisionedDevice)
    }
}

protocol MeshManagerDelegate: AnyObject {
    func meshManagerDidDiscoverDevice(_ device: UnprovisionedDevice)
    func meshManagerDidReceiveMessage(_ message: MeshMessage)
}

class UnprovisionedDevice {
    let deviceId: String
    let name: String
    let serviceUuid: String
    let rssi: Int
    let serviceData: [Int]

    init(deviceId: String, name: String, serviceUuid: String, rssi: Int, serviceData: [Int]) {
        self.deviceId = deviceId
        self.name = name
        self.serviceUuid = serviceUuid
        self.rssi = rssi
        self.serviceData = serviceData
    }

    static func fromMap(_ map: [String: Any]) -> UnprovisionedDevice {
        return UnprovisionedDevice(
            deviceId: map["deviceId"] as? String ?? "",
            name: map["name"] as? String ?? "",
            serviceUuid: map["serviceUuid"] as? String ?? "",
            rssi: map["rssi"] as? Int ?? 0,
            serviceData: (map["serviceData"] as? [Int]) ?? []
        )
    }

    func toMap() -> [String: Any] {
        return [
            "deviceId": deviceId,
            "name": name,
            "serviceUuid": serviceUuid,
            "rssi": rssi,
            "serviceData": serviceData
        ]
    }
}

class ProvisioningParameters {
    let deviceName: String
    let oobMethod: Int?
    let oobData: String?
    let enablePrivacy: Bool

    init(deviceName: String, oobMethod: Int?, oobData: String?, enablePrivacy: Bool) {
        self.deviceName = deviceName
        self.oobMethod = oobMethod
        self.oobData = oobData
        self.enablePrivacy = enablePrivacy
    }

    static func fromMap(_ map: [String: Any]) -> ProvisioningParameters {
        return ProvisioningParameters(
            deviceName: map["deviceName"] as? String ?? "",
            oobMethod: map["oobMethod"] as? Int,
            oobData: map["oobData"] as? String,
            enablePrivacy: map["enablePrivacy"] as? Bool ?? false
        )
    }
}

class ProvisionedNode {
    let uuid: String
    let unicastAddress: String

    init(uuid: String, unicastAddress: String) {
        self.uuid = uuid
        self.unicastAddress = unicastAddress
    }

    func toMap() -> [String: Any] {
        return [
            "uuid": uuid,
            "unicastAddress": unicastAddress,
            "elements": [],
            "networkKeys": [],
            "appKeys": [],
            "features": ["relay": false, "proxy": false, "friend": false, "lowPower": false]
        ]
    }
}

class MeshMessage {
    let opcode: String
    let parameters: [Int]
    let messageType: String

    init(opcode: String, parameters: [Int], messageType: String) {
        self.opcode = opcode
        self.parameters = parameters
        self.messageType = messageType
    }

    static func fromMap(_ map: [String: Any]) -> MeshMessage {
        return MeshMessage(
            opcode: map["opcode"] as? String ?? "",
            parameters: (map["parameters"] as? [Int]) ?? [],
            messageType: map["messageType"] as? String ?? ""
        )
    }

    func toMap() -> [String: Any] {
        return [
            "opcode": opcode,
            "parameters": parameters,
            "messageType": messageType
        ]
    }
}

class MeshGroup {
    let groupId: String
    let name: String
    let address: String

    init(groupId: String, name: String, address: String) {
        self.groupId = groupId
        self.name = name
        self.address = address
    }

    func toMap() -> [String: Any] {
        return [
            "groupId": groupId,
            "name": name,
            "address": address,
            "nodeIds": []
        ]
    }
}

extension MeshNetwork {
    func toMap() -> [String: Any] {
        return [
            "networkId": name,
            "name": name,
            "networkKeys": [],
            "appKeys": [],
            "nodes": [],
            "groups": [],
            "provisioner": ["name": "Provisioner", "provisionerId": UUID().uuidString, "addressRange": [0x0001, 0x0100]]
        ]
    }
}
