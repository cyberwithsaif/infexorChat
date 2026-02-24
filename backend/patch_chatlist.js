const fs = require('fs');
const path = '/var/www/whatsapplikeapp/src/controllers/chatController.js';
let content = fs.readFileSync(path, 'utf8');

if (content.includes('// Auto-inject AI bot chat if missing')) {
    console.log('Already patched.');
    process.exit(0);
}

const findChatsStr = `    const chats = await Chat.find({
      participants: userId,
    })`;

const newLogic = `    // Auto-inject AI bot chat if missing
    if (env.ai && env.ai.enabled && env.ai.botUserId) {
      const botId = env.ai.botUserId;
      if (userId !== botId) {
        // Check if user has chat with bot
        const hasBotChat = await Chat.findOne({
          type: 'private',
          participants: { $all: [userId, botId], $size: 2 }
        });
        
        if (!hasBotChat) {
          // Create the chat
          const newChat = await Chat.create({
            type: 'private',
            participants: [userId, botId],
            createdBy: botId,
            lastMessageAt: new Date()
          });
          
          // Optionally send a welcome message from the bot
          try {
            const Message = require('../models/Message');
            const welcomeMsg = await Message.create({
              chatId: newChat._id,
              senderId: botId,
              type: 'text',
              content: 'Hi! I am InfexorChat AI 🤖 your friendly assistant. How can I help you today?',
              isAI: true,
              status: 'sent'
            });
            await Chat.findByIdAndUpdate(newChat._id, {
              lastMessage: welcomeMsg._id,
              lastMessageAt: welcomeMsg.createdAt
            });
          } catch (err) {
            console.error('[AI] Failed to send welcome message', err);
          }
        }
      }
    }

    let chats = await Chat.find({
      participants: userId,
    })`;

content = content.replace("const env = require('../config/env');", ""); // Prevent double import if exists
content = "const env = require('../config/env');\n" + content;

content = content.replace(findChatsStr, newLogic);
content = content.replace('const chats = await Chat.find', 'let chats = await Chat.find');

fs.writeFileSync(path, content);
console.log('Successfully patched chatController.js');
