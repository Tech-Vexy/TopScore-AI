import React from 'react';
import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ProgressBar } from '../../components/ui/ProgressBar';
import { Card } from '../../components/ui/Card';

export default function ProgressScreen() {
  return (
    <SafeAreaView className="flex-1 bg-background">
      <ScrollView className="p-4">
        <Text className="text-2xl font-bold text-primary mb-6">My Progress</Text>

        <Card className="mb-6 p-6">
          <Text className="text-lg font-bold text-text mb-4">Overall Completion</Text>
          <View className="flex-row items-center mb-2">
            <Text className="text-3xl font-bold text-primary mr-2">65%</Text>
            <Text className="text-textSecondary">of Grade 8 syllabus</Text>
          </View>
          <ProgressBar progress={65} className="h-3" />
        </Card>

        <Text className="text-lg font-bold text-text mb-3">Subject Breakdown</Text>
        
        {[
          { subject: 'Mathematics', progress: 75, color: 'bg-blue-500' },
          { subject: 'English', progress: 80, color: 'bg-green-500' },
          { subject: 'Kiswahili', progress: 60, color: 'bg-yellow-500' },
          { subject: 'Science', progress: 45, color: 'bg-purple-500' },
          { subject: 'Social Studies', progress: 70, color: 'bg-orange-500' },
        ].map((item) => (
          <View key={item.subject} className="mb-4">
            <View className="flex-row justify-between mb-1">
              <Text className="font-medium text-text">{item.subject}</Text>
              <Text className="text-textSecondary">{item.progress}%</Text>
            </View>
            <ProgressBar progress={item.progress} color={item.color} />
          </View>
        ))}

        <Text className="text-lg font-bold text-text mb-3 mt-4">Weak Topics</Text>
        <View className="flex-row flex-wrap">
          {['Fractions', 'Photosynthesis', 'Map Reading'].map(topic => (
            <View key={topic} className="bg-red-50 px-3 py-2 rounded-full mr-2 mb-2 border border-red-100">
              <Text className="text-error text-sm font-medium">{topic}</Text>
            </View>
          ))}
        </View>

      </ScrollView>
    </SafeAreaView>
  );
}
