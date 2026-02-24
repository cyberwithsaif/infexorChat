require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    console.log('Connecting to MongoDB...', env.mongodbUri);
    await mongoose.connect(env.mongodbUri);

    const User = require('./src/models/User');
    const botId = env.ai.botUserId;

    console.log('Updating Bot Profile for ID:', botId);

    // Dicebear provides cool robot avatars automatically
    const avatarUrl = 'https://api.dicebear.com/9.x/bottts/png?seed=InfexorAI&backgroundColor=00C853';

    const result = await User.findByIdAndUpdate(botId, {
        name: 'AI BOT',
        avatar: avatarUrl,
        about: 'I am your advanced AI assistant.'
    }, { new: true });

    if (result) {
        console.log('Bot successfully updated:', result.name, '| Avatar:', result.avatar);
    } else {
        console.log('Bot user NOT found!');
    }

    process.exit(0);
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
