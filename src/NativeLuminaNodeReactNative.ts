import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  multiply(a: number, b: number): Promise<number>;
  initializeNode(network: string): Promise<boolean>;
  isRunning(): Promise<boolean>;
  start(): Promise<string>;
  stop(): Promise<string>;
  syncerInfo(): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LuminaNodeReactNative');
