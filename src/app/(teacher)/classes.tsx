import React from 'react';
import { View, Text, FlatList } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card } from '../../components/ui/Card';

export default function ClassesScreen() {
  const classes = [
    { id: '1', name: 'Grade 8 East', students: 45, subject: 'Mathematics' },
    { id: '2', name: 'Grade 7 West', students: 42, subject: 'Science' },
  ];

  return (
    <SafeAreaView className="flex-1 bg-background p-4">
      <Text className="text-2xl font-bold text-primary mb-6">My Classes</Text>
      <FlatList
        data={classes}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <Card className="mb-4 p-4">
            <View className="flex-row justify-between items-center">
              <View>
                <Text className="text-lg font-bold text-text">{item.name}</Text>
                <Text className="text-textSecondary">{item.subject}</Text>
              </View>
              <View className="bg-gray-100 px-3 py-1 rounded-full">
                <Text className="text-xs font-bold text-textSecondary">{item.students} Students</Text>
              </View>
            </View>
          </Card>
        )}
      />
    </SafeAreaView>
  );
}
