import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import NetInfo, { NetInfoState } from '@react-native-community/netinfo';

export const OfflineIndicator: React.FC = () => {
  const [isConnected, setIsConnected] = useState<boolean | null>(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state: NetInfoState) => {
      setIsConnected(state.isConnected);
    });
    return () => unsubscribe();
  }, []);

  if (isConnected) return null;

  return (
    <View className="bg-gray-800 py-2 px-4 items-center justify-center">
      <Text className="text-white text-xs font-medium">
        You're offline — everything still works ✓
      </Text>
    </View>
  );
};
