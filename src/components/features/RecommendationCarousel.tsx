import React from 'react';
import { View, Text, ScrollView } from 'react-native';
import { Resource } from '../../types';
import { ResourceCard } from './ResourceCard';

interface RecommendationCarouselProps {
  recommendations: { resourceId: string; score: number; reason: string }[];
  resources: Resource[]; // In a real app, we'd fetch these by ID
  onPressResource: (resource: Resource) => void;
}

export const RecommendationCarousel: React.FC<RecommendationCarouselProps> = ({ 
  recommendations, 
  resources,
  onPressResource 
}) => {
  return (
    <View className="mb-6">
      <Text className="text-lg font-bold text-text mb-3 px-4">Recommended for You</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16 }}>
        {recommendations.map(rec => {
          const resource = resources.find(r => r.id === rec.resourceId);
          if (!resource) return null;
          
          return (
            <View key={rec.resourceId} className="w-72 mr-4">
              <View className="bg-yellow-50 px-2 py-1 rounded-t-lg self-start">
                <Text className="text-xs text-secondary font-bold">{rec.reason}</Text>
              </View>
              <ResourceCard resource={resource} onPress={() => onPressResource(resource)} />
            </View>
          );
        })}
      </ScrollView>
    </View>
  );
};
