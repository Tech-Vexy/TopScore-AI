import React from 'react';
import { View, ViewProps } from 'react-native';
import { clsx } from 'clsx';

interface CardProps extends ViewProps {
  variant?: 'elevated' | 'outlined' | 'flat';
}

export const Card: React.FC<CardProps> = ({ variant = 'elevated', className, children, ...props }) => {
  const baseStyles = "rounded-xl p-4 bg-surface";
  
  const variants = {
    elevated: "shadow-sm elevation-2",
    outlined: "border border-gray-200",
    flat: "",
  };

  return (
    <View className={clsx(baseStyles, variants[variant], className)} {...props}>
      {children}
    </View>
  );
};
