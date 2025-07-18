import { Text, View, StyleSheet, Pressable } from 'react-native';
//@ts-ignore
import {
  isRunning,
  stop,
  eventEmitter,
  start,
} from '@leapwallet/lumina-node-react-native';
import { useEffect, useState } from 'react';

const LIGHT_NODE_SYNCING_WINDOW_SECS = 2 * 24 * 60 * 60;

function NodeEvents({ nodeRunning }: { nodeRunning?: boolean }) {
  const [visualData, setVisualData] = useState<any>([]);

  useEffect(() => {
    if (nodeRunning) {
      const handleLuminaNodeEvent = (event: any) => {
        console;
        if (visualData?.height !== event.height) {
          if (event.type === 'samplingStarted') {
            console.log('logging event', event);
            setVisualData(event);
          }
        }
      };

      eventEmitter.addListener('luminaNodeEvent', handleLuminaNodeEvent);
    }
  }, [nodeRunning, visualData]);

  useEffect(() => {}, [nodeRunning, visualData]);
  //console.log('logging visual data', visualData)

  return null;
  //<SquareVisualization events={visualData} />
}

export default function App() {
  const [nodeRunning, setNodeRunning] = useState<boolean>();
  useEffect(() => {
    async function fn() {
      const _isRunning = await isRunning();
      if (_isRunning) {
        setNodeRunning(true);
      }
    }
    fn();
  }, []);

  const toggleNode = async () => {
    try {
      if (nodeRunning) {
        await stop();
        const _nodeRunning = await isRunning();
        setNodeRunning(_nodeRunning);
      } else {
        await start('mainnet', LIGHT_NODE_SYNCING_WINDOW_SECS);
        const _nodeRunning = await isRunning();
        setNodeRunning(_nodeRunning);
      }
    } catch (e) {
      console.log('logging e', e);
    }
  };

  const stopNode = async () => {
    try {
      await stop();
      const _nodeRunning = await isRunning();
      setNodeRunning(_nodeRunning);
    } catch (e) {
      console.log('logging e', e);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.controlsContainer}>
        <Text>Node Status: {nodeRunning ? 'Running' : 'Stopped'}</Text>
        <Pressable
          style={{
            ...styles.btn,
            backgroundColor: nodeRunning ? 'red' : 'green',
          }}
          onPress={toggleNode}
        >
          <Text style={styles.btnText}>
            {nodeRunning ? 'Stop ' : 'Start '}Node
          </Text>
        </Pressable>
        <Pressable
          style={{ ...styles.btn, backgroundColor: 'red' }}
          onPress={stopNode}
        >
          <Text>Stop Node</Text>
        </Pressable>
      </View>
      <NodeEvents nodeRunning={nodeRunning} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'black',
  },
  controlsContainer: {
    justifyContent: 'flex-start',
    marginBottom: 50,
    display: 'flex',
  },
  btn: {
    padding: 5,
    alignItems: 'center',
    borderRadius: 5,
  },
  btnText: {
    color: 'white',
  },
});
