import { generateText } from 'ai';
import { createOpenAI } from '@ai-sdk/openai';
import 'dotenv/config';

// The copy-pasted snippet from Vercel used model: 'openai/gpt-5.5'
// With the AI SDK, we explicitly use the openai provider via the gateway.
const openai = createOpenAI({
  apiKey: process.env.AI_GATEWAY_API_KEY,
  // If you have a specific Vercel Gateway URL for OpenAI, it would go here.
});

async function main() {
  const { text } = await generateText({
    model: openai('gpt-5.5'),
    prompt: 'Invent a new holiday and describe its traditions.',
  });
  console.log(text);
}

main().catch(console.error);
