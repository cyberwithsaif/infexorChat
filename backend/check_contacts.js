const mongoose = require('mongoose');
const Contact = require('./src/models/Contact');

async function run() {
    await mongoose.connect('mongodb://127.0.0.1:27017/infexorChat');

    const userId = '699600aa8154556f5fda7347'; // From the logs: 699600aa8154556f5fda7347 or 699602688154556f5fda7360

    const contacts1 = await Contact.find({ userId: '699602688154556f5fda7360' }).populate('contactUserId', 'name phone').lean();
    console.log('Contacts for 699602688154556f5fda7360:', contacts1.map(c => ({ phone: c.phone, name: c.name, registered: c.isRegistered, contactUserId: c.contactUserId })));

    const contacts2 = await Contact.find({ userId: '699600aa8154556f5fda7347' }).populate('contactUserId', 'name phone').lean();
    console.log('Contacts for 699600aa8154556f5fda7347:', contacts2.map(c => ({ phone: c.phone, name: c.name, registered: c.isRegistered, contactUserId: c.contactUserId })));

    process.exit();
}
run();
