import React from 'react';
import { SafeAreaView, View, Text } from 'react-native';
import { AITutorChat } from '../../components/features/AITutorChat';

export default function TutorScreen() {
  return (
    <SafeAreaView className="flex-1 bg-background">
      <View className="p-4 border-b border-gray-200 bg-white">
        <Text className="text-xl font-bold text-primary text-center">Teacher Joy 🤖</Text>
        <Text className="text-xs text-textSecondary text-center">Always here to help you learn.</Text>
      </View>
      <AITutorChat />
    </SafeAreaView>
  );
}
