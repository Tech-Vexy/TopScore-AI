import React from 'react';
import { View } from 'react-native';
import { clsx } from 'clsx';

interface ProgressBarProps {
  progress: number; // 0 to 100
  color?: string;
  className?: string;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({ progress, color = 'bg-primary', className }) => {
  return (
    <View className={clsx("h-2 w-full bg-gray-200 rounded-full overflow-hidden", className)}>
      <View 
        className={clsx("h-full rounded-full", color)} 
        style={{ width: `${Math.max(0, Math.min(100, progress))}%` }} 
      />
    </View>
  );
};
