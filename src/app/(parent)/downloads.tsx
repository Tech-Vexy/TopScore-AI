import React from 'react';
import { View, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button } from '../../components/ui/Button';

export default function ParentDownloadsScreen() {
  return (
    <SafeAreaView className="flex-1 bg-background p-4">
      <Text className="text-2xl font-bold text-primary mb-2">Bulk Downloads</Text>
      <Text className="text-textSecondary mb-6">Download entire grade packs for offline use.</Text>

      <View className="bg-white p-4 rounded-xl border border-gray-200 mb-4">
        <Text className="text-lg font-bold text-text mb-2">Grade 8 Full Pack</Text>
        <Text className="text-textSecondary mb-4">Includes all subjects: Math, English, Kiswahili, Science, Social Studies.</Text>
        <Text className="text-xs text-gray-500 mb-4">Size: ~450MB</Text>
        <Button label="Download Pack" onPress={() => console.log('Download Pack')} />
      </View>

      <View className="bg-white p-4 rounded-xl border border-gray-200 mb-4">
        <Text className="text-lg font-bold text-text mb-2">Grade 4 CBC Pack</Text>
        <Text className="text-textSecondary mb-4">Includes all learning areas and hygiene activities.</Text>
        <Text className="text-xs text-gray-500 mb-4">Size: ~300MB</Text>
        <Button label="Download Pack" onPress={() => console.log('Download Pack')} />
      </View>
    </SafeAreaView>
  );
}
