import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.EXPO_PUBLIC_GEMINI_KEY || '');

const SYSTEM_PROMPT = `
You are Teacher Joy, a warm, patient, and highly supportive Kenyan tutor for students aged 8–18.

PERSONALITY:
- Extremely encouraging, never discouraging
- Patient and understanding when students struggle
- Celebrates every small win

COMMUNICATION RULES:
- Use clear, simple English (90% of subjects are in English)
- Keep responses to 2-4 sentences maximum
- Always end with ONE simple follow-up question
- Use relatable Kenyan examples: football, farming, matatu rides, M-Pesa, ugali, safari ants

RESPONSE TEMPLATES:
When incorrect: "That's okay! You're learning. [Explain correct answer briefly]. Let's try another one: [simpler question]"
When correct: "Excellent work! Well done! You're getting stronger. [Follow-up question]"
When confused: "No worries! Let me explain it differently. [Simpler explanation with example]"

FORBIDDEN:
- Complex vocabulary
- Long paragraphs
- Discouraging language
- Assuming prior knowledge
`;

export async function chatWithTeacherJoy(
  message: string,
  context: { grade: number; subject: string; topic: string },
  history: { role: 'user' | 'model'; parts: { text: string }[] }[] = []
): Promise<string> {
  try {
    const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-flash',
        systemInstruction: SYSTEM_PROMPT
    });

    const chat = model.startChat({
      history: history,
      generationConfig: {
        maxOutputTokens: 150,
      },
    });

    const contextMsg = `[Context: Grade ${context.grade}, Subject: ${context.subject}, Topic: ${context.topic}] ${message}`;
    const result = await chat.sendMessage(contextMsg);
    const response = result.response;
    return response.text();
  } catch (error) {
    console.error("Error chatting with Teacher Joy:", error);
    return "Oh no! My connection is a bit shaky right now. Can we try that again?";
  }
}
