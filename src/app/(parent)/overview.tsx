import React from 'react';
import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';

export default function ParentOverview() {
  return (
    <SafeAreaView className="flex-1 bg-background">
      <ScrollView className="p-4">
        <Text className="text-2xl font-bold text-primary mb-6">Parent Overview</Text>

        <Text className="text-lg font-bold text-text mb-3">My Children</Text>
        
        <Card className="mb-4 p-4 border-l-4 border-l-primary">
          <View className="flex-row justify-between items-start mb-2">
            <View>
              <Text className="text-lg font-bold text-text">Brian Ochieng</Text>
              <Text className="text-textSecondary">Grade 8 • KCPE Candidate</Text>
            </View>
            <View className="bg-green-100 px-2 py-1 rounded">
              <Text className="text-xs font-bold text-success">Active</Text>
            </View>
          </View>
          <View className="flex-row mt-2">
            <View className="mr-6">
              <Text className="text-xs text-textSecondary">Weekly Avg</Text>
              <Text className="text-lg font-bold text-primary">78%</Text>
            </View>
            <View>
              <Text className="text-xs text-textSecondary">Resources</Text>
              <Text className="text-lg font-bold text-primary">12</Text>
            </View>
          </View>
        </Card>

        <Card className="mb-6 p-4 border-l-4 border-l-secondary">
          <View className="flex-row justify-between items-start mb-2">
            <View>
              <Text className="text-lg font-bold text-text">Grace Wanjiku</Text>
              <Text className="text-textSecondary">Grade 4 • CBC</Text>
            </View>
            <View className="bg-green-100 px-2 py-1 rounded">
              <Text className="text-xs font-bold text-success">Active</Text>
            </View>
          </View>
          <View className="flex-row mt-2">
            <View className="mr-6">
              <Text className="text-xs text-textSecondary">Weekly Avg</Text>
              <Text className="text-lg font-bold text-secondary">85%</Text>
            </View>
            <View>
              <Text className="text-xs text-textSecondary">Resources</Text>
              <Text className="text-lg font-bold text-secondary">8</Text>
            </View>
          </View>
        </Card>

        <Button label="Add Child" variant="outline" onPress={() => {}} />

      </ScrollView>
    </SafeAreaView>
  );
}
