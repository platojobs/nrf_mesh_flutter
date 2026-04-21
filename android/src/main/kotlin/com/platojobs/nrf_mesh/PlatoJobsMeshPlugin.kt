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
        return meshManager?.provision(device, params) ?: ProvisionedNode(
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

    override fun getNodes(): List<ProvisionedNode> = meshManager?.getNodes() ?: emptyList()

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

    // Configuration (P1 - minimal, in-memory)
    override fun bindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean =
        meshManager?.bindAppKey(elementAddress, modelId, appKeyIndex) ?: false

    override fun unbindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean =
        meshManager?.unbindAppKey(elementAddress, modelId, appKeyIndex) ?: false

    override fun addSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean =
        meshManager?.addSubscription(elementAddress, modelId, address) ?: false

    override fun removeSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean =
        meshManager?.removeSubscription(elementAddress, modelId, address) ?: false

    override fun setPublication(
        elementAddress: Long,
        modelId: Long,
        publishAddress: Long,
        appKeyIndex: Long,
        ttl: Long?
    ): Boolean = meshManager?.setPublication(elementAddress, modelId, publishAddress, appKeyIndex, ttl) ?: false
}

/**
 * Delegate interface for MeshManager events
 */
class MeshManager {
    private var meshNetwork: NordicMeshNetwork? = null
    private val nodes: MutableList<ProvisionedNode> = mutableListOf()
    private var nextUnicast: Long = 1L

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

    fun provision(device: UnprovisionedDevice, params: ProvisioningParameters): ProvisionedNode {
        val unicast = nextUnicast
        nextUnicast += 1

        val elementAddress = unicast
        val genericOnOffServer = 0x1000L
        val genericLevelServer = 0x1002L

        val node = ProvisionedNode(
            nodeId = device.deviceId ?: "",
            name = params.deviceName,
            unicastAddress = unicast,
            uuid = device.uuid,
            elements = listOf(
                Element(
                    address = elementAddress,
                    models = listOf(
                        Model(
                            modelId = genericOnOffServer,
                            modelName = "Generic OnOff Server",
                            publishable = true,
                            subscribable = true,
                            boundAppKeyIndexes = emptyList(),
                            subscriptions = emptyList(),
                            publication = null
                        ),
                        Model(
                            modelId = genericLevelServer,
                            modelName = "Generic Level Server",
                            publishable = true,
                            subscribable = true,
                            boundAppKeyIndexes = emptyList(),
                            subscriptions = emptyList(),
                            publication = null
                        )
                    )
                )
            ),
            provisioned = true
        )
        nodes.add(node)
        return node
    }

    fun getNodes(): List<ProvisionedNode> = nodes.toList()

    private fun updateModel(
        elementAddress: Long,
        modelId: Long,
        updater: (Model) -> Model
    ): Boolean {
        var changed = false
        for (i in nodes.indices) {
            val n = nodes[i]
            val updatedElements = n.elements?.map { e ->
                if (e.address != elementAddress) return@map e
                val updatedModels = e.models?.map { m ->
                    if (m.modelId != modelId) return@map m
                    changed = true
                    updater(m)
                } ?: emptyList()
                Element(address = e.address, models = updatedModels)
            } ?: emptyList()
            if (changed) {
                nodes[i] = ProvisionedNode(
                    nodeId = n.nodeId,
                    name = n.name,
                    unicastAddress = n.unicastAddress,
                    uuid = n.uuid,
                    elements = updatedElements,
                    provisioned = n.provisioned
                )
            }
        }
        return changed
    }

    fun bindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean {
        return updateModel(elementAddress, modelId) { m ->
            val set = (m.boundAppKeyIndexes ?: emptyList()).toMutableSet()
            set.add(appKeyIndex)
            m.copy(boundAppKeyIndexes = set.toList(), publication = m.publication)
        }
    }

    fun unbindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean {
        return updateModel(elementAddress, modelId) { m ->
            val set = (m.boundAppKeyIndexes ?: emptyList()).toMutableSet()
            set.remove(appKeyIndex)
            m.copy(boundAppKeyIndexes = set.toList(), publication = m.publication)
        }
    }

    fun addSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean {
        return updateModel(elementAddress, modelId) { m ->
            val set = (m.subscriptions ?: emptyList()).toMutableSet()
            set.add(address)
            m.copy(subscriptions = set.toList(), publication = m.publication)
        }
    }

    fun removeSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean {
        return updateModel(elementAddress, modelId) { m ->
            val set = (m.subscriptions ?: emptyList()).toMutableSet()
            set.remove(address)
            m.copy(subscriptions = set.toList(), publication = m.publication)
        }
    }

    fun setPublication(
        elementAddress: Long,
        modelId: Long,
        publishAddress: Long,
        appKeyIndex: Long,
        ttl: Long?
    ): Boolean {
        return updateModel(elementAddress, modelId) { m ->
            m.copy(
                publication = Publication(
                    address = publishAddress,
                    appKeyIndex = appKeyIndex,
                    ttl = ttl
                )
            )
        }
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
