const fs = require('fs');
const filePath = '/var/www/whatsapplikeapp/src/routes/adminRoutes.js';

let content = fs.readFileSync(filePath, 'utf8');

// Add Official App Status routes
if (!content.includes('/status', content.indexOf('// Reports'))) {
    content = content.replace(
        "// Broadcasts",
        "// Official App Status\nrouter.get('/status', adminController.getOfficialStatuses);\nrouter.post('/status', adminController.createOfficialStatus);\nrouter.delete('/status/:id', adminController.deleteOfficialStatus);\n\n// Broadcasts"
    );
}

fs.writeFileSync(filePath, content);
console.log('adminRoutes.js patched successfully with status routes.');
