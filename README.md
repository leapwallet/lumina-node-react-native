# lumina-node-react-native

A React Native library that provides an interface to run and control a Lumina node from mobile apps. Use this package to start and stop a Lumina node, listen for node events, and check node status so you can integrate on-device blockchain syncing and events into your React Native application.

## Installation

```sh
npm install lumina-node-react-native
# or
yarn add lumina-node-react-native
```

## Usage

Start lumina node and listen to node events.

```typescript
import * as LuminClient from 'lumina-node-react-native';

const network = 'mainnet'
const syncingWindowSeconds = 2 * 24 * 3600 // 2 days
await LuminaClient.start(network, syncingWindowSeconds)


const eventListener = (event) => {
  // Handle node events 
}

LuminaClient.eventEmitter.addListener('LuminaNodeEvent', eventListener)

// Stop Node
await LuminaClient.stop()


// Check if node is running
const running = await LuminaClient.isRunning()


```

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
