require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    await mongoose.connect(env.mongodbUri);
    const Chat = require('./src/models/Chat');
    const User = require('./src/models/User');

    // Find a chat that likely belongs to the bot (e.g., ai bot chat)
    const chats = await Chat.find().populate('participants');
    console.log('Total chats:', chats.length);

    let botIdFound = null;
    for (let chat of chats) {
        for (let p of chat.participants) {
            if (p.phone && p.phone.includes('0000')) {
                console.log('Found bot participant in chat:', p._id, '| Name:', p.name, '| Phone:', p.phone);
                botIdFound = p._id;
            }
        }
    }

    console.log('\\ntarget Env Bot ID:', env.ai.botUserId);

    if (botIdFound && botIdFound.toString() !== env.ai.botUserId) {
        console.log('MISMATCH! The chat uses', botIdFound, 'but the env uses', env.ai.botUserId);
    }

    process.exit(0);
}
main();
