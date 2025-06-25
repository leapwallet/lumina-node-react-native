import LuminaNodeReactNative, {
  type Balances,
} from './NativeLuminaNodeReactNative';

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

export async function getBalances(address: string): Promise<Balances> {
  const balances = await LuminaNodeReactNative.getBalances(address);
  return JSON.parse(balances);
}

export async function getSpendableBalances(address: string): Promise<Balances> {
  const balances = await LuminaNodeReactNative.getSpendableBalances(address);
  return JSON.parse(balances);
}

export async function initTxClient(
  url: string,
  address: string,
  publicKey: string
) {
  return LuminaNodeReactNative.initTxClient(url, address, publicKey);
}

export async function initGrpcClient(url: string) {
  return LuminaNodeReactNative.initGrpcClient(url);
}

type SigningFunction = (signDoc: any) => Promise<string>;

export const createTransactionSigner = (signingFunction: SigningFunction) => {
  let isInitialized = false;

  const initialize = () => {
    if (!isInitialized) {
      eventEmitter.addListener('requestSignature', async (event) => {
        const { requestId, signDoc } = event;

        try {
          const signature = await signingFunction(signDoc);
          LuminaNodeReactNative.provideSignature(requestId, signature);
        } catch (error) {
          console.error('Signing failed:', error);
        }
      });

      isInitialized = true;
    }
  };

  const submitTransaction = async (doc: {
    type: string;
    value: string;
    gasLimit: string;
    gasPrice: string;
    memo: string;
  }) => {
    if (!isInitialized) {
      initialize();
    }

    return await LuminaNodeReactNative.submitMessage(doc);
  };

  const cleanup = () => {
    if (isInitialized) {
      eventEmitter.removeAllListeners('requestSignature');
      isInitialized = false;
    }
  };

  return {
    submitTransaction,
    cleanup,
    initialize,
  };
};
