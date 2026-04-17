package com.platojobs.nrf_mesh

import io.flutter.embedding.engine.plugins.FlutterPlugin
import no.nordicsemi.android.mesh.MeshNetwork as NordicMeshNetwork

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
    MeshApi {

    private var meshManager: MeshManager? = null
    private var flutterApi: MeshFlutterApi? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        meshManager = MeshManager()
        flutterApi = MeshFlutterApi(flutterPluginBinding.binaryMessenger)
        MeshApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MeshApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        meshManager = null
    }

    // MeshApi implementation (Pigeon)

    override fun createNetwork(name: String): MeshNetwork {
        val network = meshManager?.createNetwork(name) ?: NordicMeshNetwork.create(name)
        meshManager?.setNetwork(network)
        return network.toPigeon()
    }

    override fun loadNetwork(): MeshNetwork {
        val network = meshManager?.getNetwork() ?: NordicMeshNetwork.create("default")
        meshManager?.setNetwork(network)
        return network.toPigeon()
    }

    override fun saveNetwork(): Boolean = true

    override fun exportNetwork(path: String): Boolean = true

    override fun importNetwork(path: String): Boolean = true

    override fun startScan() {
        // Transport layer is currently abstracted away; no-op for now.
    }

    override fun stopScan() {
        // no-op
    }

    override fun provisionDevice(
        device: UnprovisionedDevice,
        params: ProvisioningParameters
    ): ProvisionedNode {
        // Placeholder: return a minimal node to keep API usable.
        return ProvisionedNode(
            nodeId = device.deviceId ?: "",
            name = params.deviceName,
            unicastAddress = 1L,
            uuid = device.uuid,
            elements = emptyList(),
            provisioned = true
        )
    }

    override fun sendMessage(message: MeshMessage) {
        // Placeholder: no-op
    }

    override fun getNodes(): List<ProvisionedNode> = emptyList()

    override fun removeNode(nodeId: String) {
        // no-op
    }

    override fun createGroup(name: String): MeshGroup {
        return MeshGroup(
            groupId = java.util.UUID.randomUUID().toString(),
            name = name,
            address = 0xC000,
            nodeIds = emptyList()
        )
    }

    override fun getGroups(): List<MeshGroup> = emptyList()

    override fun addNodeToGroup(nodeId: String, groupId: String) {
        // no-op
    }
}

/**
 * Delegate interface for MeshManager events
 */
class MeshManager {
    private var meshNetwork: NordicMeshNetwork? = null

    fun getNetwork(): NordicMeshNetwork? = meshNetwork
    fun setNetwork(network: NordicMeshNetwork) {
        meshNetwork = network
    }

    /**
     * Create a new mesh network
     */
    fun createNetwork(name: String): NordicMeshNetwork {
        val network = NordicMeshNetwork.create(name)
        meshNetwork = network
        return network
    }
}

private fun NordicMeshNetwork.toPigeon(): MeshNetwork {
    return MeshNetwork(
        networkId = name,
        name = name,
        networkKeys = emptyList(),
        appKeys = emptyList(),
        nodes = emptyList(),
        groups = emptyList(),
        provisioner = Provisioner(
            name = "Provisioner",
            provisionerId = java.util.UUID.randomUUID().toString(),
            addressRange = listOf(1L, 0x0100L)
        )
    )
}
