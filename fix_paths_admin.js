const fs = require('fs');
const path = require('path');

const targetDir = '/var/www/whatsapplikeapp/admin';

const files = fs.readdirSync(targetDir);

files.forEach(f => {
    if (f.includes('\\')) {
        const destRelPath = f.replace(/\\/g, '/');
        const fullDestPath = path.join(targetDir, destRelPath);
        const newDir = path.dirname(fullDestPath);

        if (!fs.existsSync(newDir)) {
            fs.mkdirSync(newDir, { recursive: true });
        }

        fs.renameSync(path.join(targetDir, f), fullDestPath);
        console.log(`Moved ${f} to ${fullDestPath}`);
    }
});
