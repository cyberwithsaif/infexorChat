/**
 * Create AI Bot User — Run ONCE on VPS
 *
 * Usage:
 *   cd /path/to/backend
 *   node create_ai_bot.js
 *
 * After running, copy the printed Bot User ID into your .env:
 *   AI_BOT_USER_ID=<the printed ID>
 */

const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./src/models/User');

(async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // Check if bot already exists
        const existing = await User.findOne({ phone: '+0000000000' });
        if (existing) {
            console.log('AI Bot user already exists!');
            console.log('Bot User ID:', existing._id.toString());
            console.log('Set AI_BOT_USER_ID=' + existing._id.toString() + ' in your .env');
            process.exit(0);
        }

        // Create bot user
        const bot = await User.create({
            phone: '+0000000000',
            name: 'InfexorChat AI',
            about: 'AI-powered assistant for InfexorChat',
            isProfileComplete: true,
            status: 'active',
            isOnline: true,
        });

        console.log('✅ AI Bot user created successfully!');
        console.log('Bot User ID:', bot._id.toString());
        console.log('');
        console.log('Add this to your .env:');
        console.log(`AI_BOT_USER_ID=${bot._id.toString()}`);
        process.exit(0);
    } catch (error) {
        console.error('Error creating AI bot user:', error);
        process.exit(1);
    }
})();
