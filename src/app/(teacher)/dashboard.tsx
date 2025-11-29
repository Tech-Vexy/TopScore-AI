import React from 'react';
import { View, Text, ScrollView } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card } from '../../components/ui/Card';

export default function TeacherDashboard() {
  return (
    <SafeAreaView className="flex-1 bg-background">
      <ScrollView className="p-4">
        <Text className="text-2xl font-bold text-primary mb-6">Teacher Dashboard</Text>

        <View className="flex-row justify-between mb-6">
          <Card className="w-[48%] p-4 bg-blue-50 border border-blue-100">
            <Text className="text-3xl font-bold text-blue-700 mb-1">85%</Text>
            <Text className="text-sm text-blue-600">Class Attendance</Text>
          </Card>
          <Card className="w-[48%] p-4 bg-green-50 border border-green-100">
            <Text className="text-3xl font-bold text-green-700 mb-1">92%</Text>
            <Text className="text-sm text-green-600">Assignment Completion</Text>
          </Card>
        </View>

        <Text className="text-lg font-bold text-text mb-3">Struggling Students Alert</Text>
        <Card className="mb-4 border-l-4 border-l-error">
          <Text className="font-bold text-text">John Kamau (Grade 8)</Text>
          <Text className="text-textSecondary text-sm">Scored below 40% in last 3 Math quizzes.</Text>
        </Card>
        <Card className="mb-4 border-l-4 border-l-error">
          <Text className="font-bold text-text">Mary Wanjiku (Grade 7)</Text>
          <Text className="text-textSecondary text-sm">Has not logged in for 5 days.</Text>
        </Card>

      </ScrollView>
    </SafeAreaView>
  );
}
