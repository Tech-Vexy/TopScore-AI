import { Resource } from '../../types';

interface Recommendation {
  resourceId: string;
  score: number; // 0-100
  reason: string;
}

export const getRecommendations = async (
  grade: number,
  recentWeakTopics: string[],
  completedResourceIds: string[],
  allResources: Resource[]
): Promise<Recommendation[]> => {
  // Simple recommendation logic
  const recommendations: Recommendation[] = [];
  const hour = new Date().getHours();
  const isMorning = hour < 12;

  for (const resource of allResources) {
    if (resource.grade !== grade) continue;
    if (completedResourceIds.includes(resource.id)) continue;

    let score = 50;
    let reason = "Recommended for your grade";

    // Boost score if topic is weak
    // Assuming resource has a 'topic' field or we infer from title/subject
    // For simplicity, let's assume resource.subject matches weak topics
    if (recentWeakTopics.includes(resource.subject)) {
      score += 30;
      reason = `You struggled with ${resource.subject}`;
    }

    // Time of day adjustment
    if (isMorning && resource.type === 'notes') {
      score += 10;
      reason = "Good for morning study";
    } else if (!isMorning && resource.type === 'mock') {
      score += 10;
      reason = "Good for evening revision";
    }

    recommendations.push({ resourceId: resource.id, score, reason });
  }

  return recommendations.sort((a, b) => b.score - a.score).slice(0, 10);
};
