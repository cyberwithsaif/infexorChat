require('dotenv').config();
const mongoose = require('mongoose');
const env = require('./src/config/env');

async function main() {
    await mongoose.connect(env.mongodbUri);

    const Device = require('./src/models/Device');
    const result = await Device.updateMany({}, { $unset: { refreshToken: 1 } });
    console.log('Cleared refresh tokens from ' + result.modifiedCount + ' devices');

    process.exit(0);
}

main().catch(function (err) { console.error(err); process.exit(1); });
