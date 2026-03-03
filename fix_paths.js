const fs = require('fs');
const path = require('path');

const srcDir = '/var/www/whatsapplikeapp/src_update';
const destDir = '/var/www/whatsapplikeapp/backend';

const files = fs.readdirSync(srcDir);

files.forEach(f => {
    if (f.includes('\\')) {
        const destRelPath = f.replace(/\\/g, '/');
        const fullDestPath = path.join(destDir, destRelPath);
        const targetDir = path.dirname(fullDestPath);

        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        fs.copyFileSync(path.join(srcDir, f), fullDestPath);
        console.log(`Copied ${f} to ${fullDestPath}`);
    }
});
