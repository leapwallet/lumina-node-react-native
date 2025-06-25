//
//  LuminaNode.swift
//  lumina-node-react-native
//
//  Created by Mayank Yadav on 07/01/25.
//
import UIKit
import React
import Foundation
import lumina_node_uniffiFFI


extension BlockRange {
  func toDictionary() -> [String: Any] {
    return [
      "start": self.start,
      "end": self.end
    ]
  }
}

extension SyncingInfo {
  func toDictionary() -> [String: Any] {
    return [
      "storedHeaders": self.storedHeaders.map { $0.toDictionary() },
      "subjectiveHead": self.subjectiveHead
    ]
    
  }
}

extension Array where Element == Coin {
  func toDictionary() -> [[String: Any]] {
    return self.map { coin in
      return [
        "denom": coin.denom,
        "amount": String(coin.amount)
      ]
    }
  }
}


extension Network {
  static func from(_ networkString: String?) -> Network? {
    guard let networkString = networkString?.lowercased() else {
      return nil
    }
    
    switch networkString {
    case "mainnet":
      return .mainnet
    case "arabica":
      return .arabica
    case "mocha":
      return .mocha
    default:
      return .custom(NetworkId(id: networkString))
    }
  }
}

enum PathError: Error {
  case applicationSupportUnavailable
  case directoryCreationFailed(error: Error)
  case resourceValueUpdateFailed(error: Error)
}

private actor ListenerState {
  var hasListeners = false
  func setHasListeners(_ value: Bool){
    hasListeners = value
  }
}

class JavaScriptDelegateSigner: UniffiSigner, @unchecked Sendable {
  private weak var eventEmitter: LuminaNodeReactNative?
  private var pendingSignRequests: [String: CheckedContinuation<UniffiSignature, Error>] = [:]
  private let requestQueue = DispatchQueue(label: "signature_requests", attributes: .concurrent)
  
  init(eventEmitter: LuminaNodeReactNative) {
    self.eventEmitter = eventEmitter
  }
  
  
  
  func sign(doc: SignDoc) async throws -> UniffiSignature {
    let requestId = UUID().uuidString
    
    return try await withCheckedThrowingContinuation { continuation in
      requestQueue.async(flags: .barrier) {
        self.pendingSignRequests[requestId] = continuation
      }
      
      let params: [String: Any] = [
        "requestId": requestId,
        "signDoc": self.serializeSignDoc(doc: doc)
      ]
      
      DispatchQueue.main.async {
        self.eventEmitter?.sendEvent(
          withName: "requestSignature",
          body: params
        )
      }
    }
  }
  
  func receiveSignature(requestId: String, signature: Data) {
    requestQueue.async(flags: .barrier) {
      if let continuation = self.pendingSignRequests.removeValue(forKey: requestId) {
        let uniffiSignature = UniffiSignature(bytes: signature)
        continuation.resume(returning: uniffiSignature)
      }
    }
  }
  
  private func serializeSignDoc(doc: SignDoc) -> String {
    let signDocDict: [String: Any] = [
      "bodyBytes": doc.bodyBytes.base64EncodedString(),
      "authInfoBytes": doc.authInfoBytes.base64EncodedString(),
      "chainId": doc.chainId,
      "accountNumber": String(doc.accountNumber)
    ]
    
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: signDocDict, options: [])
      return String(data: jsonData, encoding: .utf8) ?? "{}"
    } catch {
      print("Failed to serialize SignDoc: \(error)")
      return "{}"
    }
  }
}


@objc(LuminaNodeReactNative)
class LuminaNodeReactNative: RCTEventEmitter {
  private var node: LuminaNode?
  private var initialized = false
  private var paused = false
  private var initializing = false
  private var grpcClient: GrpcClient?
  private var txClient: TxClient?
  private lazy var jsSigner = JavaScriptDelegateSigner(eventEmitter: self)
  
  private var wasRunningBeforeBackground = false
  
  
  private var filterEventTypes = ["samplingStarted", "samplingFinished", "peerConnected", "connectingToBootnodes"]
  
  
  private static let maxSyncingWindow: Int = 30 * 24 * 60 * 60
  private let listenerState = ListenerState()
  
  
  private let nodeQueue = DispatchQueue(label: "com.lumina.nodeQueue", qos: .userInitiated)
  
  override static func moduleName() -> String {
    return "LuminaNodeReactNative"
  }
  
  override func supportedEvents() -> [String] {
    return ["luminaNodeEvent", "requestSignature"]
  }
  
