import { Text, View, StyleSheet, Pressable } from 'react-native';
import {
  initializeNode,
  isRunning,
  stop,
  eventEmitter,
} from 'lumina-node-react-native';
import { useEffect, useState } from 'react';
import SquareVisualization from './Square-Viz';
import { LogViewer } from './LogViewer';

export default function App() {
  const [nodeRunning, setNodeRunning] = useState<boolean>();
  const [visualData, setVisualData] = useState<any>();
  const [logs, setLogs] = useState<any>([]);
  useEffect(() => {
    async function fn() {
      const _isRunning = await isRunning();
      if (_isRunning) {
        setNodeRunning(true);
      }
    }

    fn();
  }, []);

  useEffect(() => {
    console.log('running', nodeRunning);
    if (nodeRunning) {
      const handleLuminaNodeEvent = (event: any) => {
        if (event.type !== 'unknown' && event.type !== 'samplingStarted') {
          const x = () => {
            setLogs((prevEvent: any) => {
              if (prevEvent?.length > 50) {
                return setLogs([event]);
              } else {
                return setLogs(prevEvent?.concat([event]) ?? []);
              }
            });
          };
          x();
        }
        if (event.type === 'samplingStarted') {
          if (visualData?.height !== event.height) {
            console.log('logging lumina event', event);
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

  return (
    <View style={styles.container}>
      <View style={styles.controlsContainer}>
        <Text>Node Status: {nodeRunning ? 'Running' : 'Stopped'}</Text>
        <Pressable
          style={{
            ...styles.btn,
            backgroundColor: nodeRunning ? 'red' : 'green',
          }}
          onPress={async () => {
            try {
              if (nodeRunning) {
                stop();
              } else {
                console.log('started');
                await initializeNode('mainnet');
                const _nodeRunning = await isRunning();
                setNodeRunning(_nodeRunning);
                console.log('start finished');
              }
            } catch (e) {
              console.log('logging e', e);
            }
          }}
        >
          <Text style={styles.btnText}>
            {nodeRunning ? 'Stop ' : 'Start '}Node
          </Text>
        </Pressable>
      </View>
      {logs?.length > 0 ? <LogViewer logs={logs} /> : null}
      {visualData ? <SquareVisualization events={visualData} /> : null}
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
