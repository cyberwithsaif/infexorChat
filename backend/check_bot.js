require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    await mongoose.connect(env.mongodbUri);
    const User = require('./src/models/User');
    const Chat = require('./src/models/Chat');

    const botId = env.ai.botUserId;
    console.log('Bot User ID:', botId);

    const bot = await User.findById(botId).lean();
    if (bot) {
        console.log('Bot found:', bot.name, '|', bot.phone, '| avatar:', bot.avatar || 'none');
    } else {
        console.log('Bot user NOT found in DB!');
    }

    // Check chats that include the bot
    const chats = await Chat.find({ participants: botId }).populate('participants', 'name phone').lean();
    console.log('\nChats with bot:', chats.length);
    chats.forEach(c => {
        const others = c.participants.filter(p => p._id.toString() !== botId).map(p => p.name);
        console.log('  Chat:', c._id, '| Type:', c.type, '| With:', others.join(', '));
    });

    process.exit(0);
}

main().catch(err => { console.error(err); process.exit(1); });
