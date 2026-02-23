require('dotenv').config();
const mongoose = require('mongoose');

async function dropIndex() {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/infexor_chat');
        console.log('Connected to DB');
        await mongoose.connection.collection('statuses').dropIndex('expiresAt_1');
        console.log('Dropped index expiresAt_1 successfully.');
    } catch (err) {
        console.error('Error dropping index (may not exist):', err.message);
    } finally {
        process.exit(0);
    }
}

dropIndex();
