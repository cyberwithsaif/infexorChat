const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');
const env = require('./env');

const uploadsDir = path.resolve(env.uploads.dir);

// ──────────────────────────────────────────────
// Allowed MIME types per category
// ──────────────────────────────────────────────
const ALLOWED_MIMES = {
  image: [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
  ],
  video: [
    'video/mp4',
    'video/mpeg',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    'video/webm',
    'video/3gpp',
  ],
  audio: [
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/aac',
    'audio/flac',
    'audio/x-m4a',
  ],
  voice: [
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/aac',
    'audio/x-m4a',
    'audio/amr',
  ],
  document: [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip',
    'application/x-rar-compressed',
    'application/x-7z-compressed',
    'application/gzip',
    'text/plain',
    'text/csv',
    'application/json',
    'application/xml',
  ],
};

// ──────────────────────────────────────────────
// Subdirectory mapping
// ──────────────────────────────────────────────
const SUBDIR_MAP = {
  image: 'images',
  video: 'videos',
  audio: 'audio',
  voice: 'voice',
  document: 'documents',
};

// ──────────────────────────────────────────────
// Ensure a directory exists (sync, runs once at
// config time or lazily on first upload)
// ──────────────────────────────────────────────
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

// ──────────────────────────────────────────────
// Build a multer disk-storage instance for a
// given file category (image | video | audio |
// voice | document)
// ──────────────────────────────────────────────
function createStorage(category) {
  const subdir = SUBDIR_MAP[category];

  return multer.diskStorage({
    destination(_req, _file, cb) {
      const dest = path.join(uploadsDir, subdir);
      ensureDir(dest);
      cb(null, dest);
    },
    filename(_req, file, cb) {
      const uniqueId = crypto.randomUUID();
      const ext = path.extname(file.originalname).toLowerCase() || '';
      cb(null, `${uniqueId}${ext}`);
    },
  });
}

// ──────────────────────────────────────────────
// File-filter factory – rejects files whose MIME
// type is not in the allowed list for the category
// ──────────────────────────────────────────────
function createFileFilter(category) {
  const allowed = ALLOWED_MIMES[category];

  return (_req, file, cb) => {
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(
        new multer.MulterError(
          'LIMIT_UNEXPECTED_FILE',
          `Invalid file type. Allowed types for ${category}: ${allowed.join(', ')}`
        ),
        false
      );
    }
  };
}

// ──────────────────────────────────────────────
// Create configured multer instances
// ──────────────────────────────────────────────
function createUploader(category) {
  return multer({
    storage: createStorage(category),
    limits: {
      fileSize: env.uploads.maxFileSize[category],
    },
    fileFilter: createFileFilter(category),
  });
}

const imageUpload = createUploader('image');
const videoUpload = createUploader('video');
const audioUpload = createUploader('audio');
const voiceUpload = createUploader('voice');
const documentUpload = createUploader('document');

module.exports = {
  imageUpload,
  videoUpload,
  audioUpload,
  voiceUpload,
  documentUpload,
  ALLOWED_MIMES,
  uploadsDir,
};
