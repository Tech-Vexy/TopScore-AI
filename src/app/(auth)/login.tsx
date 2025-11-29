import React from 'react';
import { View, Text, Image } from 'react-native';
import { Button } from '../../components/ui/Button';
import { router } from 'expo-router';
import { signInWithCredential, GoogleAuthProvider } from 'firebase/auth';
import { auth, getUserProfile } from '../../services/firebase/auth';

export default function LoginScreen() {
  const handleGoogleSignIn = async () => {
    // In a real app, we would use expo-auth-session or @react-native-google-signin/google-signin
    // For this demo, we'll simulate a successful login
    try {
      // Simulate auth state change
      // const userCredential = await signInWithCredential(auth, ...);
      
      // Check if user has a role
      // const profile = await getUserProfile(userCredential.user.uid);
      
      // Mocking navigation for now
      router.replace('/(onboarding)/role-select');
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <View className="flex-1 bg-background justify-center items-center p-6">
      <View className="items-center mb-12">
        <View className="w-24 h-24 bg-primary rounded-full mb-4 items-center justify-center">
          <Text className="text-white text-4xl font-bold">EP</Text>
        </View>
        <Text className="text-3xl font-bold text-primary mb-2">ElimuPamoja</Text>
        <Text className="text-textSecondary text-center">
          We support teachers. We empower parents. We help students succeed — together.
        </Text>
      </View>

      <Button 
        label="Sign in with Google" 
        onPress={handleGoogleSignIn}
        className="w-full mb-4"
      />
      
      <Text className="text-xs text-textSecondary text-center mt-4">
        By signing in, you agree to our Terms and Privacy Policy.
      </Text>
    </View>
  );
}
