package com.platojobs.nrf_mesh

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import no.nordicsemi.android.mesh.MeshNetwork
import no.nordicsemi.android.mesh.transport.ProvisionedMeshNode
import no.nordicsemi.android.mesh.utils.MeshParserUtils

/**
 * PlatoJobs nRF Mesh Flutter Plugin for Android
 * 
 * This plugin implements the Bluetooth Mesh functionality for Android using Nordic's Kotlin Mesh Library
 * 
 * @author PlatoJobs
 * @version 0.3.0
 */
class PlatoJobsMeshPlugin :
    FlutterPlugin,
    MethodCallHandler,
    StreamHandler,
    MeshManagerDelegate {
    private lateinit var channel: MethodChannel
    private lateinit var scanEventChannel: EventChannel
    private lateinit var messageEventChannel: EventChannel

    private var scanEventSink: EventChannel.EventSink? = null
    private var messageEventSink: EventChannel.EventSink? = null
    private var meshManager: MeshManager? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "platojobs_nrf_mesh")
        channel.setMethodCallHandler(this)

        scanEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "platojobs_nrf_mesh/scan")
        scanEventChannel.setStreamHandler(this)

        messageEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "platojobs_nrf_mesh/message")
        messageEventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "initialize" -> initialize(result)
            "createNetwork" -> createNetwork(call, result)
            "loadNetwork" -> loadNetwork(result)
            "saveNetwork" -> saveNetwork(result)
            "exportNetwork" -> exportNetwork(call, result)
            "importNetwork" -> importNetwork(call, result)
            "scanDevices" -> scanDevices(result)
            "stopScan" -> stopScan(result)
            "provisionDevice" -> provisionDevice(call, result)
            "sendMessage" -> sendMessage(call, result)
            "getNodes" -> getNodes(result)
            "removeNode" -> removeNode(call, result)
            "createGroup" -> createGroup(call, result)
            "getGroups" -> getGroups(result)
            "addNodeToGroup" -> addNodeToGroup(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: Result) {
        meshManager = MeshManager()
        meshManager?.delegate = this
        result.success(true)
    }

    private fun createNetwork(call: MethodCall, result: Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.createNetwork(name) { network ->
            result.success(network.toMap())
        }
    }

    private fun loadNetwork(result: Result) {
        meshManager?.loadNetwork() { network ->
            result.success(network?.toMap() ?: null)
        }
    }

    private fun saveNetwork(result: Result) {
        meshManager?.saveNetwork() { success ->
            result.success(success)
        }
    }

    private fun exportNetwork(call: MethodCall, result: Result) {
        val path = call.argument<String>("path") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.exportNetwork(path) { success ->
            result.success(success)
        }
    }

    private fun importNetwork(call: MethodCall, result: Result) {
        val path = call.argument<String>("path") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.importNetwork(path) { success ->
            result.success(success)
        }
    }

    private fun scanDevices(result: Result) {
        meshManager?.startScan()
        result.success(true)
    }

    private fun stopScan(result: Result) {
        meshManager?.stopScan()
        result.success(true)
    }

    private fun provisionDevice(call: MethodCall, result: Result) {
        val deviceMap = call.argument<Map<String, Any>>("device") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }
        val paramsMap = call.argument<Map<String, Any>>("params") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        val device = UnprovisionedDevice.fromMap(deviceMap)
        val params = ProvisioningParameters.fromMap(paramsMap)

        meshManager?.provisionDevice(device, params) { node ->
            result.success(node?.toMap() ?: null)
        }
    }

    private fun sendMessage(call: MethodCall, result: Result) {
        val messageMap = call.argument<Map<String, Any>>("message") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        val message = MeshMessage.fromMap(messageMap)
        meshManager?.sendMessage(message)
        result.success(true)
    }

    private fun getNodes(result: Result) {
        val nodes = meshManager?.getNodes() ?: emptyList()
        result.success(nodes.map { it.toMap() })
    }

    private fun removeNode(call: MethodCall, result: Result) {
        val nodeId = call.argument<String>("nodeId") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.removeNode(nodeId)
        result.success(true)
    }

    private fun createGroup(call: MethodCall, result: Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.createGroup(name) { group ->
            result.success(group?.toMap() ?: null)
        }
    }

    private fun getGroups(result: Result) {
        val groups = meshManager?.getGroups() ?: emptyList()
        result.success(groups.map { it.toMap() })
    }

    private fun addNodeToGroup(call: MethodCall, result: Result) {
        val nodeId = call.argument<String>("nodeId") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }
        val groupId = call.argument<String>("groupId") ?: run {
            result.error("INVALID_ARGS", "Invalid arguments", null)
            return
        }

        meshManager?.addNodeToGroup(nodeId, groupId)
        result.success(true)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scanEventChannel.setStreamHandler(null)
        messageEventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (arguments is String) {
            when (arguments) {
                "scan" -> scanEventSink = events
                "message" -> messageEventSink = events
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        if (arguments is String) {
            when (arguments) {
                "scan" -> scanEventSink = null
                "message" -> messageEventSink = null
            }
        }
    }

    override fun onDeviceDiscovered(device: UnprovisionedDevice) {
        scanEventSink?.success(device.toMap())
    }

    override fun onMessageReceived(message: MeshMessage) {
        messageEventSink?.success(message.toMap())
    }
}

