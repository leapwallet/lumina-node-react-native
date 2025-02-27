package com.luminanodereactnative

import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import uniffi.lumina_node.Network
import uniffi.lumina_node.NetworkId
import uniffi.lumina_node_uniffi.LuminaNode
import uniffi.lumina_node_uniffi.NodeConfig
import uniffi.lumina_node_uniffi.NodeEvent
import java.io.File
import java.util.UUID

@ReactModule(name = LuminaNodeReactNativeModule.NAME)
class LuminaNodeReactNativeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), LifecycleEventListener {

  var node: LuminaNode? = null;
  var isEventLoopRunning: Boolean = false
  var listenerCount: Int = 0
  private var isInitialized = false

  private val coroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
  private var wasRunningBeforeBackground = false
  private var eventLoopJob: Job? = null


  companion object {
    const val NAME = "LuminaNodeReactNative"
    private const val MAX_SYNC_WINDOW: Double = 30.0 * 24 * 60 * 60
    private val filterEventTypes: Array<String> = arrayOf(
      "samplingStarted",
      "samplingFinished",
      "peerConnected",
      "connectingToBootnodes"
    )
  }


  init {
    System.loadLibrary("lumina_node_uniffi")
    reactContext.addLifecycleEventListener(this)

  }

  override fun getName(): String {
    return NAME
  }

  fun convert30DayMaxUInt(input: Double): UInt {
    return input.coerceIn(0.0, MAX_SYNC_WINDOW).toUInt()
  }

  fun getNetwork(networkString: String): Network {
    return when(networkString.lowercase()){
      "mainnet" -> Network.Mainnet
      "arabica" -> Network.Arabica
      "mocha" -> Network.Mocha
      else -> Network.Custom(NetworkId(networkString))
    }
  }

  override fun onHostDestroy() {
    stopEventLoop()
    coroutineScope.cancel()
    reactApplicationContext.removeLifecycleEventListener(this)
  }

  override fun onHostPause() {
    coroutineScope.launch {
      try {
        wasRunningBeforeBackground = node?.isRunning() ?: false
        if (wasRunningBeforeBackground) {

          stopEventLoop()
          node?.stop()
          Log.d("Lumina node", "Node stopped successfully in background")
        }
      } catch (e: Exception) {
        Log.e("Lumina node", "Error stopping node in background: ${e.message}")
      }
    }
  }

  override fun onHostResume(){
    if (wasRunningBeforeBackground && isInitialized) {
      coroutineScope.launch {
        try {
          if (node?.isRunning() == false) {
            node?.start()
            node?.waitConnected()
            Log.d("Lumina node", "Node restarted successfully in foreground")
            startEventLoop()
            isEventLoopRunning = true
          }
          wasRunningBeforeBackground = false
        } catch (e: Exception) {
          Log.e("Lumina node", "Error restarting node in foreground: ${e.message}")
          wasRunningBeforeBackground = false
        }
      }
    }

  }

  @ReactMethod
  fun start(networkString: String, syncingWindowSecs: Double, promise: Promise?) {
    coroutineScope.launch {
      try {
        if(isInitialized){
          if(node?.isRunning() == false){
            Log.d("Lumina node", "starting node")
            node?.start()
            startEventLoop()
            promise?.resolve(true)
          }else{
            Log.d("Lumina node", "not starting node")
            promise?.resolve(true)
          }
        }else{
          Log.d("Lumina node", "starting node: init base path")
          val documentsPath = reactApplicationContext.filesDir
          val basePath = File(documentsPath, "lumina")

          if(!basePath.exists()){
            basePath.mkdirs()
          }
          Log.d("Lumina node", "starting node: init base path success")
          val network = getNetwork(networkString)
          val config = NodeConfig(
            basePath = basePath.path,
            network = network,
            bootnodes = null,
            syncingWindowSecs = convert30DayMaxUInt(syncingWindowSecs),
            pruningDelaySecs = 60.toUInt(),
            batchSize = 64UL,
            ed25519SecretKeyBytes = null
          )
          Log.d("Lumina node", "starting node: init node config success")


          node = LuminaNode(config = config)
          Log.d("Lumina node", "starting node: init node success")

          node?.start()
          Log.d("Lumina node", "starting node: init node start success")
          isInitialized = true

          startEventLoop()

          node?.waitConnected()
          Log.d("Lumina node", "starting node: init node connection acquired")

          promise?.resolve(true)
        }


      }catch(e: Exception){
        e.message?.let { Log.d("Lumina Node", it) };
        promise?.reject("Unable to start node")
      }
    }
  }

