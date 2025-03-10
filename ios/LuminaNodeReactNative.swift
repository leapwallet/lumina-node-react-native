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


@objc(LuminaNodeReactNative)
class LuminaNodeReactNative: RCTEventEmitter {
  private var node: LuminaNode?
  private var initialized = false
  private var paused = false
  
  private var wasRunningBeforeBackground = false

  
  private var filterEventTypes = ["samplingStarted", "samplingFinished", "peerConnected", "connectingToBootnodes"]


  private static let maxSyncingWindow: Int = 30 * 24 * 60 * 60
  private let listenerState = ListenerState()
 
  
  private let nodeQueue = DispatchQueue(label: "com.lumina.nodeQueue", qos: .userInitiated)

  override static func moduleName() -> String {
    return "LuminaNodeReactNative"
  }
  
  override func supportedEvents() -> [String] {
    return ["luminaNodeEvent"]
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
  
  @objc(start:syncingWindowSecs:resolver:rejecter:)
  func start(networkString: String, syncingWindowSecs: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    nodeQueue.async {
      Task {
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
            guard let network = Network.from(networkString) else {
              DispatchQueue.main.async {
                reject("ERROR", "Unable to get network for \(networkString)", nil)
              }
              return
            }
            let basePath: URL
            do {
              basePath = try self.getBasePath()
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
              syncingWindowSecs: self.convertTo30DayMaxUInt32(seconds: syncingWindowSecs),
              pruningDelaySecs: 120,
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
  
  private func startEventLoop(){
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
//                "squareWidth": squareWidth,
//                "shares": shares.map {
//                  [
//                    "row": $0.row,
//                    "column": $0.column
//                  ]
//                }
              ]
            case .samplingFinished(let height, let accepted, let took):
              return [
                "id": uuid,
                "type": "samplingFinished",
                "height": height,
                "accepted": accepted,
                "tookMs": took
              ]
            case .shareSamplingResult(let height, let squareWidth, let row, let column, let accepted):
              return [
                "id": uuid,
                "type": "shareSamplingResult",
                "height": height,
                "squareWidth": squareWidth,
                "row": row,
                "column": column,
                "accepted": accepted
              ]
            case .prunedHeaders(let toHeight):
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
