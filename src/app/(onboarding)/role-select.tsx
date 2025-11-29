import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { router } from 'expo-router';
import { Card } from '../../components/ui/Card';
import { createUserProfile, UserRole } from '../../services/firebase/auth';
import { auth } from '../../services/firebase/config';

export default function RoleSelectScreen() {
  const handleRoleSelect = async (role: UserRole) => {
    try {
      if (auth.currentUser) {
        await createUserProfile(auth.currentUser.uid, { role });
      }
      
      // Navigate based on role
      switch (role) {
        case 'student':
          router.replace('/(student)/home');
          break;
        case 'teacher':
          router.replace('/(teacher)/dashboard');
          break;
        case 'parent':
          router.replace('/(parent)/overview');
          break;
      }
    } catch (error) {
      console.error(error);
      // Fallback for demo if auth is not real
      switch (role) {
        case 'student':
          router.replace('/(student)/home');
          break;
        case 'teacher':
          router.replace('/(teacher)/dashboard');
          break;
        case 'parent':
          router.replace('/(parent)/overview');
          break;
      }
    }
  };

  const RoleCard = ({ role, title, description, icon }: { role: UserRole, title: string, description: string, icon: string }) => (
    <TouchableOpacity onPress={() => handleRoleSelect(role)} activeOpacity={0.9} className="mb-4 w-full">
      <Card className="flex-row items-center p-6">
        <View className="w-12 h-12 bg-green-100 rounded-full items-center justify-center mr-4">
          <Text className="text-2xl">{icon}</Text>
        </View>
        <View className="flex-1">
          <Text className="text-lg font-bold text-text mb-1">{title}</Text>
          <Text className="text-sm text-textSecondary">{description}</Text>
        </View>
      </Card>
    </TouchableOpacity>
  );

  return (
    <View className="flex-1 bg-background p-6 justify-center">
      <Text className="text-2xl font-bold text-primary mb-2 text-center">Welcome!</Text>
      <Text className="text-textSecondary text-center mb-8">Tell us who you are to get started.</Text>

      <RoleCard 
        role="student" 
        title="I am a Student" 
        description="Access notes, quizzes, and Teacher Joy." 
        icon="🎓" 
      />
      <RoleCard 
        role="teacher" 
        title="I am a Teacher" 
        description="Manage classes and upload resources." 
        icon="👨‍🏫" 
      />
      <RoleCard 
        role="parent" 
        title="I am a Parent" 
        description="Track progress and support your child." 
        icon="👨‍👩‍👧" 
      />
    </View>
  );
}
