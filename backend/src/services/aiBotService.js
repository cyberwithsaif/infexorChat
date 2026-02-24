const { Message, Chat, User } = require('../models');
const { getIO } = require('../config/socket');
const env = require('../config/env');
const logger = require('../utils/logger');
const axios = require('axios'); // Added for LLM API calls

// Rate-limit map per chat to prevent spam
const rateLimitMap = new Map();
const RATE_LIMIT_MS = 2000;

/**
 * Generates a smart reply based on the user's message.
 * Now supports advanced LLM responses via Gemini if an API key is configured.
 */
async function generateReply(message, senderName) {
    // 1. Advanced LLM Generation (if configured)
    if (env.ai.geminiKey && env.ai.geminiKey.trim().length > 0) {
        try {
            const prompt = `You are "AI BOT", the friendly, super-smart artificial intelligence assistant built directly into the InfexorChat app. 
The user's name is ${senderName}. 
They just said: "${message}"

Respond directly to the user in a helpful, friendly, and conversational way. Keep the answer reasonably concise and suitable for a mobile text messaging app. You can use emojis. Don't sound robotic, be friendly!`;

            const response = await axios.post(
                `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${env.ai.geminiKey}`,
                {
                    contents: [{ parts: [{ text: prompt }] }],
                    generationConfig: {
                        temperature: 0.7,
                        maxOutputTokens: 800,
                    }
                },
                { timeout: 8000 }
            );

            if (response.data && response.data.candidates && response.data.candidates.length > 0) {
                return response.data.candidates[0].content.parts[0].text.trim();
            }
        } catch (error) {
            logger.error(`[AI Bot] Gemini API error: ${error.message}. Falling back to rule-based engine.`);
        }
    }

    // 2. Fallback Rule-Based Engine
    const msg = message.toLowerCase().trim();

    // Greetings
    if (/^(hi|hello|hey|hola|sup|yo|hii+|heyy+)\b/.test(msg)) {
        const greetings = [
            `Hey ${senderName}! 👋 How can I help you today?`,
            `Hello ${senderName}! 😊 What's on your mind?`,
            `Hi there ${senderName}! 🌟 How are you doing?`,
            `Hey! 👋 Nice to hear from you, ${senderName}!`,
        ];
        return greetings[Math.floor(Math.random() * greetings.length)];
    }

    // How are you
    if (/how are you|how('re| are) (u|you)|what'?s up|sup\b/.test(msg)) {
        const responses = [
            `I'm doing great, thanks for asking! 😄 How about you?`,
            `All good here! ✨ What can I do for you?`,
            `I'm fantastic! 🚀 Ready to chat anytime!`,
        ];
        return responses[Math.floor(Math.random() * responses.length)];
    }

    // Thanks
    if (/thank|thanks|thx|ty\b/.test(msg)) {
        const responses = [
            `You're welcome! 😊 Happy to help!`,
            `Anytime! 🤗 Feel free to ask me anything.`,
            `No problem at all! ✨`,
        ];
        return responses[Math.floor(Math.random() * responses.length)];
    }

    // Help
    if (/help|assist|support/.test(msg)) {
        return `Sure, I'd love to help! 💡 Here's what I can do:\n\n` +
            `💬 Chat and keep you company\n` +
            `❓ Answer your questions\n` +
            `🎯 Share fun facts and tips\n` +
            `😄 Tell jokes to brighten your day\n\n` +
            `Just ask me anything!`;
    }

    // Jokes
    if (/joke|funny|laugh|humor/.test(msg)) {
        const jokes = [
            `Why do programmers prefer dark mode? Because light attracts bugs! 🐛😄`,
            `Why was the smartphone wearing glasses? Because it lost its contacts! 👓📱`,
            `What did the WiFi router say to the doctor? "I'm not feeling very connected today." 📡😂`,
            `Why do Java developers wear glasses? Because they don't C#! 🤓`,
            `What's a computer's favorite snack? Microchips! 🖥️🍪`,
        ];
        return jokes[Math.floor(Math.random() * jokes.length)];
    }

    // Who are you / about
    if (/who (are|r) (u|you)|your name|about you|what (are|r) (u|you)/.test(msg)) {
        return `I'm InfexorChat AI 🤖, your friendly chat assistant!\n\n` +
            `I'm built right into this app to help you out, share fun facts, tell jokes, ` +
            `and keep you company. Think of me as your always-available chat buddy! 😊✨`;
    }

    // Good morning/night
    if (/good morning|gm\b|morning/.test(msg)) {
        return `Good morning ${senderName}! ☀️ Hope you have an amazing day ahead! 🌟`;
    }
    if (/good night|gn\b|night|sleep/.test(msg)) {
        return `Good night ${senderName}! 🌙 Sweet dreams and rest well! 💤✨`;
    }

    // Bye
    if (/bye|goodbye|see you|later|gtg|gotta go/.test(msg)) {
        return `Bye ${senderName}! 👋 It was great chatting with you! Come back anytime! 😊`;
    }

    // Fun facts
    if (/fact|interesting|tell me something|did you know/.test(msg)) {
        const facts = [
            `Did you know? 🧠 Honey never spoils — archaeologists found 3,000-year-old honey in Egyptian tombs that was still edible!`,
            `Fun fact! 🌊 The ocean produces over 50% of the world's oxygen through phytoplankton. So the sea is literally keeping us alive!`,
            `Here's one! 🐙 Octopuses have three hearts, blue blood, and nine brains. Nature is wild!`,
            `Did you know? 🍌 Bananas are berries, but strawberries aren't. Botany is confusing! 😄`,
            `Cool fact! 🦈 Sharks have been around longer than trees. They've existed for over 400 million years!`,
        ];
        return facts[Math.floor(Math.random() * facts.length)];
    }

    // Weather (generic)
    if (/weather|rain|sunny|cold|hot|temperature/.test(msg)) {
        return `I wish I could check the weather for you! 🌤️ Unfortunately, I don't have access to real-time data yet. ` +
            `Try checking a weather app for the latest updates! ☂️`;
    }

    // Time
    if (/what time|time now|what'?s the time/.test(msg)) {
        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
        return `It's currently ${timeStr} (server time) ⏰`;
    }

    // Love/feelings
    if (/i love you|love u|love you|❤️|💕/.test(msg)) {
        return `Aww, that's so sweet! 🥰 I appreciate you too, ${senderName}! ❤️✨`;
    }

    // Default - contextual fallback
    const defaults = [
        `That's interesting, ${senderName}! 🤔 Tell me more about that!`,
        `Hmm, I see! 💭 What else is on your mind?`,
        `Cool! 😊 Is there anything specific I can help you with?`,
        `Got it! 👍 Feel free to ask me anything — jokes, facts, or just chat!`,
        `Interesting! 🌟 I'm always here if you want to chat about something.`,
        `I hear you, ${senderName}! 💬 What would you like to talk about?`,
    ];
    return defaults[Math.floor(Math.random() * defaults.length)];
}

/**
 * Handle AI auto-reply when a message is sent to a chat that includes the bot.
 * Called from socketHandler after a message is saved.
 */
async function handleAutoReply(chatId, senderId, messageContent) {
    if (!env.ai.enabled) return;
    if (!env.ai.botUserId) return;
    if (!messageContent || messageContent.trim().length === 0) return;

    // Don't reply to yourself (prevent loops)
    if (senderId === env.ai.botUserId) return;

    try {
        // Check if the bot is a participant in this chat
        const chat = await Chat.findById(chatId).lean();
        if (!chat) return;

        const botId = env.ai.botUserId;
        const isParticipant = chat.participants.some(
            p => p.toString() === botId
        );
        if (!isParticipant) return;

        // Rate limit per chat
        const now = Date.now();
        const lastReply = rateLimitMap.get(chatId);
        if (lastReply && (now - lastReply) < RATE_LIMIT_MS) return;
        rateLimitMap.set(chatId, now);

        // Get sender name for personalized replies
        let senderName = 'there';
        try {
            const sender = await User.findById(senderId).select('name').lean();
            if (sender && sender.name) {
                senderName = sender.name.split(' ')[0]; // First name only
            }
        } catch (_) { }

        // Generate the reply
        const replyText = await generateReply(messageContent, senderName);

        // Simulate typing delay
        const io = getIO();

        // Emit typing start
        chat.participants.forEach(pid => {
            const p = pid.toString();
            if (p !== botId) {
                io.to(`user:${p}`).emit('typing:start', { chatId, userId: botId });
            }
        });

        // Wait (simulates typing)
        const delay = Math.min(2000, Math.max(800, replyText.length * 8));
        await new Promise(resolve => setTimeout(resolve, delay));

        // Emit typing stop
        chat.participants.forEach(pid => {
            const p = pid.toString();
            if (p !== botId) {
                io.to(`user:${p}`).emit('typing:stop', { chatId, userId: botId });
            }
        });

        // Create the reply message
        const aiMessage = await Message.create({
            chatId,
            senderId: botId,
            type: 'text',
            content: replyText,
            isAI: true,
            status: 'sent',
        });

        // Update chat's lastMessage
        await Chat.findByIdAndUpdate(chatId, {
            lastMessage: aiMessage._id,
            lastMessageAt: aiMessage.createdAt,
        });

        // Populate and broadcast
        const populated = await Message.findById(aiMessage._id)
            .populate('senderId', 'name avatar')
            .lean();

        chat.participants.forEach(pid => {
            const p = pid.toString();
            if (p !== botId) {
                io.to(`user:${p}`).emit('message:new', populated);
            }
        });

        logger.info(`[AI Bot] Replied in chat ${chatId}: "${replyText.substring(0, 50)}..."`);
    } catch (err) {
        logger.error(`[AI Bot] Auto-reply error: ${err.message}`);
    }
}

// Cleanup stale rate-limit entries every 5 minutes
setInterval(() => {
    const now = Date.now();
    for (const [key, ts] of rateLimitMap.entries()) {
        if (now - ts > 60000) rateLimitMap.delete(key);
    }
}, 5 * 60 * 1000);

module.exports = { handleAutoReply };
