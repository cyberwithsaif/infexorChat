const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const ApiResponse = require('../utils/apiResponse');
const { uploadsDir } = require('../config/upload');
const MediaCleanup = require('../models/MediaCleanup');

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

/**
 * Build public URL from a file's absolute path.
 * e.g. /uploads/images/abc123.jpg
 */
function publicUrl(absPath) {
  const relative = path.relative(uploadsDir, absPath).replace(/\\/g, '/');
  return `/uploads/${relative}`;
}

/**
 * Ensure the thumbnails directory exists.
 */
function ensureThumbnailDir() {
  const dir = path.join(uploadsDir, 'thumbnails');
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  return dir;
}

// ──────────────────────────────────────────────
// IMAGE UPLOAD
// ──────────────────────────────────────────────
exports.uploadImage = async (req, res, next) => {
  try {
    if (!req.file) {
      return ApiResponse.badRequest(res, 'No image file provided');
    }

    const file = req.file;
    const filePath = file.path;

    // --- Read original image metadata (no compression — send original quality) ---
    const metadata = await sharp(filePath).metadata();
    const width = metadata.width || 0;
    const height = metadata.height || 0;

    // --- Generate thumbnail only (small preview, not the original) ---
    const thumbDir = ensureThumbnailDir();
    const thumbName = `thumb_${path.basename(filePath)}`;
    const thumbPath = path.join(thumbDir, thumbName);

    await sharp(filePath)
      .resize({ width: 200, height: 200, fit: 'cover' })
      .jpeg({ quality: 60 })
      .toFile(thumbPath);

    const stat = fs.statSync(filePath);

    return ApiResponse.success(res, {
      url: publicUrl(filePath),
      thumbnail: publicUrl(thumbPath),
      mimeType: file.mimetype,
      size: stat.size,
      width,
      height,
      fileName: file.originalname,
    }, 'Image uploaded successfully');
  } catch (error) {
    next(error);
  }
};

// ──────────────────────────────────────────────
// VIDEO UPLOAD
// ──────────────────────────────────────────────
exports.uploadVideo = async (req, res, next) => {
  try {
    if (!req.file) {
      return ApiResponse.badRequest(res, 'No video file provided');
    }

    const file = req.file;
    const stat = fs.statSync(file.path);

    return ApiResponse.success(res, {
      url: publicUrl(file.path),
      thumbnail: '', // FFmpeg thumbnail generation can be added later
      mimeType: file.mimetype,
      size: stat.size,
      duration: 0, // Requires FFprobe; client can supply duration
      fileName: file.originalname,
    }, 'Video uploaded successfully');
  } catch (error) {
    next(error);
  }
};

// ──────────────────────────────────────────────
// AUDIO UPLOAD
// ──────────────────────────────────────────────
exports.uploadAudio = async (req, res, next) => {
  try {
    if (!req.file) {
      return ApiResponse.badRequest(res, 'No audio file provided');
    }

    const file = req.file;
    const stat = fs.statSync(file.path);

    return ApiResponse.success(res, {
      url: publicUrl(file.path),
      mimeType: file.mimetype,
      size: stat.size,
      duration: 0, // Client can supply duration
      fileName: file.originalname,
    }, 'Audio uploaded successfully');
  } catch (error) {
    next(error);
  }
};

// ──────────────────────────────────────────────
// VOICE NOTE UPLOAD
// ──────────────────────────────────────────────
exports.uploadVoice = async (req, res, next) => {
  try {
    if (!req.file) {
      return ApiResponse.badRequest(res, 'No voice file provided');
    }

    const file = req.file;
    const stat = fs.statSync(file.path);

    return ApiResponse.success(res, {
      url: publicUrl(file.path),
      mimeType: file.mimetype,
      size: stat.size,
      duration: 0, // Client supplies duration
      fileName: file.originalname,
    }, 'Voice note uploaded successfully');
  } catch (error) {
    next(error);
  }
};

// ──────────────────────────────────────────────
// DOCUMENT UPLOAD
// ──────────────────────────────────────────────
exports.uploadDocument = async (req, res, next) => {
  try {
    if (!req.file) {
      return ApiResponse.badRequest(res, 'No document file provided');
    }

    const file = req.file;
    const stat = fs.statSync(file.path);

    return ApiResponse.success(res, {
      url: publicUrl(file.path),
      mimeType: file.mimetype,
      size: stat.size,
      fileName: file.originalname,
    }, 'Document uploaded successfully');
  } catch (error) {
    next(error);
  }
};

// ──────────────────────────────────────────────
// MARK MEDIA AS DOWNLOADED (For auto-cleanup)
// ──────────────────────────────────────────────
exports.markDownloaded = async (req, res, next) => {
  try {
    const { fileUrl } = req.body;
    if (!fileUrl) {
      return ApiResponse.badRequest(res, 'File URL is required');
    }

    // Schedule deletion for 1 day (24 hours) from now
    const deleteAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Upsert to ensure we only have one cleanup entry per file
    // In case multiple people download it, resetting the timer is fine (or keeping the first one)
    // We'll just create a new one or update the existing one's deleteAt
    await MediaCleanup.findOneAndUpdate(
      { fileUrl },
      {
        deleteAt,
        downloadedBy: req.user._id,
      },
      { upsert: true, new: true }
    );

    return ApiResponse.success(res, null, 'Media marked for deletion in 1 day');
  } catch (error) {
    next(error);
  }
};