  @ReactMethod
  fun isRunning(promise: Promise?) {
    runBlocking {
      val running = node?.isRunning()
      promise?.resolve(running)
    }
  }

  @ReactMethod
  fun stop(promise: Promise?) {
    runBlocking {
      node?.stop()
      stopEventLoop()
      promise?.resolve("Node stopped")
    }
  }

  @ReactMethod
  fun syncerInfo(promise: Promise?) {
    runBlocking {
      val info = node?.syncerInfo()
      val json = Gson().toJson(info)
      promise?.resolve(json)
    }
  }

  fun peerTrackerInfo(promise: Promise?) {
    runBlocking {
      val info = node?.peerTrackerInfo()
      promise?.resolve(info?.numConnectedPeers)
    }
  }


  private fun sendEvent(
    reactContext: ReactContext,
    eventName: String,
    params: WritableMap
  ) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }




  @ReactMethod
  fun addListener(eventName: String) {
    listenerCount += 1;
    if(listenerCount == 1 && !isEventLoopRunning){
      Log.d("Lumina node", "starting event loop")
      startEventLoopIfNeeded()
      isEventLoopRunning = true
    }
  }


  @ReactMethod
  fun removeListeners(count: Int) {
    listenerCount -= 1
    if(listenerCount == 0 && isEventLoopRunning){
      stopEventLoop()
    }
  }

  private fun startEventLoopIfNeeded() {
    if (eventLoopJob == null) {
      eventLoopJob = coroutineScope.launch {
        while (listenerCount != 0) {
          val event = node?.nextEvent()
          if (event != null) {
            val eventData: MutableMap<String, Any> = when(event) {
              is NodeEvent.ConnectingToBootnodes -> mutableMapOf("type" to "connectingToBootnodes")

              is NodeEvent.AddedHeaderFromHeaderSub -> mutableMapOf(
                "type" to "addedHeaderFromHeaderSub",
                "height" to event.height
              )
              is NodeEvent.FatalDaserError -> mutableMapOf(
                "type" to "fatalDaserError",
                "error" to event.error
              )
              is NodeEvent.FatalPrunerError -> mutableMapOf(
                "type" to "fatalPrunerError",
                "error" to event.error
              )
              is NodeEvent.FatalSyncerError -> mutableMapOf(
                "type" to "fatalSyncerError",
                "error" to event.error
              )
              is NodeEvent.FetchingHeadHeaderFinished -> mutableMapOf(
                "type" to "fetchingHeadHeaderFinished",
                "height" to event.height,
                "tookMs" to event.tookMs
              )
              NodeEvent.FetchingHeadHeaderStarted -> mutableMapOf("type" to "fetchingHeadHeaderStarted")
              is NodeEvent.FetchingHeadersFailed -> mutableMapOf(
                "type" to "fetchingHeadersFailed",
                "fromHeight" to event.fromHeight,
                "toHeight" to event.toHeight,
                "error" to event.error,
                "tookMs" to event.tookMs
              )
              is NodeEvent.FetchingHeadersFinished -> mutableMapOf(
                "type" to "fetchingHeadersFinished",
                "fromHeight" to event.fromHeight,
                "toHeight" to event.toHeight,
                "tookMs" to event.tookMs
              )
              is NodeEvent.FetchingHeadersStarted -> mutableMapOf(
                "type" to "fetchingHeadersStarted",
                "fromHeight" to event.fromHeight,
                "toHeight" to event.toHeight
              )
              NodeEvent.NetworkCompromised -> mutableMapOf("type" to "networkCompromised")
              NodeEvent.NodeStopped -> mutableMapOf("type" to "nodeStopped")
              is NodeEvent.PeerConnected -> mutableMapOf(
                "type" to "peerConnected",
                "peerId" to event.id.peerId,
                "trusted" to event.trusted
              )
              is NodeEvent.PeerDisconnected -> mutableMapOf(
                "type" to "peerDisconnected",
                "peerId" to event.id.peerId,
                "trusted" to event.trusted
              )
              is NodeEvent.PrunedHeaders -> mutableMapOf(
                "type" to "prunedHeaders",
                "toHeight" to event.toHeight
              )
              is NodeEvent.SamplingFinished -> mutableMapOf(
                "type" to "samplingFinished",
                "height" to event.height,
                "accepted" to event.accepted
                "accepted" to event.accepted,
                "tookMs" to event.tookMs
              )
              is NodeEvent.SamplingStarted -> {
                Log.d("LuminaNode", "Sampling started $event.height")
                mutableMapOf(
                "type" to "samplingStarted",
                "height" to event.height,
//                "squareWidth" to event.squareWidth,
//                "shares" to event.shares.map {
//                  mapOf(
//                    "row" to it.row,
//                    "column" to it.column
//                  )
//                }
              )
              }
              is NodeEvent.ShareSamplingResult -> mutableMapOf(
                "type" to "shareSamplingResult",
                "height" to event.height,
//                "squareWidth" to event.squareWidth,
//                "row" to event.row,
//                "column" to event.column,
//                "accepted" to event.accepted
              )
            }
            eventData["id"] = UUID.randomUUID().toString()
            Log.d("Lumina node", "$eventData")
            if(filterEventTypes.contains(eventData["type"])){
              val dataMap = convertMapToWritableMap(eventData)
              sendEvent(reactContext = reactApplicationContext, "luminaNodeEvent", params = dataMap)
              delay(5000)
            }
          }
          delay(100)
        }
      }
    }
  }

  @ReactMethod
  fun startEventLoop(){
    listenerCount += 1
    if(listenerCount == 1 && !isEventLoopRunning){
      startEventLoopIfNeeded()
      isEventLoopRunning = true
    }
  }

  @ReactMethod
  fun stopEventLoop() {
    if(isEventLoopRunning){
      eventLoopJob?.cancel()
      eventLoopJob = null
      listenerCount = 0
      isEventLoopRunning = false
    }
  }

  override fun invalidate() {
    super.invalidate()
    stopEventLoop()
    coroutineScope.cancel()
  }

  private fun convertMapToWritableMap(map: Map<String, Any?>): WritableMap {
    val writableMap = Arguments.createMap()
    for ((key, value) in map) {
      when (value) {
        null -> writableMap.putNull(key)
        is String -> writableMap.putString(key, value)
        is Int -> writableMap.putInt(key, value)
        is Boolean -> writableMap.putBoolean(key, value)
        is Double -> writableMap.putDouble(key, value)
        is Float -> writableMap.putDouble(key, value.toDouble())
        is Long -> writableMap.putDouble(key, value.toDouble())
        is ULong -> writableMap.putDouble(key, value.toDouble())
        is UShort -> writableMap.putInt(key, value.toInt())
        is List<*> -> writableMap.putArray(key, convertListToWritableArray(value))
        is Map<*, *> -> writableMap.putMap(key, convertMapToWritableMap(value as Map<String, Any?>))
        else -> throw IllegalArgumentException("Unsupported type: ${value::class.java}")
      }
    }
    return writableMap
  }

  private fun convertListToWritableArray(list: List<*>): WritableArray {
    val writableArray = Arguments.createArray()
    for (item in list) {
      when (item) {
        null -> writableArray.pushNull()
        is String -> writableArray.pushString(item)
        is Int -> writableArray.pushInt(item)
        is Boolean -> writableArray.pushBoolean(item)
        is Double -> writableArray.pushDouble(item)
        is Float -> writableArray.pushDouble(item.toDouble())
        is Long -> writableArray.pushDouble(item.toDouble())
        is ULong -> writableArray.pushDouble(item.toDouble())
        is UShort -> writableArray.pushInt(item.toInt())
        is List<*> -> writableArray.pushArray(convertListToWritableArray(item))
        is Map<*, *> -> writableArray.pushMap(convertMapToWritableMap(item as Map<String, Any?>))
        else -> throw IllegalArgumentException("Unsupported type: ${item::class.java}")
      }
    }
    return writableArray
  }
}
