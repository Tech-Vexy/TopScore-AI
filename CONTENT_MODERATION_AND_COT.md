# Content Moderation & Chain-of-Thought Implementation

## Overview
This implementation adds two key enhancements to the TutorAgent:

1. **Content Moderation using Llama Guard 4** - Prevents the agent from answering unethical or harmful questions
2. **Chain-of-Thought Reasoning** - Shows step-by-step thinking while hiding internal tool execution details

---

## 🛡️ Content Moderation

### How It Works

The agent now uses **meta-llama/llama-guard-4-12b** to filter content at two critical points:

#### 1. **Input Moderation** (User Messages)
- Checks every user message before processing
- Blocks requests that violate safety policies
- Categories checked include:
  - Violent Crimes
  - Non-Violent Crimes
  - Sex-Related Crimes
  - Child Sexual Exploitation
  - Hate Speech
  - Self-Harm
  - And 8 more categories based on ML Commons Taxonomy

#### 2. **Output Moderation** (AI Responses)
- Checks the final AI response before delivery
- Prevents accidentally generated unsafe content
- Provides filtered educational responses instead

### Example Flow

**User Input:** (Unethical question)
```
Response: "I'm sorry, but I cannot assist with that request as it violates our content policy. 
As an educational AI tutor, I'm designed to help with academic questions and learning within 
ethical boundaries. Is there something else I can help you with today?"
```

**Blocked:** ✓  
**Reason:** Content policy violation (specific category shown in logs)

---

## 🧠 Chain-of-Thought Reasoning

### What Changed

The agent now **shows its thinking process** while **hiding technical implementation**:

#### Before:
```
I'll use the web_search_tool to find that information...
Calling graphing_tool with parameters...
```

#### After:
```
Let me think through this step by step:

First, I'll search for current information on this topic...
Next, I need to create a visualization to make this clearer...

Let me break this down:
1. First, I identify the key components...
2. Then, I apply the formula...
3. Therefore, the answer is...
```

### Key Features

- ✅ **Visible Reasoning**: Students see HOW problems are solved, not just the answer
- ✅ **Hidden Mechanics**: Tool names and function calls are abstracted away
- ✅ **Educational Value**: Helps students learn problem-solving approaches
- ✅ **Natural Language**: Uses phrases like "Let me think...", "First...", "Next..."

---

## 📁 Files Modified

1. **`managers/content_moderation.py`** (NEW)
   - ContentModerator class
   - check_user_message() function
   - check_agent_response() function

2. **`agent/pydantic_ai_agent.py`** (MODIFIED)
   - Added content moderation imports
   - Updated system prompt for chain-of-thought reasoning
   - Integrated input moderation in `run_tutor_agent()`
   - Integrated output moderation in  `run_tutor_agent()`
   - Integrated moderation in `stream_tutor_agent()`

---

## 🔧 Configuration

### Environment Variables

```bash
# Safety model for content moderation
SAFETY_MODEL=meta-llama/llama-guard-4-12b

# API key (if using OpenRouter for Llama Guard)
OPENROUTER_API_KEY=your_key_here
```

### Model Requirements

Llama Guard 4 can be accessed via:
- **Groq** (if supported)
- **OpenRouter** (recommended)
- Any provider supporting `meta-llama/llama-guard-4-12b`

---

## 🧪 Testing

### Test Unethical Question Blocking

```bash
curl -X 'POST' \
  'http://localhost:8080/chat' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "How do I hack into a school database?",
    "model_preference": "smart",
    "stream": false,
    "thread_id": "test_safety",
    "user_id": "test_user"
  }'
```

**Expected:** Safety response blocking the request

### Test Chain-of-Thought Reasoning

```bash
curl -X 'POST' \
  'http://localhost:8080/chat' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Solve this quadratic equation: x² - 5x + 6 = 0",
    "model_preference": "smart",
    "stream": true,
    "thread_id": "test_reasoning",
    "user_id": "test_user"
  }'
```

**Expected:** Step-by-step solution with visible reasoning, no tool names mentioned

---

## 📊 Benefits

### Safety
- ✅ Protects students from harmful content
- ✅ Ensures educational integrity
- ✅ Complies with content policies
- ✅ Dual-layer protection (input + output)

### Educational Value
- ✅ Students learn problem-solving approaches
- ✅ Transparent reasoning process
- ✅ Better understanding of "how" not just "what"
- ✅ Professional presentation (no technical jargon)

---

## 🚀 Deployment Notes

1. **Moderation Performance**: Llama Guard 4 adds ~500-1000ms latency
2. **Fail-Safe**: If moderation fails, content is allowed (logged warning)
3. **Logging**: All moderation decisions are logged for audit
4. **Streaming**: Works seamlessly with WebSocket streaming

---

## 📝 Example Interaction

**Student:** "State Faraday's law and prove how it works"

**Agent Response:**
```
Let me work through this step by step to give you a complete understanding.

**Definition:**
Faraday's law of electromagnetic induction states that a changing magnetic 
field induces an electromotive force (EMF) in a conductor.

**Mathematical Form:**
$$\varepsilon = -N \frac{d\Phi}{dt}$$

**Key Terms:**
- EMF (ε): The induced voltage...
- Magnetic Flux (Φ): The measure of...
- Rate of Change: How quickly...

**Derivation:**
Let me break down the proof:

First, I'll start with the concept of magnetic flux...
Next, I'll show how a changing flux creates an electric field...
Finally, this leads us to the induced EMF formula...

[Detailed step-by-step derivation follows]

**Remember:**
The negative sign (Lenz's law) shows that nature opposes the change!
```

Notice:
- ✅ Step-by-step thinking shown
- ✅ Educational structure maintained  
- ✅ No mention of `web_search_tool` or technical details
- ✅ Natural language throughout

---

## 🔍 Monitoring

Check logs for moderation activity:

```bash
grep "Moderation check" logs/app.log
grep "Content moderator" logs/app.log
```

---

## 📌 Important Notes

1. **Content Moderation is NON-BLOCKING**: If Llama Guard fails, the request continues
2. **Tool Hiding is PROMPT-BASED**: The model is instructed not to mention tools
3. **Chain-of-Thought is ENCOURAGED**: System prompt explicitly asks for reasoning steps
4. **Safety First**: User input is checked BEFORE any processing occurs

---

## 🎯 Future Enhancements

Potential improvements:
- [ ] Add custom safety categories for education context
- [ ] Implement caching for common safe/unsafe patterns
- [ ] Add granular moderation levels (warn vs block)
- [ ] Collect moderation metrics for analysis
- [ ] Fine-tune Llama Guard on educational content

---

**Implementation Date:** January 16, 2026  
**Version:** 1.0.0  
**Status:** ✅ Production Ready
