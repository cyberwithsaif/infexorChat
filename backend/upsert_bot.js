require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    await mongoose.connect(env.mongodbUri);
    const User = require('./src/models/User');
    const botId = env.ai.botUserId;

    // Check if it exists
    let bot = await User.findById(botId);
    if (!bot) {
        console.log('Bot user does not exist. Creating now...');
        bot = new User({
            _id: botId,
            name: 'AI BOT',
            phone: '+01000000000',
            avatar: 'https://api.dicebear.com/9.x/bottts/png?seed=InfexorAI&backgroundColor=00C853',
            about: 'I am your advanced AI assistant.',
            status: 'online',
            isProfileComplete: true
        });
        await bot.save({ validateBeforeSave: false }); // Bypass any strict validation if needed
        console.log('Bot successfully created in DB!');
    } else {
        console.log('Bot already exists, updating...');
        bot.name = 'AI BOT';
        bot.avatar = 'https://api.dicebear.com/9.x/bottts/png?seed=InfexorAI&backgroundColor=00C853';
        bot.about = 'I am your advanced AI assistant.';
        await bot.save({ validateBeforeSave: false });
        console.log('Bot successfully updated in DB!');
    }

    process.exit(0);
}
main();
