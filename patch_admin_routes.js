const fs = require('fs');
const filePath = '/var/www/whatsapplikeapp/src/routes/adminRoutes.js';

let content = fs.readFileSync(filePath, 'utf8');

// Add missing requires
if (!content.includes('uploadController')) {
    content = content.replace(
        "const adminController = require('../controllers/adminController');",
        "const adminController = require('../controllers/adminController');\nconst uploadController = require('../controllers/uploadController');\nconst { imageUpload, videoUpload } = require('../config/upload');"
    );
}

// Add upload routes
if (!content.includes('/upload/image')) {
    content = content.replace(
        "// Broadcasts",
        "// Admin media uploads\nrouter.post('/upload/image', imageUpload.single('image'), uploadController.uploadImage);\nrouter.post('/upload/video', videoUpload.single('video'), uploadController.uploadVideo);\n\n// Broadcasts"
    );
}

fs.writeFileSync(filePath, content);
console.log('adminRoutes.js patched successfully.');
