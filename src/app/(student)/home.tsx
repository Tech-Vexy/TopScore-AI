import React from 'react';
import { View, Text, ScrollView, SafeAreaView } from 'react-native';
import { RecommendationCarousel } from '../../components/features/RecommendationCarousel';
import { Button } from '../../components/ui/Button';
import { router } from 'expo-router';
import { OfflineIndicator } from '../../components/features/OfflineIndicator';

export default function StudentHomeScreen() {
  // Mock data
  const recommendations = [
    { resourceId: '1', score: 90, reason: 'Your teacher assigned this' },
    { resourceId: '2', score: 80, reason: 'You struggled with Fractions' },
  ];

  const resources = [
    {
      id: '1',
      title: 'KCPE Math 2023 Past Paper',
      type: 'past_paper',
      subject: 'Mathematics',
      grade: 8,
      year: 2023,
      curriculum: 'KCPE',
      downloadUrl: 'https://example.com/math2023.pdf',
      fileSize: 1024 * 1024 * 2,
      premium: false,
    },
    {
      id: '2',
      title: 'Fractions & Decimals Notes',
      type: 'notes',
      subject: 'Mathematics',
      grade: 8,
      curriculum: 'KCPE',
      downloadUrl: 'https://example.com/fractions.pdf',
      fileSize: 1024 * 500,
      premium: false,
    },
  ] as any[];

  return (
    <SafeAreaView className="flex-1 bg-background">
      <OfflineIndicator />
      <ScrollView className="flex-1">
        <View className="p-6 pb-2">
          <Text className="text-textSecondary text-lg">Jambo,</Text>
          <Text className="text-3xl font-bold text-primary">Student!</Text>
        </View>

        <View className="px-6 mb-6">
          <View className="bg-green-50 p-4 rounded-xl flex-row justify-between items-center border border-green-100">
            <View>
              <Text className="text-primary font-bold text-lg">3 Day Streak! 🔥</Text>
              <Text className="text-textSecondary text-sm">Keep learning to unlock badges.</Text>
            </View>
          </View>
        </View>

        <RecommendationCarousel 
          recommendations={recommendations} 
          resources={resources}
          onPressResource={(r) => console.log('Open resource', r.id)}
        />

        <View className="px-6 mb-6">
          <Text className="text-lg font-bold text-text mb-3">Quick Actions</Text>
          <View className="flex-row flex-wrap justify-between">
            <Button 
              label="Ask Teacher Joy" 
              onPress={() => router.push('/(student)/tutor')}
              className="w-[48%] mb-4"
            />
            <Button 
              label="My Downloads" 
              variant="secondary"
              onPress={() => router.push('/(student)/downloads')}
              className="w-[48%] mb-4"
            />
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
