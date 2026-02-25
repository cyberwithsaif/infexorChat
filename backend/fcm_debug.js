const mongoose = require('mongoose');
const User = require('./models/User');
const admin = require('firebase-admin');

async function main() {
    await mongoose.connect('mongodb://localhost:27017/infexor_chat');
    console.log('Connected to MongoDB');

    // 1. Check all users FCM tokens
    const users = await User.find({}).select('phone name fcmToken').lean();
    console.log('\n=== USER FCM TOKENS ===');
    users.forEach(u => {
        const token = u.fcmToken || 'EMPTY';
        const preview = token.length > 20 ? token.substring(0, 30) + '...' : token;
        console.log('  ' + (u.name || 'No Name') + ' (' + u.phone + '): ' + preview);
    });

    // 2. Check Firebase Admin SDK
    console.log('\n=== FIREBASE ADMIN SDK ===');
    try {
        const sa = require('../infexorchat-firebase-adminsdk.json');
        console.log('  Key file found. Project: ' + sa.project_id);
        try {
            admin.initializeApp({ credential: admin.credential.cert(sa) });
            console.log('  Initialized OK');
        } catch (e) {
            if (e.code === 'app/duplicate-app') console.log('  Already initialized');
            else console.log('  Init ERROR: ' + e.message);
        }
    } catch (e) {
        console.log('  KEY FILE ERROR: ' + e.message);
    }

    // 3. Test push to first user with a token
    const userWithToken = users.find(u => u.fcmToken && u.fcmToken.length > 10);
    if (userWithToken) {
        console.log('\n=== TEST PUSH to ' + (userWithToken.name || userWithToken.phone) + ' ===');
        try {
            const result = await admin.messaging().send({
                notification: { title: 'FCM Test', body: 'Push notifications work!' },
                token: userWithToken.fcmToken,
                android: { priority: 'high' }
            });
            console.log('  SUCCESS! Message ID: ' + result);
        } catch (e) {
            console.log('  FAILED: ' + e.code + ' - ' + e.message);
        }
    } else {
        console.log('\n  WARNING: No users have a valid fcmToken stored!');
        console.log('  The login flow is NOT saving the FCM token.');
    }

    await mongoose.disconnect();
    process.exit(0);
}

main().catch(e => { console.error('FATAL:', e); process.exit(1); });
