const mongoose = require('mongoose');

async function main() {
    await mongoose.connect('mongodb://localhost:27017/infexor_chat');
    console.log('Connected to MongoDB');

    // Migrate fcmTokens array to fcmToken string
    const result = await mongoose.connection.db.collection('users').updateMany(
        { fcmTokens: { $exists: true, $ne: [] } },
        [{ $set: { fcmToken: { $arrayElemAt: ['$fcmTokens', 0] } } }]
    );
    console.log('Migration result:', result.modifiedCount, 'users updated');

    // Verify
    const users = await mongoose.connection.db.collection('users')
        .find({}, { projection: { phone: 1, name: 1, fcmToken: 1, fcmTokens: 1 } })
        .toArray();
    users.forEach(u => {
        console.log(u.name, '(' + u.phone + '):',
            'fcmToken=' + (u.fcmToken ? u.fcmToken.substring(0, 30) + '...' : 'EMPTY'),
            'fcmTokens=' + JSON.stringify(u.fcmTokens || []));
    });

    await mongoose.disconnect();
    process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
