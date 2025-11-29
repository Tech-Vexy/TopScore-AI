import React from 'react';
import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ProgressBar } from '../../components/ui/ProgressBar';

export default function ChildProgressScreen() {
  return (
    <SafeAreaView className="flex-1 bg-background">
      <ScrollView className="p-4">
        <Text className="text-2xl font-bold text-primary mb-6">Brian's Progress</Text>

        <View className="mb-6">
          <Text className="text-lg font-bold text-text mb-2">Mathematics</Text>
          <ProgressBar progress={78} className="h-3 mb-1" />
          <Text className="text-right text-xs text-textSecondary">78% Complete</Text>
        </View>

        <View className="mb-6">
          <Text className="text-lg font-bold text-text mb-2">English</Text>
          <ProgressBar progress={92} className="h-3 mb-1" color="bg-blue-500" />
          <Text className="text-right text-xs text-textSecondary">92% Complete</Text>
        </View>

        <View className="mb-6">
          <Text className="text-lg font-bold text-text mb-2">Science</Text>
          <ProgressBar progress={65} className="h-3 mb-1" color="bg-yellow-500" />
          <Text className="text-right text-xs text-textSecondary">65% Complete</Text>
        </View>

      </ScrollView>
    </SafeAreaView>
  );
}
