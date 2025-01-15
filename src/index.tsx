import LuminaNodeReactNative from './NativeLuminaNodeReactNative';

import { NativeEventEmitter, NativeModules } from 'react-native';

export const eventEmitter = new NativeEventEmitter(
  NativeModules.LuminaNodeReactNative
);

export function multiply(a: number, b: number): Promise<number> {
  return LuminaNodeReactNative.multiply(a, b);
}

export async function initializeNode(network: string) {
  return await LuminaNodeReactNative.initializeNode(network);
}

export async function isRunning() {
  return await LuminaNodeReactNative.isRunning();
}

export async function start() {
  return await LuminaNodeReactNative.start();
}

export async function stop() {
  return await LuminaNodeReactNative.stop();
}

export async function syncerInfo() {
  return await LuminaNodeReactNative.syncerInfo();
}
