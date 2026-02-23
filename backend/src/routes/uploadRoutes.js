const express = require('express');
const { auth } = require('../middleware/auth');
const uploadController = require('../controllers/uploadController');
const {
    imageUpload,
    videoUpload,
    audioUpload,
    voiceUpload,
    documentUpload,
} = require('../config/upload');

const router = express.Router();

// All upload routes require authentication
router.use(auth);

// Image upload (compressed + thumbnail generated)
router.post('/image', imageUpload.single('image'), uploadController.uploadImage);

// Video upload
router.post('/video', videoUpload.single('video'), uploadController.uploadVideo);

// Audio upload
router.post('/audio', audioUpload.single('audio'), uploadController.uploadAudio);

// Voice note upload
router.post('/voice', voiceUpload.single('voice'), uploadController.uploadVoice);

// Document upload
router.post('/document', documentUpload.single('document'), uploadController.uploadDocument);

// Mark media as downloaded for auto-cleanup
router.post('/mark-downloaded', uploadController.markDownloaded);

module.exports = router;
