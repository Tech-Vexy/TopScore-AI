import React, { useState, useRef } from 'react';
import { View, Text, TextInput, ScrollView, KeyboardAvoidingView, Platform } from 'react-native';
import { Button } from '../ui/Button';
import { chatWithTeacherJoy } from '../../services/ai/gemini';

interface Message {
  id: string;
  text: string;
  sender: 'user' | 'ai';
}

export const AITutorChat: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([
    { id: '1', text: "Jambo! I'm Teacher Joy. How can I help you learn today?", sender: 'ai' }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const scrollViewRef = useRef<ScrollView>(null);

  const handleSend = async () => {
    if (!input.trim()) return;

    const userMsg: Message = { id: Date.now().toString(), text: input, sender: 'user' };
    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setLoading(true);

    try {
      // Mock context for now
      const context = { grade: 8, subject: 'Science', topic: 'General' };
      const history = messages.map(m => ({
        role: m.sender === 'user' ? 'user' : 'model' as 'user' | 'model',
        parts: [{ text: m.text }]
      }));
      
      const responseText = await chatWithTeacherJoy(userMsg.text, context, history);
      const aiMsg: Message = { id: (Date.now() + 1).toString(), text: responseText, sender: 'ai' };
      setMessages(prev => [...prev, aiMsg]);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-background"
    >
      <ScrollView 
        ref={scrollViewRef}
        className="flex-1 p-4"
        onContentSizeChange={() => scrollViewRef.current?.scrollToEnd({ animated: true })}
      >
        {messages.map(msg => (
          <View 
            key={msg.id} 
            className={`mb-4 max-w-[80%] p-3 rounded-xl ${
              msg.sender === 'user' 
                ? 'bg-primary self-end rounded-tr-none' 
                : 'bg-white self-start rounded-tl-none border border-gray-200'
            }`}
          >
            <Text className={msg.sender === 'user' ? 'text-white' : 'text-text'}>
              {msg.text}
            </Text>
          </View>
        ))}
        {loading && (
          <View className="self-start bg-white p-3 rounded-xl rounded-tl-none border border-gray-200 mb-4">
            <Text className="text-textSecondary italic">Teacher Joy is typing...</Text>
          </View>
        )}
      </ScrollView>
      <View className="p-4 border-t border-gray-200 bg-white flex-row items-center">
        <TextInput
          className="flex-1 bg-gray-100 p-3 rounded-full mr-2 text-text"
          placeholder="Ask Teacher Joy..."
          value={input}
          onChangeText={setInput}
          onSubmitEditing={handleSend}
        />
        <Button label="Send" size="sm" onPress={handleSend} disabled={loading || !input.trim()} />
      </View>
    </KeyboardAvoidingView>
  );
};