  override init(){
    super.init()
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func cleanLockFiles() throws {
    let basePath = try getBasePath()
    let fileManager = FileManager.default
    
    let contents = try fileManager.contentsOfDirectory(atPath: basePath.path)
    for item in contents {
      if item.hasSuffix(".lock") {
        let lockPath = basePath.appendingPathComponent(item).path
        try fileManager.removeItem(atPath: lockPath)
        print("Removed lock file: \(lockPath)")
      }
    }
  }
  
  @objc private func applicationWillEnterForeground(_ notification: NSNotification){
    guard initialized && wasRunningBeforeBackground else { return }
    nodeQueue.async {
      Task {
        do {
          if let nodeIsRunning = await self.node?.isRunning(), !nodeIsRunning {
            
            try await self.node?.start()
            try await self.node?.waitConnected()
            print("Node restarted successfully in foreground \(self.paused)")
            
            await self.listenerState.setHasListeners(true)
            self.startEventLoop()
          }
          self.wasRunningBeforeBackground = false
        } catch {
          print("Error restarting node in foreground: \(error.localizedDescription)")
          self.wasRunningBeforeBackground = false
        }
      }
    }
  }
  
  @objc private func applicationDidEnterBackground(_ notification: Notification) {
    nodeQueue.async {
      Task {
        do {
          
          self.wasRunningBeforeBackground = await self.node?.isRunning() ?? false
          if self.wasRunningBeforeBackground {
            try await self.node?.stop()
            await self.listenerState.setHasListeners(false)
            print("Node stopped successfully in background")
          }
        } catch {
          print("Error stopping node in background: \(error.localizedDescription)")
        }
      }
    }
  }
  
  func convertTo30DayMaxUInt32(seconds input: Int) -> UInt32 {
    let clampedSeconds = max(0, min(input, Self.maxSyncingWindow))
    return UInt32(clampedSeconds)
  }
  
  func getBasePath() throws -> URL {
    
    guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw PathError.applicationSupportUnavailable
    }
    var basePath = appSupportURL.appendingPathComponent("lumina")
    
    do {
      try FileManager.default.createDirectory(atPath: basePath.path, withIntermediateDirectories: true)
    } catch {
      throw PathError.directoryCreationFailed(error: error)
    }
    
    
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    do {
      try basePath.setResourceValues(resourceValues)
    } catch {
      throw PathError.resourceValueUpdateFailed(error: error)
    }
    return basePath
  }
  
