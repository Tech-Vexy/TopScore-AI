import React from 'react';
import { TouchableOpacity, Text, ActivityIndicator, TouchableOpacityProps } from 'react-native';
import { clsx } from 'clsx';

interface ButtonProps extends TouchableOpacityProps {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  label: string;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  loading = false,
  label,
  className,
  disabled,
  ...props
}) => {
  const baseStyles = "rounded-lg flex-row items-center justify-center";
  
  const variants = {
    primary: "bg-primary",
    secondary: "bg-secondary",
    outline: "border-2 border-primary bg-transparent",
    ghost: "bg-transparent",
  };

  const textVariants = {
    primary: "text-white font-bold",
    secondary: "text-text font-bold",
    outline: "text-primary font-bold",
    ghost: "text-primary font-bold",
  };

  const sizes = {
    sm: "px-3 py-2",
    md: "px-4 py-3",
    lg: "px-6 py-4",
  };

  return (
    <TouchableOpacity
      className={clsx(baseStyles, variants[variant], sizes[size], disabled && "opacity-50", className)}
      disabled={disabled || loading}
      activeOpacity={0.8}
      {...props}
    >
      {loading ? (
        <ActivityIndicator color={variant === 'outline' || variant === 'ghost' ? '#006600' : '#FFFFFF'} />
      ) : (
        <Text className={clsx(textVariants[variant], "text-center")}>{label}</Text>
      )}
    </TouchableOpacity>
  );
};