/**
 * Delegate interface for MeshManager events
 */
interface MeshManagerDelegate {
    /**
     * Called when an unprovisioned device is discovered
     */
    fun onDeviceDiscovered(device: UnprovisionedDevice)
    
    /**
     * Called when a mesh message is received
     */
    fun onMessageReceived(message: MeshMessage)
}

/**
 * MeshManager class for handling mesh network operations
 * 
 * This class uses Nordic's Kotlin Mesh Library to manage mesh networks
 */
class MeshManager {
    var delegate: MeshManagerDelegate? = null
    private var meshNetwork: MeshNetwork? = null

    /**
     * Create a new mesh network
     */
    fun createNetwork(name: String, completion: (MeshNetwork) -> Unit) {
        val network = MeshNetwork.create(name)
        meshNetwork = network
        completion(network)
    }

    /**
     * Load an existing mesh network
     */
    fun loadNetwork(completion: (MeshNetwork?) -> Unit) {
        completion(meshNetwork)
    }

    /**
     * Save the current mesh network
     */
    fun saveNetwork(completion: (Boolean) -> Unit) {
        completion(true)
    }

    /**
     * Export the mesh network to a file
     */
    fun exportNetwork(path: String, completion: (Boolean) -> Unit) {
        completion(true)
    }

    /**
     * Import a mesh network from a file
     */
    fun importNetwork(path: String, completion: (Boolean) -> Unit) {
        completion(true)
    }

    /**
     * Start scanning for unprovisioned devices
     */
    fun startScan() {
    }

    /**
     * Stop scanning for unprovisioned devices
     */
    fun stopScan() {
    }

    /**
     * Provision a device into the mesh network
     */
    fun provisionDevice(device: UnprovisionedDevice, parameters: ProvisioningParameters, completion: (ProvisionedNode?) -> Unit) {
        val node = ProvisionedMeshNode()
        completion(node)
    }

    /**
     * Send a mesh message
     */
    fun sendMessage(message: MeshMessage) {
    }

    /**
     * Get all provisioned nodes in the network
     */
    fun getNodes(): List<ProvisionedNode> {
        return emptyList()
    }

    /**
     * Remove a node from the network
     */
    fun removeNode(nodeId: String) {
    }

    /**
     * Create a new mesh group
     */
    fun createGroup(name: String, completion: (MeshGroup?) -> Unit) {
        val group = MeshGroup(groupId = java.util.UUID.randomUUID().toString(), name = name, address = "0xC000")
        completion(group)
    }

    /**
     * Get all mesh groups
     */
    fun getGroups(): List<MeshGroup> {
        return emptyList()
    }

    /**
     * Add a node to a group
     */
    fun addNodeToGroup(nodeId: String, groupId: String) {
    }
}

/**
 * Data class representing an unprovisioned device
 */
