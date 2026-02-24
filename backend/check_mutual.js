const mongoose = require('mongoose');
const Contact = require('./src/models/Contact');
const Status = require('./src/models/Status');
const User = require('./src/models/User');

async function run() {
    await mongoose.connect('mongodb://127.0.0.1:27017/infexorChat');

    const userId = new mongoose.Types.ObjectId('699602688154556f5fda7360');

    // 1. My registered contacts
    const myContacts = await Contact.find({
        userId: userId,
        isRegistered: true,
        contactUserId: { $ne: null },
    }).populate('contactUserId', 'name phone').lean();

    console.log(`\n--- I have ${myContacts.length} contacts saved ---`);
    const myContactUserIds = myContacts.map((c) => c.contactUserId._id);
    myContacts.forEach(c => console.log(`Saved: ${c.name || 'No Name'} (${c.phone}) - ID: ${c.contactUserId._id}`));

    // 2. Who out of my contacts also has ME saved?
    const mutualContacts = await Contact.find({
        userId: { $in: myContactUserIds },
        contactUserId: userId,
    }).populate('userId', 'name phone').lean();

    const mutualContactUserIds = mutualContacts.map((c) => c.userId._id);
    console.log(`\n--- I have ${mutualContactUserIds.length} MUTUAL contacts ---`);
    mutualContacts.forEach(c => console.log(`Mutual: ${c.userId.name} (${c.userId.phone}) - ID: ${c.userId._id}`));

    // 3. Statuses from Mutual Contacts
    const statuses = await Status.find({
        userId: { $in: mutualContactUserIds },
        expiresAt: { $gt: new Date() },
    }).populate('userId', 'name phone').sort({ createdAt: -1 });

    console.log(`\n--- Found ${statuses.length} active statuses from mutual contacts ---`);
    statuses.forEach(s => console.log(`Status by: ${s.userId.name} (${s.userId.phone})`));

    process.exit();
}
run();
