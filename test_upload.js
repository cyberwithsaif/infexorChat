const env = require('./backend/src/config/env');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const http = require('http');
const FormData = require('form-data'); // usually pre-installed

function generateToken() {
    return jwt.sign({ id: 'testadmin', username: 'admin' }, env.adminJwt.secret, { expiresIn: '1h' });
}

const token = generateToken();

const formData = new FormData();
// Just sending a dummy text file as image
const buffer = Buffer.from('dummy image content');
formData.append('image', buffer, { filename: 'dummy.jpg', contentType: 'image/jpeg' });

const options = {
    hostname: '127.0.0.1',
    port: 5000,
    path: '/api/admin/upload/image',
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${token}`,
        ...formData.getHeaders()
    }
};

const req = http.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        console.log(`Status: ${res.statusCode}`);
        console.log(`Response: ${data}`);
    });
});

req.on('error', (e) => {
    console.error(`Problem with request: ${e.message}`);
});

formData.pipe(req);