  @objc(initGrpcClient:resolver:rejecter:)
  func initGrpcClient(url: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        self.grpcClient = try await GrpcClient.create(url: url)
      } catch {
        reject("ERROR Creating Grpc Client", error.localizedDescription, error)
      }
    }
  }
  
  @objc(getBalances:resolver:rejecter:)
  func getBalances(address: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        let balances = try await self.grpcClient?.getAllBalances(address: parseBech32Address(bech32Address: address))
        
        let objectToSerialize = balances?.toDictionary()
        print("Address: \(address)")
        print("Object type: \(type(of: objectToSerialize))")
        print("Array (with default): \(objectToSerialize)")
        balances?.forEach { coin in
          print("denom \(coin.denom)")
          print("amount \(coin.amount)")
        }
        
        
        
        let dictionaries = balances?.toDictionary() ?? []
        let jsonData = try JSONSerialization.data(withJSONObject: dictionaries, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          print("json string", jsonString)
          resolve(jsonString)
        } else {
          reject("JSON_ERROR", "Failed to convert JSON data to string", nil)
        }
      }catch {
        reject("ERROR Fetching balances", error.localizedDescription, error)
      }
    }
  }
  
  @objc(getSpendableBalances:resolver:rejecter:)
  func getSpendableBalances(address: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        let balances = try await self.grpcClient?.getSpendableBalances(address: parseBech32Address(bech32Address: address))
        
        let objectToSerialize = balances?.toDictionary()
        print("Spendabled Balances: Address: \(address)")
        print("Spendabled Balances: Object type: \(type(of: objectToSerialize))")
        print("Spendabled Balances: Array (with default): \(objectToSerialize)")
        balances?.forEach { coin in
          print("Spendabled Balances: denom \(coin.denom)")
          print("Spendabled Balances: amount \(coin.amount)")
        }
        
        
        
        let dictionaries = balances?.toDictionary() ?? []
        let jsonData = try JSONSerialization.data(withJSONObject: dictionaries, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          print("Spendabled Balances: json string", jsonString)
          resolve(jsonString)
        } else {
          reject("JSON_ERROR", "Failed to convert JSON data to string", nil)
        }
      }catch {
        reject("ERROR Fetching balances", error.localizedDescription, error)
      }
    }
  }
  
  @objc(initTxClient:address:publicKey:resolver:rejecter:)
  func initTxClient(
    url: String,
    address: String,
    publicKey: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let accountAddress: RustAddress = try parseBech32Address(bech32Address: address)
        
        guard let publicKeyData = Data(base64Encoded: publicKey) else {
          reject("INIT_TX_CLIENT_ERROR", "Invalid base64 public key", nil)
          return
        }
        
        let accountPubKey = publicKeyData
        
        print("Init client: \(url) \(address) \(publicKey)")
        
        txClient = try await TxClient.create(
          url: url,
          accountAddress: accountAddress,
          accountPubkey: accountPubKey,
          signer: jsSigner
        )
        
        resolve("client initialized")
      } catch {
        reject("INIT_TX_CLIENT_ERROR", error.localizedDescription, error)
      }
    }
  }
  
  @objc(submitMessage:resolver:rejecter:)
  func submitMessage(
    doc: NSDictionary,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        guard let type = doc["type"] as? String,
              let value = doc["value"] as? String,
              let gasLimit = doc["gasLimit"] as? String,
              let gasPrice = doc["gasPrice"] as? String,
              let memo = doc["memo"] as? String else {
                reject("SUBMIT_MESSAGE_ERROR", "Invalid message parameters", nil)
                return
              }
        
        guard let valueData = Data(base64Encoded: value) else {
          reject("SUBMIT_MESSAGE_ERROR", "Invalid base64 value", nil)
          return
        }
        
        
        let message = AnyMsg(type: type, value: valueData)
        
        guard let gasLimitUInt = UInt64(gasLimit),
              let gasPriceDouble = Double(gasPrice) else {
          reject("SUBMIT_MESSAGE_ERROR", "Invalid gas parameters", nil)
          return
        }
        
        let txConfig = TxConfig(gasLimit: gasLimitUInt, gasPrice: gasPriceDouble, memo: memo)
        
        print("Submitting message")
        
        guard let client = txClient else {
          reject("SUBMIT_MESSAGE_ERROR", "TxClient not initialized", nil)
          return
        }
        
        let txInfo = try await client.submitMessage(message: message, config: txConfig)
        
        print("txInfo: \(txInfo)")
        
        // Handle hash conversion based on UniffiHash type
        let hexString: String
        switch txInfo.hash {
        case .sha256(let hashBytes):
          hexString = hashBytes.map { String(format: "%02x", $0) }.joined()
        default:
          // Handle other hash types if needed
          hexString = ""
        }
        
        resolve(hexString)
      } catch {
        print("Transaction failed: \(error)")
        reject("SUBMIT_MESSAGE_ERROR", error.localizedDescription, error)
      }
    }
  }
  
  @objc(provideSignature:signatureHex:)
  func provideSignature(requestId: String, signatureHex: String) {
    guard let signatureData = Data(base64Encoded: signatureHex) else {
      print("Invalid base64 signature")
      return
    }
    
    jsSigner.receiveSignature(requestId: requestId, signature: signatureData)
  }
  
  @objc(start:syncingWindowSecs:resolver:rejecter:)
  func start(networkString: String, syncingWindowSecs: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    nodeQueue.async {
      Task {
        //        if(self.initializing) {
        //          return
        //        }
        do {
          if(self.initialized == true){
            let nodeIsRunning = await self.node?.isRunning()
            print("printing node is running \(String(describing: nodeIsRunning))")
            if(nodeIsRunning == false){
              try await self.node?.start()
              DispatchQueue.main.async {
                resolve(true)
              }
              return
            }else{
              DispatchQueue.main.async {
                resolve(true)
              }
              return
            }
          }else{
            self.initializing = true
            guard let network = Network.from(networkString) else {
              DispatchQueue.main.async {
                reject("ERROR", "Unable to get network for \(networkString)", nil)
              }
              return
            }
            
            do {
              try self.cleanLockFiles()
            } catch {
              DispatchQueue.main.async {
                reject("ERROR", "FAiled to clean lock file at path: \(error.localizedDescription)", error)
              }
            }
            let basePath: URL
            do {
              basePath = try self.getBasePath()
              print("self.initialized", self.initialized)
              
              
            } catch {
              DispatchQueue.main.async {
                reject("ERROR", "FAiled to get base apth: \(error.localizedDescription)", error)
              }
              return
            }
            
            
            
            let config = NodeConfig(
              basePath: basePath.path,
              network: network,
              bootnodes: nil,
              samplingWindowSecs: self.convertTo30DayMaxUInt32(seconds: syncingWindowSecs),
              pruningWindowSecs: 120,
              batchSize: nil,
              ed25519SecretKeyBytes: nil
            )
            
            do {
              self.node = try LuminaNode(config: config)
              print("LuminaNode initialized successfully")
              
              try await self.node?.start()
              print("LuminaNode started successfully")
              
              try await self.node?.waitConnected()
              print("LuminaNode connected successfully")
              self.initialized = true
              self.initializing = false
              
              DispatchQueue.main.async {
                resolve(true)
              }
            } catch {
              DispatchQueue.main.async {
                reject("ERROR", error.localizedDescription, error)
              }
            }
          }
        } catch {
          DispatchQueue.main.async {
            reject("ERROR", error.localizedDescription, error)
          }
        }
      }
    }
  }
  
  @objc(isRunning:rejecter:)
  func isRunning(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    nodeQueue.async {
      Task {
        let running = await self.node?.isRunning()
        DispatchQueue.main.async {
          resolve(running)
        }
      }
    }
  }
  
  @objc(stop:rejecter:)
  func stop(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    nodeQueue.async {
      Task {
        do {
          try await self.node?.stop()
          DispatchQueue.main.async {
            resolve("Node stopped")
          }
          
        }catch{
          DispatchQueue.main.async{
            reject("ERROR", error.localizedDescription, error)
          }
        }
      }
    }
  }
  
  @objc(syncerInfo:rejecter:)
  func syncerInfo(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    nodeQueue.async {
      Task {
        do {
          let info = try await self.node?.syncerInfo()
          let jsonData = try JSONSerialization.data(withJSONObject: info?.toDictionary(), options: .prettyPrinted)
          DispatchQueue.main.async {
            resolve(jsonData)
          }
          
        }catch{
          DispatchQueue.main.async {
            reject("ERROR", error.localizedDescription, error)
          }
        }
      }
    }
  }
  
  override func startObserving() {
    Task {
      await self.listenerState.setHasListeners(true)
    }
    startEventLoop()
  }
  
  override func stopObserving(){
    Task {
      await self.listenerState.setHasListeners(false)
    }
  }
  
  private func startEventLoop() {
    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self = self else {return}
      
      while await self.listenerState.hasListeners {
        guard let node = self.node else {
          await MainActor.run {
            self.sendEvent(withName: "luminaNodeEvent", body: [
              "type": "error",
              "error": "Node is not available"
            ] as [String: Any])
          }
          await self.listenerState.setHasListeners(false)
          break;
        }
        do {
          let event = try await node.nextEvent()
          let uuid = NSUUID().uuidString
          let eventDict: [String: Any] = {
            switch event {
            case .connectingToBootnodes:
              return ["id": uuid, "type": "connectingToBootnodes"]
            case .peerConnected(let id, let trusted):
              return [
                "id": uuid,
                "type": "peerConnected",
                "peerId": id.peerId,
                "trusted": trusted
              ]
            case .peerDisconnected(let id, let trusted):
              return [
                "id": uuid,
                "type": "peerDisconnected",
                "peerId": id.peerId,
                "trusted": trusted
              ]
            case .samplingStarted(let height, let squareWidth, let shares):
              print("Sampling started \(height)")
              return [
                "id": uuid,
                "type": "samplingStarted",
                "height": height,
              ]
            case .samplingResult(let height, let timedOut, let tookMs):
              return [
                "id": uuid,
                "type": "samplingFinished",
                "height": height,
                "tookMs": tookMs
              ]
            case .shareSamplingResult(let height, let squareWidth, let row, let column, let timedOut):
              return [
                "id": uuid,
                "type": "shareSamplingResult",
                "height": height,
                "squareWidth": squareWidth,
                "row": row,
                "column": column,
                "timedOut": timedOut
              ]
            case .prunedHeaders(let fromHeight, let toHeight):
              return [
                "id": uuid,
                "type": "prunedHeaders",
                "toHeight": toHeight
              ]
            case .fetchingHeadersStarted(let fromHeight, let toHeight):
              return [
                "id": uuid,
                "type": "fetchingHeadHeaderStarted",
                "fromHeight": fromHeight,
                "toHeight": toHeight
              ]
            case .fetchingHeadHeaderFinished(let height, let tookMs):
              return [
                "id": uuid,
                "type": "fetchingHeadHeaderStarted",
                "height": height,
                "tookMs": tookMs
              ]
            case .nodeStopped:
              return ["id": uuid, "type": "nodeStopped"]
            default:
              return ["id": uuid, "type": "unknown"]
            }
          }()
          
          print(eventDict)
          
          
          if(filterEventTypes.contains(eventDict["type"] as! String)){
            
            await MainActor.run {
              self.sendEvent(withName: "luminaNodeEvent", body: eventDict)
            }
            try await Task.sleep(nanoseconds: 5000_000_000)
          }
        }catch {
          let errorDescription = error.localizedDescription
          await MainActor.run {
            self.sendEvent(withName: "luminaNodeEvent", body: [
              "type": "error",
              "error": error.localizedDescription
            ] as [String: Any])
          }
          break;
        }
      }
    }
  }
}
