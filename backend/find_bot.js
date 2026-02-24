require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    await mongoose.connect(env.mongodbUri);
    const User = require('./src/models/User');

    // Find any user with phone starting with 0000000000 or any bot
    const bots = await User.find({ phone: { $regex: '0000' } }).lean();
    console.log('Found bots with 0000 in phone:');
    bots.forEach(b => {
        console.log(`ID: ${b._id} | Name: ${b.name} | Phone: ${b.phone}`);
    });

    const envBotId = env.ai.botUserId;
    console.log('\nEnv bot ID:', envBotId);

    // Check if the exact envBotId exists
    const exactBot = await User.findById(envBotId).lean();
    if (exactBot) {
        console.log('Env bot exists:', exactBot.name, exactBot.phone);
    } else {
        console.log('Env bot DOES NOT exist in DB!');
    }

    process.exit(0);
}
main();
