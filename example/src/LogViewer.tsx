import { useEffect, useRef } from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';

export const LogViewer = ({ logs }: any) => {
  const scrollViewRef = useRef<any>();

  useEffect(() => {
    scrollViewRef.current?.scrollToEnd({ animated: true });
  }, [logs]);
  return (
    <View style={styles.container}>
      <ScrollView ref={scrollViewRef} style={styles.logContainer}>
        {logs.map((log: any, index: any) => (
          <Text key={index} style={styles.logText}>
            {JSON.stringify(log)}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 2,
    backgroundColor: '#f5f5f5',
    maxHeight: 150,
    marginBottom: 100,
    alignSelf: 'stretch',
    paddingBottom: 20,
  },
  logContainer: {
    flex: 1,
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 8,
  },
  logText: {
    fontSize: 14,
    color: '#333',
    marginBottom: 4,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 16,
  },
});
