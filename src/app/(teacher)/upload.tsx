import React from 'react';
import { View, Text, TextInput } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button } from '../../components/ui/Button';

export default function UploadScreen() {
  return (
    <SafeAreaView className="flex-1 bg-background p-4">
      <Text className="text-2xl font-bold text-primary mb-6">Upload Resource</Text>
      
      <View className="mb-4">
        <Text className="text-text font-medium mb-2">Title</Text>
        <TextInput className="bg-white border border-gray-300 rounded-lg p-3" placeholder="e.g. Algebra Worksheet 1" />
      </View>

      <View className="mb-4">
        <Text className="text-text font-medium mb-2">Subject</Text>
        <TextInput className="bg-white border border-gray-300 rounded-lg p-3" placeholder="e.g. Mathematics" />
      </View>

      <View className="mb-6">
        <Text className="text-text font-medium mb-2">File</Text>
        <View className="border-2 border-dashed border-gray-300 rounded-lg p-8 items-center justify-center bg-gray-50">
          <Text className="text-gray-400">Tap to select file</Text>
        </View>
      </View>

      <Button label="Upload Resource" onPress={() => console.log('Upload')} />
    </SafeAreaView>
  );
}
