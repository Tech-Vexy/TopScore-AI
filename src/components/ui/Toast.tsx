import React, { useEffect, useState } from 'react';
import { View, Text, Animated } from 'react-native';
import { clsx } from 'clsx';

interface ToastProps {
  message: string;
  visible: boolean;
  type?: 'success' | 'error' | 'info';
  onHide: () => void;
}

export const Toast: React.FC<ToastProps> = ({ message, visible, type = 'info', onHide }) => {
  const [fadeAnim] = useState(new Animated.Value(0));

  useEffect(() => {
    if (visible) {
      Animated.sequence([
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.delay(2000),
        Animated.timing(fadeAnim, {
          toValue: 0,
          duration: 300,
          useNativeDriver: true,
        }),
      ]).start(() => onHide());
    }
  }, [visible]);

  if (!visible) return null;

  const bgColors = {
    success: 'bg-success',
    error: 'bg-error',
    info: 'bg-gray-800',
  };

  return (
    <Animated.View 
      style={{ opacity: fadeAnim }}
      className={clsx("absolute bottom-10 left-4 right-4 p-4 rounded-lg shadow-lg z-50", bgColors[type])}
    >
      <Text className="text-white text-center font-medium">{message}</Text>
    </Animated.View>
  );
};
