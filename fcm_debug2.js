const mongoose = require('mongoose');
const User = require('./src/models/User');

async function main() {
    await mongoose.connect('mongodb://localhost:27017/infexor_chat');
    const users = await User.find({}, 'name phone fcmToken isOnline lastSeen')
        .sort({ lastSeen: -1 })
        .limit(10);

    console.log('=== LATEST USERS ===');
    users.forEach(u => {
        const token = u.fcmToken ? (u.fcmToken.length > 30 ? u.fcmToken.substring(0, 30) + '...' : u.fcmToken) : 'EMPTY';
        console.log(`${u.name} (${u.phone}): ${token}`);
    });
    process.exit(0);
}

main().catch(console.error);
