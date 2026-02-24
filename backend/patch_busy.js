// Patch socketHandler.js to add call:busy handler
const fs = require('fs');
const filePath = '/var/www/whatsapplikeapp/src/services/socketHandler.js';
let content = fs.readFileSync(filePath, 'utf8');

if (content.includes("call:busy")) {
  console.log('call:busy handler already exists — skipping');
  process.exit(0);
}

// Insert call:busy handler right after the call:reject block's closing });
const insertAfter = "    // Callee rejects";
const busyHandler = `    // Callee is busy on another call — notify caller
    socket.on('call:busy', (data) => {
      const { chatId, callerId } = data;
      if (!chatId || !callerId) return;
      logger.info('[call:busy] ' + userId + ' is busy, declining call from ' + callerId);
      io.to('user:' + callerId).emit('call:busy', {
        chatId,
        busyUserId: userId,
      });
    });

    `;

content = content.replace(insertAfter, busyHandler + insertAfter);

fs.writeFileSync(filePath, content);
console.log('call:busy handler added successfully');
