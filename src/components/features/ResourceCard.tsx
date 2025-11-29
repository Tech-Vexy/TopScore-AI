import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { Resource } from '../../types';
import { Card } from '../ui/Card';
import { DownloadButton } from './DownloadButton';

interface ResourceCardProps {
  resource: Resource;
  onPress: () => void;
}

export const ResourceCard: React.FC<ResourceCardProps> = ({ resource, onPress }) => {
  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.9}>
      <Card className="mb-4">
        <View className="flex-row justify-between items-start">
          <View className="flex-1 mr-4">
            <Text className="text-lg font-bold text-text mb-1">{resource.title}</Text>
            <Text className="text-sm text-textSecondary mb-2">
              {resource.subject} • Grade {resource.grade} • {resource.type.replace('_', ' ')}
            </Text>
            {resource.premium && (
              <View className="bg-secondary px-2 py-1 rounded self-start">
                <Text className="text-xs font-bold text-white">PREMIUM</Text>
              </View>
            )}
          </View>
          <DownloadButton resource={resource} />
        </View>
      </Card>
    </TouchableOpacity>
  );
};