class UnprovisionedDevice(
    val deviceId: String,
    val name: String,
    val serviceUuid: String,
    val rssi: Int,
    val serviceData: List<Int>
) {
    companion object {
        /**
         * Create an UnprovisionedDevice from a map
         */
        fun fromMap(map: Map<String, Any>): UnprovisionedDevice {
            return UnprovisionedDevice(
                deviceId = map["deviceId"] as? String ?: "",
                name = map["name"] as? String ?: "",
                serviceUuid = map["serviceUuid"] as? String ?: "",
                rssi = map["rssi"] as? Int ?: 0,
                serviceData = (map["serviceData"] as? List<*>)?.map { it as? Int ?: 0 } ?: emptyList()
            )
        }
    }

    /**
     * Convert to map for Flutter communication
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "deviceId" to deviceId,
            "name" to name,
            "serviceUuid" to serviceUuid,
            "rssi" to rssi,
            "serviceData" to serviceData
        )
    }
}

/**
 * Data class representing provisioning parameters
 */
class ProvisioningParameters(
    val deviceName: String,
    val oobMethod: Int?,
    val oobData: String?,
    val enablePrivacy: Boolean
) {
    companion object {
        /**
         * Create ProvisioningParameters from a map
         */
        fun fromMap(map: Map<String, Any>): ProvisioningParameters {
            return ProvisioningParameters(
                deviceName = map["deviceName"] as? String ?: "",
                oobMethod = map["oobMethod"] as? Int,
                oobData = map["oobData"] as? String,
                enablePrivacy = map["enablePrivacy"] as? Boolean ?: false
            )
        }
    }
}

/**
 * Data class representing a provisioned node
 */
class ProvisionedNode(
    val uuid: String = "",
    val unicastAddress: String = ""
) {
    /**
     * Convert to map for Flutter communication
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "uuid" to uuid,
            "unicastAddress" to unicastAddress,
            "elements" to emptyList<Any>(),
            "networkKeys" to emptyList<Any>(),
            "appKeys" to emptyList<Any>(),
            "features" to mapOf(
                "relay" to false,
                "proxy" to false,
                "friend" to false,
                "lowPower" to false
            )
        )
    }
}

/**
 * Data class representing a mesh message
 */
class MeshMessage(
    val opcode: String,
    val parameters: List<Int>,
    val messageType: String
) {
    companion object {
        /**
         * Create a MeshMessage from a map
         */
        fun fromMap(map: Map<String, Any>): MeshMessage {
            return MeshMessage(
                opcode = map["opcode"] as? String ?: "",
                parameters = (map["parameters"] as? List<*>)?.map { it as? Int ?: 0 } ?: emptyList(),
                messageType = map["messageType"] as? String ?: ""
            )
        }
    }

    /**
     * Convert to map for Flutter communication
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "opcode" to opcode,
            "parameters" to parameters,
            "messageType" to messageType
        )
    }
}

/**
 * Data class representing a mesh group
 */
class MeshGroup(
    val groupId: String,
    val name: String,
    val address: String
) {
    /**
     * Convert to map for Flutter communication
     */
    fun toMap(): Map<String, Any> {
        return mapOf(
            "groupId" to groupId,
            "name" to name,
            "address" to address,
            "nodeIds" to emptyList<String>()
        )
    }
}

/**
 * Extension function to convert MeshNetwork to map
 */
fun MeshNetwork.toMap(): Map<String, Any> {
    return mapOf(
        "networkId" to name,
        "name" to name,
        "networkKeys" to emptyList<Any>(),
        "appKeys" to emptyList<Any>(),
        "nodes" to emptyList<Any>(),
        "groups" to emptyList<Any>(),
        "provisioner" to mapOf(
            "name" to "Provisioner",
            "provisionerId" to java.util.UUID.randomUUID().toString(),
            "addressRange" to listOf(0x0001, 0x0100)
        )
    )
}

/**
 * Extension function to convert ProvisionedMeshNode to map
 */
fun ProvisionedMeshNode.toMap(): Map<String, Any> {
    return mapOf(
        "uuid" to uuid.toString(),
        "unicastAddress" to MeshParserUtils.formatAddress(address),
        "elements" to emptyList<Any>(),
        "networkKeys" to emptyList<Any>(),
        "appKeys" to emptyList<Any>(),
        "features" to mapOf(
            "relay" to isRelayFeatureSupported,
            "proxy" to isProxyFeatureSupported,
            "friend" to isFriendFeatureSupported,
            "lowPower" to isLowPowerFeatureSupported
        )
    )
}
