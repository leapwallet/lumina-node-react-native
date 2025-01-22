import LuminaNodeReactNative from './NativeLuminaNodeReactNative';

import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

type Network = 'mainnet' | 'arabica' | 'mocha';

export const eventEmitter = new NativeEventEmitter(
  NativeModules.LuminaNodeReactNative
);

export async function start(network: Network, syncingWindowSecs: number) {
  return await LuminaNodeReactNative.start(network, syncingWindowSecs);
}

export async function isRunning() {
  return await LuminaNodeReactNative.isRunning();
}

export async function stop() {
  return await LuminaNodeReactNative.stop();
}

export async function syncerInfo() {
  return await LuminaNodeReactNative.syncerInfo();
}

export async function startEventLoop() {
  if (Platform.OS === 'android') {
    return LuminaNodeReactNative.startEventLoop();
  }
}

export async function stopEventLoop() {
  if (Platform.OS === 'android') {
    return LuminaNodeReactNative.stopEventLoop();
  }
}
