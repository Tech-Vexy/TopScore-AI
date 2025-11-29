import React, { useEffect, useState } from 'react';
import { View, Text, FlatList, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { listDownloads, deleteDownload, openDownload } from '../../services/downloads/manager';
import { LocalFile } from '../../types';
import { Card } from '../../components/ui/Card';
import { useFocusEffect } from 'expo-router';

export default function DownloadsScreen() {
  const [downloads, setDownloads] = useState<LocalFile[]>([]);

  const loadDownloads = async () => {
    const files = await listDownloads();
    setDownloads(files);
  };

  useFocusEffect(
    React.useCallback(() => {
      loadDownloads();
    }, [])
  );

  const handleDelete = async (id: string) => {
    await deleteDownload(id);
    loadDownloads();
  };

  const handleOpen = async (id: string) => {
    try {
      await openDownload(id);
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <SafeAreaView className="flex-1 bg-background p-4">
      <Text className="text-2xl font-bold text-primary mb-4">My Downloads</Text>
      
      {downloads.length === 0 ? (
        <View className="flex-1 justify-center items-center">
          <Text className="text-textSecondary text-lg">No downloads yet.</Text>
          <Text className="text-textSecondary text-sm mt-2">Save resources to view them offline.</Text>
        </View>
      ) : (
        <FlatList
          data={downloads}
          keyExtractor={item => item.id}
          renderItem={({ item }) => (
            <TouchableOpacity onPress={() => handleOpen(item.id)}>
              <Card className="mb-3 flex-row justify-between items-center">
                <View className="flex-1">
                  <Text className="font-bold text-text mb-1" numberOfLines={1}>{item.filename}</Text>
                  <Text className="text-xs text-textSecondary">
                    {new Date(item.downloadedAt).toLocaleDateString()}
                  </Text>
                </View>
                <TouchableOpacity 
                  onPress={() => handleDelete(item.id)}
                  className="p-2 bg-red-50 rounded-full ml-2"
                >
                  <Text className="text-error font-bold">✕</Text>
                </TouchableOpacity>
              </Card>
            </TouchableOpacity>
          )}
        />
      )}
    </SafeAreaView>
  );
}
