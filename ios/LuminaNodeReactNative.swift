//
//  LuminaNode.swift
//  lumina-node-react-native
//
//  Created by Mayank Yadav on 07/01/25.
//

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


@objc(LuminaNodeReactNative)
class LuminaNodeReactNative: RCTEventEmitter {
  private var node: LuminaNode?
  private var hasListeners = false
  private var initialized = false
  
  override static func moduleName() -> String {
    return "LuminaNodeReactNative"
  }
  
  override func supportedEvents() -> [String] {
    return ["luminaNodeEvent"]
  }
  
  @objc(multiply:withB:resolver:rejecter:)
  func multiply(_ a: Int, b: Int, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let result = a * b
    resolve(result)
  }
  
  @objc(initializeNode:resolver:rejecter:)
  func initializeNode(network: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
      Task {
          do {

            if(initialized == true){
              resolve(true)
            }else{
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              let basePath = documentsPath.appendingPathComponent("lumina").path
              
              print("Base path: \(basePath)")
              
              try FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
              print("Directory created successfully at: \(basePath)")
                let config = NodeConfig(
                    basePath: basePath,
                    network: .mainnet, // Or whatever network you want
                    bootnodes: nil,    // Use default bootnodes
                    syncingWindowSecs: nil, // Use default
                    pruningDelaySecs: nil,  // Use default
                    batchSize: nil,         // Use default
                    ed25519SecretKeyBytes: nil // Generate new keypair
                )
              
              print("Node config initialized successfully")
                
              self.node = try LuminaNode(config: config)
              print("LuminaNode initialized successfully")
                 
              try await self.node?.start()
              print("LuminaNode started successfully")
                 
              try await self.node?.waitConnected()
              print("LuminaNode connected successfully")
                 
              resolve(true)
              self.initialized = true
            }
          } catch {
            reject("ERROR", error.localizedDescription, error )
          }
      }
  }
  
  @objc(isRunning:rejecter:)
  func isRunning(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        let running = try await self.node?.isRunning()
        resolve(running);
      } catch {
        reject("ERROR", error.localizedDescription, error)
      }
    }
  }
  
  @objc(start:rejecter:)
  func start(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        let result = try await self.node?.start()
        try await self.node?.waitConnected()
        resolve("Node started")
      }catch{
        reject("ERROR", error.localizedDescription, error)
      }
    }
  }
  
  @objc(stop:rejecter:)
  func stop(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        try await self.node?.stop()
        resolve("Node stopped")
      }catch{
        reject("ERROR", error.localizedDescription, error)
      }
    }
  }
  
  @objc(syncerInfo:rejecter:)
  func syncerInfo(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
    Task {
      do {
        let info = try await self.node?.syncerInfo()
        let jsonData = try JSONSerialization.data(withJSONObject: info?.toDictionary(), options: .prettyPrinted)
        resolve(jsonData)
      }catch{
        reject("ERROR", error.localizedDescription, error)
      }
    }
  }
  
  override func startObserving() {
    hasListeners = true
    startEventLoop()
  }
  
  override func stopObserving(){
    hasListeners = false
  }
  
  private func startEventLoop(){
    Task {
      while hasListeners {
        guard let node = self.node else {
          self.sendEvent(withName: "luminaNodeEvent", body: [
            "type": "error",
            "error": "Node is not available"
          ] as [String: Any])
          hasListeners = false
          break;
        }
        do {
          let event = try await node.nextEvent()
          let eventDict: [String: Any] = {
            switch event {
            case .connectingToBootnodes:
              return ["type": "connectingToBootnodes"]
            case .peerConnected(let id, let trusted):
              return [
                "type": "peerConnected",
                "peerId": id.peerId,
                "trusted": trusted
              ]
            case .peerDisconnected(let id, let trusted):
              return [
                "type": "peerDisconnected",
                "peerId": id.peerId,
                "trusted": trusted
              ]
            case .samplingStarted(let height, let squareWidth, let shares):
              print("Sampling started \(height)")
              return [
                "type": "samplingStarted",
                "height": height,
                "squareWidth": squareWidth,
                "shares": shares.map {
                  [
                    "row": $0.row,
                    "column": $0.column
                  ]
                }
              ]
            case .samplingFinished(let height, let accepted, let took):
              return [
                "type": "samplingFinished",
                "height": height,
                "accepted": accepted,
                "took": took
              ]
            case .shareSamplingResult(let height, let squareWidth, let row, let column, let accepted):
              return [
                "type": "shareSamplingResult",
                "height": height,
                "squareWidth": squareWidth,
                "row": row,
                "column": column,
                "accepted": accepted
              ]
            case .prunedHeaders(let toHeight):
              return [
                "type": "prunedHeaders",
                "toHeight": toHeight
              ]
            case .fetchingHeadersStarted(let fromHeight, let toHeight):
              return [
                "type": "fetchingHeadHeaderStarted",
                "fromHeight": fromHeight,
                "toHeight": toHeight
              ]
            case .fetchingHeadHeaderFinished(let height, let tookMs):
              return [
                "type": "fetchingHeadHeaderStarted",
                "height": height,
                "tookMs": tookMs
              ]
            case .nodeStopped:
              return ["type": "nodeStopped"]
            default:
              return ["type": "unknown"]
            }
          }()
          self.sendEvent(withName: "luminaNodeEvent", body: eventDict)
        }catch {
          let errorDescription = error.localizedDescription
          self.sendEvent(withName: "luminaNodeEvent", body: [
            "type": "error",
            "error": error.localizedDescription
          ] as [String: Any])
          break;
        }
      }
    }
  }
  
  
}
