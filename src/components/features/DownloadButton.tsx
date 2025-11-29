import React, { useState, useEffect } from 'react';
import { TouchableOpacity, ActivityIndicator, Text, View } from 'react-native';
import { Resource } from '../../types';
import { downloadResource, listDownloads, deleteDownload } from '../../services/downloads/manager';
import { ProgressBar } from '../ui/ProgressBar';
import * as Haptics from 'expo-haptics';

interface DownloadButtonProps {
  resource: Resource;
}

export const DownloadButton: React.FC<DownloadButtonProps> = ({ resource }) => {
  const [status, setStatus] = useState<'idle' | 'downloading' | 'downloaded'>('idle');
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    checkStatus();
  }, []);

  const checkStatus = async () => {
    const downloads = await listDownloads();
    const isDownloaded = downloads.some(d => d.resourceId === resource.id);
    setStatus(isDownloaded ? 'downloaded' : 'idle');
  };

  const handleDownload = async () => {
    if (status === 'downloaded') {
      // Ideally show options to delete or open
      return; 
    }

    try {
      setStatus('downloading');
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      await downloadResource(resource, (p) => setProgress(p * 100));
      setStatus('downloaded');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (error) {
      console.error(error);
      setStatus('idle');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  };

  if (status === 'downloading') {
    return (
      <View className="w-12 items-center">
        <ActivityIndicator size="small" color="#006600" />
        <ProgressBar progress={progress} className="mt-1 h-1 w-full" />
      </View>
    );
  }

  return (
    <TouchableOpacity 
      onPress={handleDownload}
      className={`p-2 rounded-full ${status === 'downloaded' ? 'bg-green-100' : 'bg-gray-100'}`}
    >
      <Text className={`text-xs font-bold ${status === 'downloaded' ? 'text-success' : 'text-primary'}`}>
        {status === 'downloaded' ? '✓' : '↓'}
      </Text>
    </TouchableOpacity>
  );
};
