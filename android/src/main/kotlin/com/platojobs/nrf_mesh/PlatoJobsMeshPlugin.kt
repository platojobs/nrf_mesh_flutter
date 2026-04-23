package com.platojobs.nrf_mesh

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import no.nordicsemi.kotlin.ble.client.android.CentralManager
import no.nordicsemi.kotlin.ble.client.android.native
import no.nordicsemi.kotlin.ble.environment.android.NativeAndroidEnvironment
import no.nordicsemi.kotlin.mesh.bearer.MeshBearer
import no.nordicsemi.kotlin.mesh.bearer.gatt.GattBearerImpl
import no.nordicsemi.kotlin.mesh.core.MeshNetworkManager
import no.nordicsemi.kotlin.mesh.core.SecurePropertiesStorage
import no.nordicsemi.kotlin.mesh.core.Storage
import no.nordicsemi.kotlin.mesh.core.messages.MeshMessage as KmMeshMessage
import no.nordicsemi.kotlin.mesh.core.messages.foundation.configuration.ConfigModelAppBind
import no.nordicsemi.kotlin.mesh.core.messages.foundation.configuration.ConfigModelAppUnbind
import no.nordicsemi.kotlin.mesh.core.messages.foundation.configuration.ConfigModelPublicationSet
import no.nordicsemi.kotlin.mesh.core.messages.foundation.configuration.ConfigModelSubscriptionAdd
import no.nordicsemi.kotlin.mesh.core.messages.foundation.configuration.ConfigModelSubscriptionDelete
import no.nordicsemi.kotlin.mesh.core.model.IvIndex
import no.nordicsemi.kotlin.mesh.core.model.ApplicationKey
import no.nordicsemi.kotlin.mesh.core.model.MeshAddress
import no.nordicsemi.kotlin.mesh.core.model.Publish
import no.nordicsemi.kotlin.mesh.core.model.PublishPeriod
import no.nordicsemi.kotlin.mesh.core.model.Retransmit
import no.nordicsemi.kotlin.mesh.core.model.SigModelId
import no.nordicsemi.kotlin.mesh.core.model.UnicastAddress
import no.nordicsemi.kotlin.mesh.core.model.isValidKeyIndex
import kotlin.time.ExperimentalTime
import kotlin.time.Instant
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

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

    private var legacyManager: MeshManager? = null
    private var flutterApi: MeshFlutterApi? = null
    private var appContext: Context? = null
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var proxyConnected: Boolean = false
    private var kotlinMeshManager: MeshNetworkManager? = null
    private var secureStorage: PersistentSecurePropertiesStorage? = null
    private var bearer: MeshBearer? = null
    private var incomingMessagesJob: Job? = null
    private var rxSourceAddressSupported: Boolean = false
    private var experimentalRxMetadataEnabled: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        legacyManager = MeshManager()
        flutterApi = MeshFlutterApi(flutterPluginBinding.binaryMessenger)
        MeshApi.setUp(flutterPluginBinding.binaryMessenger, this)

        // Initialize Kotlin Mesh manager (storage + secure properties).
        val ctx = appContext!!
        val storage = object : Storage {
            override suspend fun load(): ByteArray {
                val f = File(ctx.filesDir, "kotlin_mesh_network.bin")
                return if (f.exists()) f.readBytes() else ByteArray(0)
            }

            override suspend fun save(network: ByteArray) {
                val f = File(ctx.filesDir, "kotlin_mesh_network.bin")
                f.parentFile?.mkdirs()
                f.writeBytes(network)
            }
        }
        val secureImpl = PersistentSecurePropertiesStorage(ctx)
        secureStorage = secureImpl
        val secure: SecurePropertiesStorage = secureImpl
        kotlinMeshManager = MeshNetworkManager(storage = storage, secureProperties = secure, ioDispatcher = Dispatchers.IO)

        // Forward incoming mesh messages to Flutter.
        incomingMessagesJob?.cancel()
        incomingMessagesJob = ioScope.launch {
            val km = kotlinMeshManager ?: return@launch

            // Default: use public API only. Experimental mode may extract source address via reflection.
            val receivedFlow: kotlinx.coroutines.flow.SharedFlow<Any>? =
                if (!experimentalRxMetadataEnabled) {
                    null
                } else {
                    try {
                        val getNm = km.javaClass.methods.firstOrNull { it.name == "getNetworkManager\$core" }
                        val nm = getNm?.invoke(km) ?: return@launch
                        @Suppress("UNCHECKED_CAST")
                        nm.javaClass.methods.firstOrNull { it.name == "getIncomingMeshMessages\$core" }
                            ?.invoke(nm) as? kotlinx.coroutines.flow.SharedFlow<Any>
                    } catch (_: Throwable) {
                        null
                    }
                }

            if (receivedFlow != null) {
                rxSourceAddressSupported = true
                receivedFlow.collect { received ->
                    try {
                        val addrObj = received.javaClass.methods.firstOrNull { it.name == "getAddress" }?.invoke(received)
                        val msgObj = received.javaClass.methods.firstOrNull { it.name == "getMessage" }?.invoke(received)
                        val src = try {
                            val m = addrObj?.javaClass?.methods?.firstOrNull { it.name.startsWith("getAddress") }
                            val v = m?.invoke(addrObj)
                            when (v) {
                                is Short -> v.toInt() and 0xFFFF
                                is Int -> v and 0xFFFF
                                else -> null
                            }
                        } catch (_: Throwable) { null }

                        val bytes = try {
                            val params = msgObj?.javaClass?.methods?.firstOrNull { it.name == "getParameters" }?.invoke(msgObj) as? ByteArray
                            (params ?: byteArrayOf()).map { (it.toInt() and 0xFF).toLong() }
                        } catch (_: Throwable) {
                            emptyList()
                        }

                        val op = (msgObj as? KmMeshMessage)?.opCode?.toLong() ?: 0L
                        flutterApi?.onMessageReceived(
                            MeshMessage(
                                opcode = op,
                                address = src?.toLong(),
                                appKeyIndex = null,
                                parameters = mapOf("bytes" to bytes),
                            )
                        ) {}

                        flutterApi?.onRxAccessMessage(
                            RxAccessMessage(
                                opcode = op,
                                parameters = bytes,
                                source = src?.toLong(),
                                destination = null,
                                metadataStatus = RxMetadataStatus.AVAILABLE,
                            )
                        ) {}
                    } catch (_: Throwable) {
                        // Ignore forwarding failures; do not crash the collector.
                    }
                }
            } else {
                rxSourceAddressSupported = false
                km.incomingMeshMessages.collect { msg ->
                    try {
                        val bytes = (msg.parameters ?: byteArrayOf()).map { (it.toInt() and 0xFF).toLong() }
                        val op = (msg as? KmMeshMessage)?.opCode?.toLong() ?: 0L
                        flutterApi?.onMessageReceived(
                            MeshMessage(
                                opcode = op,
                                address = null,
                                appKeyIndex = null,
                                parameters = mapOf("bytes" to bytes),
                            )
                        ) {}

                        flutterApi?.onRxAccessMessage(
                            RxAccessMessage(
                                opcode = op,
                                parameters = bytes,
                                source = null,
                                destination = null,
                                metadataStatus = RxMetadataStatus.UNAVAILABLE,
                            )
                        ) {}
                    } catch (_: Throwable) {
                        // ignore
                    }
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MeshApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        legacyManager = null
        incomingMessagesJob?.cancel()
        incomingMessagesJob = null
        kotlinMeshManager = null
        appContext = null
    }

    // MeshApi implementation (Pigeon)

    override fun createNetwork(name: String): MeshNetwork {
        legacyManager?.createNetwork(name)
        return legacyManager?.toMeshNetworkPigeon() ?: MeshNetwork(
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

    override fun loadNetwork(): MeshNetwork {
        val ctx = appContext
        if (ctx != null) {
            val loaded = legacyManager?.loadFromDefaultPath(ctx)
            if (loaded != null) return loaded
        }

        legacyManager?.createNetwork("default")
        return legacyManager?.toMeshNetworkPigeon() ?: MeshNetwork(
            networkId = "default",
            name = "default",
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

    override fun saveNetwork(): Boolean {
        val ctx = appContext ?: return false
        return legacyManager?.saveToDefaultPath(ctx) ?: false
    }

    override fun exportNetwork(path: String): Boolean {
        val ctx = appContext ?: return false
        return legacyManager?.exportToPath(ctx, path) ?: false
    }

    override fun importNetwork(path: String): Boolean {
        val ctx = appContext ?: return false
        // Try importing a standard Mesh DB (Configuration Database Profile 1.0.1) using Kotlin Mesh.
        val km = kotlinMeshManager
        if (km != null) {
            try {
                val f = File(path)
                val inp = if (f.isAbsolute) f else File(ctx.filesDir, path)
                if (inp.exists()) {
                    val bytes = inp.readBytes()
                    runBlocking { km.import(bytes) }
                    // Persist into Kotlin storage via manager.save().
                    runBlocking { km.save() }
                    return true
                }
            } catch (_: Throwable) {
                // Fall through to legacy JSON import.
            }
        }
        return legacyManager?.importFromPath(ctx, path) ?: false
    }

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
        flutterApi?.onProvisioningEvent(
            ProvisioningEvent(
                deviceId = device.deviceId,
                type = ProvisioningEventType.STARTED,
                message = "Provisioning started",
                progress = 0L,
                attentionTimer = null,
            )
        ) {}

        flutterApi?.onProvisioningEvent(
            ProvisioningEvent(
                deviceId = device.deviceId,
                type = ProvisioningEventType.CAPABILITIES_RECEIVED,
                message = "Capabilities received (best-effort)",
                progress = 5L,
                attentionTimer = null,
            )
        ) {}

        when (params.oobMethod?.toInt() ?: 0) {
            2 -> flutterApi?.onProvisioningEvent(
                ProvisioningEvent(
                    deviceId = device.deviceId,
                    type = ProvisioningEventType.OOB_INPUT_REQUESTED,
                    message = "Output OOB: please enter the value displayed on the device",
                    progress = 10L,
                    attentionTimer = null,
                )
            ) {}
            3 -> flutterApi?.onProvisioningEvent(
                ProvisioningEvent(
                    deviceId = device.deviceId,
                    type = ProvisioningEventType.OOB_OUTPUT_REQUESTED,
                    message = "Input OOB: provide a value to be entered on the device",
                    progress = 10L,
                    attentionTimer = null,
                )
            ) {}
            else -> {}
        }

        val out = legacyManager?.provision(device, params) ?: ProvisionedNode(
            nodeId = device.deviceId ?: "",
            name = params.deviceName,
            unicastAddress = 1L,
            uuid = device.uuid,
            elements = emptyList(),
            provisioned = true
        )
        flutterApi?.onProvisioningEvent(
            ProvisioningEvent(
                deviceId = device.deviceId,
                type = ProvisioningEventType.PROVISIONING_COMPLETED,
                message = "Provisioning completed",
                progress = 100L,
                attentionTimer = null,
            )
        ) {}
        return out
    }

    override fun sendMessage(message: MeshMessage) {
        val km = kotlinMeshManager
        if (!proxyConnected) {
            // Keep legacy behavior for UI/testing when not connected to a Proxy.
            return
        }
        requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
        require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
        val opcode = (message.opcode ?: 0L).toInt().toUInt()
        val dst = (message.address ?: 0L).toInt()
        val appKeyIndex = (message.appKeyIndex ?: 0L).toUShort()
        val bytesAny: Any? = message.parameters?.get("bytes")
        val bytes: ByteArray = (bytesAny as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?.map { it.and(0xFF).toByte() }
            ?.toByteArray()
            ?: byteArrayOf()

        runBlocking<Unit> {
            val net: no.nordicsemi.kotlin.mesh.core.model.MeshNetwork = km.meshNetwork.first()
            val appKey: ApplicationKey = requireNotNull(net.applicationKey(appKeyIndex)) {
                "AppKey not found for index $appKeyIndex"
            }
            km.send(
                message = RawAccessMessage(opCode = opcode, parameters = bytes),
                localElement = null,
                destination = MeshAddress.Companion.create(dst),
                initialTtl = null,
                applicationKey = appKey
            )
        }
    }

    override fun getNodes(): List<ProvisionedNode> = legacyManager?.getNodes() ?: emptyList()

    override fun removeNode(nodeId: String) {
        // no-op
    }

    override fun createGroup(name: String): MeshGroup {
        return legacyManager?.createGroup(name) ?: MeshGroup(
            groupId = java.util.UUID.randomUUID().toString(),
            name = name,
            address = 0xC000L,
            nodeIds = emptyList()
        )
    }

    override fun getGroups(): List<MeshGroup> = legacyManager?.getGroups() ?: emptyList()

    override fun addNodeToGroup(nodeId: String, groupId: String) {
        // no-op
    }

    // Configuration (P1 - minimal, in-memory)
    override fun bindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean =
        try {
            val km = kotlinMeshManager
            if (proxyConnected) {
                requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
                require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
                val keyIndex = appKeyIndex.toUShort()
                require(keyIndex.isValidKeyIndex()) { "Invalid AppKeyIndex" }
                runBlocking {
                    km.send(
                        message = ConfigModelAppBind(
                            keyIndex = keyIndex,
                            elementAddress = UnicastAddress(elementAddress.toUShort()),
                            modelId = SigModelId(modelIdentifier = modelId.toUShort())
                        ),
                        destination = elementAddress.toUShort(),
                        initialTtl = null
                    )
                    km.save()
                }
                true
            } else {
                legacyManager?.bindAppKey(elementAddress, modelId, appKeyIndex) ?: false
            }
        } catch (t: Throwable) {
            // If proxy is connected, the caller expects real config path. Surface the error.
            if (proxyConnected) throw t
            legacyManager?.bindAppKey(elementAddress, modelId, appKeyIndex) ?: false
        }

    override fun unbindAppKey(elementAddress: Long, modelId: Long, appKeyIndex: Long): Boolean =
        try {
            val km = kotlinMeshManager
            if (proxyConnected) {
                requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
                require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
                val keyIndex = appKeyIndex.toUShort()
                require(keyIndex.isValidKeyIndex()) { "Invalid AppKeyIndex" }
                runBlocking {
                    km.send(
                        message = ConfigModelAppUnbind(
                            keyIndex = keyIndex,
                            elementAddress = UnicastAddress(elementAddress.toUShort()),
                            modelId = SigModelId(modelIdentifier = modelId.toUShort())
                        ),
                        destination = elementAddress.toUShort(),
                        initialTtl = null
                    )
                    km.save()
                }
                true
            } else {
                legacyManager?.unbindAppKey(elementAddress, modelId, appKeyIndex) ?: false
            }
        } catch (t: Throwable) {
            if (proxyConnected) throw t
            legacyManager?.unbindAppKey(elementAddress, modelId, appKeyIndex) ?: false
        }

    override fun addSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean =
        try {
            val km = kotlinMeshManager
            if (proxyConnected) {
                requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
                require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
                runBlocking {
                    val sub = MeshAddress.create(address.toInt())
                    km.send(
                        message = ConfigModelSubscriptionAdd(
                            elementAddress = UnicastAddress(elementAddress.toUShort()),
                            address = sub.address,
                            modelIdentifier = modelId.toUShort(),
                            companyIdentifier = null
                        ),
                        destination = elementAddress.toUShort(),
                        initialTtl = null
                    )
                    km.save()
                }
                true
            } else {
                legacyManager?.addSubscription(elementAddress, modelId, address) ?: false
            }
        } catch (t: Throwable) {
            if (proxyConnected) throw t
            legacyManager?.addSubscription(elementAddress, modelId, address) ?: false
        }

    override fun removeSubscription(elementAddress: Long, modelId: Long, address: Long): Boolean =
        try {
            val km = kotlinMeshManager
            if (proxyConnected) {
                requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
                require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
                runBlocking {
                    val sub = MeshAddress.create(address.toInt())
                    km.send(
                        message = ConfigModelSubscriptionDelete(
                            elementAddress = UnicastAddress(elementAddress.toUShort()),
                            address = sub.address,
                            modelIdentifier = modelId.toUShort(),
                            companyIdentifier = null
                        ),
                        destination = elementAddress.toUShort(),
                        initialTtl = null
                    )
                    km.save()
                }
                true
            } else {
                legacyManager?.removeSubscription(elementAddress, modelId, address) ?: false
            }
        } catch (t: Throwable) {
            if (proxyConnected) throw t
            legacyManager?.removeSubscription(elementAddress, modelId, address) ?: false
        }

    override fun setPublication(
        elementAddress: Long,
        modelId: Long,
        publishAddress: Long,
        appKeyIndex: Long,
        ttl: Long?
    ): Boolean =
        try {
            val km = kotlinMeshManager
            if (proxyConnected) {
                requireNotNull(km) { "Kotlin Mesh manager is not initialized" }
                require(km.export() != null) { "Mesh DB is not loaded (importNetwork first)" }
                val keyIndex = appKeyIndex.toUShort()
                require(keyIndex.isValidKeyIndex()) { "Invalid AppKeyIndex" }
                runBlocking {
                    val pubAddr =
                        MeshAddress.create(publishAddress.toInt()) as no.nordicsemi.kotlin.mesh.core.model.PublicationAddress
                    val publish = Publish(
                        address = pubAddr,
                        index = keyIndex,
                        ttl = (ttl ?: 0L).coerceIn(0, 255).toUByte(),
                        period = PublishPeriod.disabled,
                        credentials = no.nordicsemi.kotlin.mesh.core.model.MasterSecurity,
                        retransmit = Retransmit.disabled
                    )
                    km.send(
                        message = ConfigModelPublicationSet(
                            companyIdentifier = null,
                            modelIdentifier = modelId.toUShort(),
                            elementAddress = UnicastAddress(elementAddress.toUShort()),
                            publish = publish
                        ),
                        destination = elementAddress.toUShort(),
                        initialTtl = null
                    )
                    km.save()
                }
                true
            } else {
                legacyManager?.setPublication(elementAddress, modelId, publishAddress, appKeyIndex, ttl) ?: false
            }
        } catch (t: Throwable) {
            if (proxyConnected) throw t
            legacyManager?.setPublication(elementAddress, modelId, publishAddress, appKeyIndex, ttl) ?: false
        }

    // Proxy connection (P1 real-transport prerequisite)
    override fun connectProxy(deviceId: String, proxyUnicastAddress: Long): Boolean {
        val ctx = appContext ?: return false
        val manager = kotlinMeshManager ?: return false

        return try {
            runBlocking {
                val env = NativeAndroidEnvironment.getInstance(
                    context = ctx,
                    isNeverForLocationFlagSet = true
                )
                val central = no.nordicsemi.kotlin.ble.client.android.CentralManager.Factory.native(
                    environment = env,
                    scope = ioScope
                )
                val peripheral = central.getPeripheralsById(listOf(deviceId)).first()
                val b = GattBearerImpl(
                    peripheral = peripheral,
                    centralManager = central,
                    ioDispatcher = Dispatchers.IO
                )
                bearer = b
                manager.meshBearer = b
                b.open()
                proxyConnected = true
            }
            true
        } catch (_: Throwable) {
            proxyConnected = false
            false
        }
    }

    override fun disconnectProxy(): Boolean {
        return try {
            runBlocking {
                bearer?.close()
            }
            bearer = null
            proxyConnected = false
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun isProxyConnected(): Boolean = proxyConnected

    override fun supportsRxSourceAddress(): Boolean = rxSourceAddressSupported

    override fun clearSecureStorage() {
        secureStorage?.clearAll()
    }

    override fun setExperimentalRxMetadataEnabled(enabled: Boolean) {
        experimentalRxMetadataEnabled = enabled
    }
}

private data class RawAccessMessage(
    override val opCode: UInt,
    override val parameters: ByteArray
) : KmMeshMessage {
}

/**
 * Persist secure mesh state (IV index, sequence numbers, SeqAuth values) so that
 * Access message sending remains stable across app restarts.
 */
@OptIn(ExperimentalUuidApi::class, ExperimentalTime::class)
private class PersistentSecurePropertiesStorage(
    context: Context,
) : SecurePropertiesStorage {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("nrf_mesh_flutter_secure", Context.MODE_PRIVATE)

    fun clearAll() {
        prefs.edit().clear().apply()
    }

    private fun key(prefix: String, networkUuid: Uuid): String = "$prefix:${networkUuid}"
    private fun key(prefix: String, networkUuid: Uuid, src: UnicastAddress): String =
        "$prefix:${networkUuid}:${src.address}"

    override suspend fun ivIndex(uuid: Uuid): IvIndex {
        val idx = prefs.getInt(key("ivIndex", uuid), 0)
        val active = prefs.getBoolean(key("ivUpdateActive", uuid), false)
        val transitionMs = prefs.getLong(key("ivTransitionMs", uuid), 0L)
        return IvIndex(
            idx.toUInt(),
            active,
            Instant.fromEpochMilliseconds(transitionMs),
        )
    }

    override suspend fun storeIvIndex(uuid: Uuid, ivIndex: IvIndex) {
        prefs.edit()
            .putInt(key("ivIndex", uuid), ivIndex.index.toInt())
            .putBoolean(key("ivUpdateActive", uuid), ivIndex.isIvUpdateActive)
            .putLong(
                key("ivTransitionMs", uuid),
                ivIndex.transitionDate.toEpochMilliseconds(),
            )
            .apply()
    }

    override suspend fun nextSequenceNumber(uuid: Uuid, address: UnicastAddress): UInt {
        val v = prefs.getLong(key("seq", uuid, address), 0L)
        return v.toUInt()
    }

    override suspend fun storeNextSequenceNumber(uuid: Uuid, address: UnicastAddress, sequenceNumber: UInt) {
        prefs.edit()
            .putLong(key("seq", uuid, address), sequenceNumber.toLong())
            .apply()
    }

    override suspend fun resetSequenceNumber(uuid: Uuid, address: UnicastAddress) {
        prefs.edit()
            .remove(key("seq", uuid, address))
            .apply()
    }

    override suspend fun lastSeqAuthValue(uuid: Uuid, source: UnicastAddress): ULong? {
        val k = key("lastSeqAuth", uuid, source)
        if (!prefs.contains(k)) return null
        return prefs.getLong(k, 0L).toULong()
    }

    override fun storeLastSeqAuthValue(uuid: Uuid, source: UnicastAddress, lastSeqAuth: ULong) {
        prefs.edit()
            .putLong(key("lastSeqAuth", uuid, source), lastSeqAuth.toLong())
            .apply()
    }

    override suspend fun previousSeqAuthValue(uuid: Uuid, source: UnicastAddress): ULong? {
        val k = key("prevSeqAuth", uuid, source)
        if (!prefs.contains(k)) return null
        return prefs.getLong(k, 0L).toULong()
    }

    override fun storePreviousSeqAuthValue(uuid: Uuid, source: UnicastAddress, seqAuth: ULong) {
        prefs.edit()
            .putLong(key("prevSeqAuth", uuid, source), seqAuth.toLong())
            .apply()
    }

    override suspend fun storeLocalProvisioner(uuid: Uuid, localProvisionerUuid: Uuid) {
        prefs.edit()
            .putString(key("localProvisioner", uuid), localProvisionerUuid.toString())
            .apply()
    }

    override suspend fun localProvisioner(uuid: Uuid): String? {
        return prefs.getString(key("localProvisioner", uuid), null)
    }
}

/**
 * Delegate interface for MeshManager events
 */
class MeshManager {
    private val nodes: MutableList<ProvisionedNode> = mutableListOf()
    private var nextUnicast: Long = 1L
    private var networkName: String = "default"
    private val groups: MutableList<MeshGroup> = mutableListOf()

    fun setNetworkName(name: String) { networkName = name }

    /**
     * Create a new mesh network
     */
    fun createNetwork(name: String) {
        networkName = name
        nodes.clear()
        groups.clear()
        nextUnicast = 1L
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

    fun createGroup(name: String): MeshGroup {
        val group = MeshGroup(
            groupId = java.util.UUID.randomUUID().toString(),
            name = name,
            address = 0xC000L,
            nodeIds = emptyList()
        )
        groups.add(group)
        return group
    }

    fun getGroups(): List<MeshGroup> = groups.toList()

    fun toMeshNetworkPigeon(): MeshNetwork {
        return MeshNetwork(
            networkId = networkName,
            name = networkName,
            networkKeys = emptyList(),
            appKeys = emptyList(),
            nodes = nodes.toList(),
            groups = groups.toList(),
            provisioner = Provisioner(
                name = "Provisioner",
                provisionerId = java.util.UUID.randomUUID().toString(),
                addressRange = listOf(1L, 0x0100L)
            )
        )
    }

    private fun defaultFile(ctx: Context): File = File(ctx.filesDir, "nrf_mesh_flutter_network.json")

    fun saveToDefaultPath(ctx: Context): Boolean {
        return exportToFile(defaultFile(ctx))
    }

    fun loadFromDefaultPath(ctx: Context): MeshNetwork? {
        val f = defaultFile(ctx)
        if (!f.exists()) return null
        return if (importFromFile(f)) toMeshNetworkPigeon() else null
    }

    fun exportToPath(ctx: Context, path: String): Boolean {
        // If path is relative, place under app files directory.
        val f = File(path)
        val out = if (f.isAbsolute) f else File(ctx.filesDir, path)
        return exportToFile(out)
    }

    fun importFromPath(ctx: Context, path: String): Boolean {
        val f = File(path)
        val inp = if (f.isAbsolute) f else File(ctx.filesDir, path)
        return importFromFile(inp)
    }

    private fun exportToFile(file: File): Boolean {
        return try {
            val root = JSONObject()
            root.put("name", networkName)
            root.put("nextUnicast", nextUnicast)

            val nodesArr = JSONArray()
            for (n in nodes) {
                nodesArr.put(nodeToJson(n))
            }
            root.put("nodes", nodesArr)

            val groupsArr = JSONArray()
            for (g in groups) {
                groupsArr.put(groupToJson(g))
            }
            root.put("groups", groupsArr)

            file.parentFile?.mkdirs()
            file.writeText(root.toString())
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun importFromFile(file: File): Boolean {
        return try {
            if (!file.exists()) return false
            val root = JSONObject(file.readText())
            networkName = root.optString("name", "default")
            nextUnicast = root.optLong("nextUnicast", 1L)
            nodes.clear()
            groups.clear()

            val nodesArr = root.optJSONArray("nodes") ?: JSONArray()
            for (i in 0 until nodesArr.length()) {
                val o = nodesArr.getJSONObject(i)
                nodes.add(nodeFromJson(o))
            }

            val groupsArr = root.optJSONArray("groups") ?: JSONArray()
            for (i in 0 until groupsArr.length()) {
                val o = groupsArr.getJSONObject(i)
                groups.add(groupFromJson(o))
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun nodeToJson(n: ProvisionedNode): JSONObject {
        val o = JSONObject()
        o.put("nodeId", n.nodeId)
        o.put("name", n.name)
        o.put("unicastAddress", n.unicastAddress)
        val uuidArr = JSONArray()
        for (b in (n.uuid ?: emptyList())) uuidArr.put(b)
        o.put("uuid", uuidArr)
        o.put("provisioned", n.provisioned)
        val elements = JSONArray()
        for (e in n.elements ?: emptyList()) {
            val eo = JSONObject()
            eo.put("address", e.address)
            val modelsArr = JSONArray()
            for (m in e.models ?: emptyList()) {
                val mo = JSONObject()
                mo.put("modelId", m.modelId)
                mo.put("modelName", m.modelName)
                mo.put("publishable", m.publishable)
                mo.put("subscribable", m.subscribable)
                val boundArr = JSONArray()
                for (v in (m.boundAppKeyIndexes ?: emptyList())) boundArr.put(v)
                mo.put("boundAppKeyIndexes", boundArr)
                val subsArr = JSONArray()
                for (v in (m.subscriptions ?: emptyList())) subsArr.put(v)
                mo.put("subscriptions", subsArr)
                val pub = m.publication
                if (pub != null) {
                    val po = JSONObject()
                    po.put("address", pub.address)
                    po.put("appKeyIndex", pub.appKeyIndex)
                    po.put("ttl", pub.ttl)
                    mo.put("publication", po)
                }
                modelsArr.put(mo)
            }
            eo.put("models", modelsArr)
            elements.put(eo)
        }
        o.put("elements", elements)
        return o
    }

    private fun nodeFromJson(o: JSONObject): ProvisionedNode {
        val elementsArr = o.optJSONArray("elements") ?: JSONArray()
        val elements = mutableListOf<Element>()
        for (i in 0 until elementsArr.length()) {
            val eo = elementsArr.getJSONObject(i)
            val modelsArr = eo.optJSONArray("models") ?: JSONArray()
            val models = mutableListOf<Model>()
            for (j in 0 until modelsArr.length()) {
                val mo = modelsArr.getJSONObject(j)
                val boundArr = mo.optJSONArray("boundAppKeyIndexes") ?: JSONArray()
                val subsArr = mo.optJSONArray("subscriptions") ?: JSONArray()
                val bound = (0 until boundArr.length()).map { boundArr.getLong(it) }
                val subs = (0 until subsArr.length()).map { subsArr.getLong(it) }
                val pubObj = mo.optJSONObject("publication")
                val pub = if (pubObj == null) null else Publication(
                    address = pubObj.optLong("address"),
                    appKeyIndex = pubObj.optLong("appKeyIndex"),
                    ttl = if (pubObj.has("ttl")) pubObj.optLong("ttl") else null
                )
                models.add(
                    Model(
                        modelId = mo.optLong("modelId"),
                        modelName = mo.optString("modelName"),
                        publishable = mo.optBoolean("publishable", true),
                        subscribable = mo.optBoolean("subscribable", true),
                        boundAppKeyIndexes = bound,
                        subscriptions = subs,
                        publication = pub
                    )
                )
            }
            elements.add(Element(address = eo.optLong("address"), models = models))
        }

        val uuidArr = o.optJSONArray("uuid") ?: JSONArray()
        val uuid = (0 until uuidArr.length()).map { uuidArr.getLong(it) }

        return ProvisionedNode(
            nodeId = o.optString("nodeId"),
            name = o.optString("name"),
            unicastAddress = o.optLong("unicastAddress"),
            uuid = uuid,
            elements = elements,
            provisioned = o.optBoolean("provisioned", true)
        )
    }

    private fun groupToJson(g: MeshGroup): JSONObject {
        val o = JSONObject()
        o.put("groupId", g.groupId)
        o.put("name", g.name)
        o.put("address", g.address)
        o.put("nodeIds", JSONArray(g.nodeIds ?: emptyList<String>()))
        return o
    }

    private fun groupFromJson(o: JSONObject): MeshGroup {
        val idsArr = o.optJSONArray("nodeIds") ?: JSONArray()
        val ids = (0 until idsArr.length()).map { idsArr.getString(it) }
        return MeshGroup(
            groupId = o.optString("groupId"),
            name = o.optString("name"),
            address = o.optLong("address"),
            nodeIds = ids
        )
    }

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

