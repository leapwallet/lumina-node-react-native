import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  start(network: string, syncingWindowSecs: number): Promise<boolean>;
  isRunning(): Promise<boolean>;
  stop(): Promise<string>;
  syncerInfo(): Promise<string>;
  peerTrackerInfo(): Promise<string>;
  startEventLoop(): void;
  stopEventLoop(): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LuminaNodeReactNative');
