const fs = require('fs');
const file = '/var/www/whatsapplikeapp/src/services/notificationService.js';
let content = fs.readFileSync(file, 'utf8');

const oldStr = `        if (isCall) {
            // Call: data-only, high priority, 30s TTL, wake device from doze
            message.android = {
                priority: 'high',
                ttl: 30000,
                directBootOk: true,
            };
        } else {
            // Message: notification block + correct channel for Android 8+
            message.notification = { title, body };`;

const newStr = `        if (isCall) {
            // Call: Strictly data-only (NO message.notification block)
            message.android = {
                priority: 'high',
                ttl: 30000,
                directBootOk: true,
            };
        } else {
            // Message: notification block + correct channel for Android 8+
            message.notification = { title, body };`;

if (content.includes('message.notification = { title, body };')) {
    content = content.replace(oldStr, newStr);
    fs.writeFileSync(file, content);
    console.log('FCM Payload fixed on VPS');
} else {
    console.log('Already fixed or not found');
}
