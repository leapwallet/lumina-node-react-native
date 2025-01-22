import { Text, View, StyleSheet, Pressable } from 'react-native';
import { isRunning, stop, eventEmitter, start } from 'lumina-node-react-native';
import { useEffect, useState } from 'react';
import SquareVisualization from './Square-Viz';

const LIGHT_NODE_SYNCING_WINDOW_SECS = 2 * 24 * 60 * 60;

function NodeEvents({ nodeRunning }: { nodeRunning?: boolean }) {
  const [visualData, setVisualData] = useState<any>();

  useEffect(() => {
    console.log('running', nodeRunning);
    if (nodeRunning) {
      const handleLuminaNodeEvent = (event: any) => {
        console.log('logging event', event);
        if (event.type === 'samplingStarted') {
          if (visualData?.height !== event.height) {
            setVisualData(event);
          }
        }
      };

      eventEmitter.addListener('luminaNodeEvent', handleLuminaNodeEvent);
    }
    return () => {
      if (nodeRunning) {
        eventEmitter.removeAllListeners('luminaNodeEvent');
      }
    };
  }, [nodeRunning, visualData]);

  return <>{visualData ? <SquareVisualization events={visualData} /> : null}</>;
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
      console.log('toggle node', nodeRunning);
      if (nodeRunning) {
        console.log('stopping node');
        await stop();
        const _nodeRunning = await isRunning();
        console.log('logging is running 1', _nodeRunning);
        setNodeRunning(_nodeRunning);
      } else {
        console.log('starting node');
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
      console.log('stopping node');
      await stop();
      const _nodeRunning = await isRunning();
      console.log('logging is running', _nodeRunning);
      setNodeRunning(_nodeRunning);
    } catch (e) {
      console.log('logging e', e);
    }
  };

  const btn = () => {
    console.log('btn clicked');
  };

  console.log('app');

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
        <Pressable
          style={{ ...styles.btn, backgroundColor: 'blue' }}
          onPress={btn}
        >
          <Text>click me</Text>
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
