import { View, StyleSheet, Dimensions, Text } from 'react-native';

type Share = { row: number; column: number };

type Prop = {
  events: {
    height: number;
    squareWidth: number;
    shares: Array<Share>;
  };
};

const SquareVisualization = ({ events }: Prop) => {
  const hdsSize = events ? events.squareWidth : 32;
  const shares = events ? events.shares : null;

  const isActive = (x: number, y: number) => {
    return shares?.some((coord) => coord.row === x && coord.column === y);
  };

  const renderGrid = (gridCount: number) => {
    const gridSize = Dimensions.get('window').width / gridCount; // Calculate cell size based on screen width
    const rows = [];
    for (let i = 0; i < gridCount; i++) {
      const cols = [];
      for (let j = 0; j < gridCount; j++) {
        const key = `${i}-${j}`;
        cols.push(
          <View
            key={key}
            style={[
              {
                width: gridSize,
                height: gridSize,
                backgroundColor: isActive(i, j) ? '#8F34FF' : '#E5E7EB', // Light gray for inactive, purple for active
              },
            ]}
          />
        );
      }
      rows.push(
        <View key={i} style={styles.row}>
          {cols}
        </View>
      );
    }
    return rows;
  };

  return (
    <View style={styles.container}>
      <Text style={styles.vizHeader}>
        Square Visualization for: {events.height}
      </Text>
      {renderGrid(hdsSize)}
    </View>
  );
};

// NOTE • Styles
const styles = StyleSheet.create({
  container: {
    width: '100%',
    height: 320, // Fixed height for the grid
    justifyContent: 'center',
    alignItems: 'center',
  },
  vizHeader: {
    color: 'white',
  },
  row: {
    flexDirection: 'row',
  },
});

export default SquareVisualization;
