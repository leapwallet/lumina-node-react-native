import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export type Balances = Array<{ denom: string; amount: string }>;

export interface Spec extends TurboModule {
  start(network: string, syncingWindowSecs: number): Promise<boolean>;
  isRunning(): Promise<boolean>;
  stop(): Promise<string>;
  syncerInfo(): Promise<string>;
  peerTrackerInfo(): Promise<string>;
  startEventLoop(): void;
  stopEventLoop(): void;
  initTxClient(url: string, address: string, publicKey: string): Promise<void>;
  initGrpcClient(url: string): Promise<void>;
  submitMessage(doc: {
    type: string;
    value: string;
    gasLimit: string;
    gasPrice: string;
  }): Promise<string>;
  provideSignature(requestId: string, signature: string): void;
  getBalances(address: string): Promise<string>;
  getSpendableBalances(address: string): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LuminaNodeReactNative');
