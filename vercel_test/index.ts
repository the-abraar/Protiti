import 'dotenv/config';

async function main() {
  console.log("Sending smallest possible test request to OpenRouter (using native fetch)...");
  
  try {
    // Testing with a FREE model (google/gemini-2.0-flash-lite-preview-02-05:free)
    // This model is guaranteed free on OpenRouter, costing you $0.00
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/the-abraar/DKC',
        'X-Title': 'Protiti DKC App',
      },
      body: JSON.stringify({
        model: 'google/gemini-2.5-flash',
        messages: [{ role: 'user', content: 'Say the word "test" and nothing else.' }],
        max_tokens: 5,
      })
    });

    const data = await response.json();
    
    if (data.error) {
      throw new Error(data.error.message);
    }
    
    console.log("\nSuccess! Here is the response:\n");
    console.log(data.choices[0].message.content);
    console.log("\nYour OpenRouter API Key is working perfectly, and it cost $0.00!");
  } catch (error) {
    console.error("\nError connecting to OpenRouter:", error);
  }
}

main().catch(console.error);
