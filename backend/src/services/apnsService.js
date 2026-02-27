/**
 * apnsService.js
 *
 * Sends APNs VoIP pushes to iOS devices.
 *
 * Uses Apple's HTTP/2 APNs API with JWT authentication (.p8 key).
 * No third-party packages required — uses Node.js built-ins only.
 *
 * Setup:
 *   1. Download AuthKey_XXXXXXXXXX.p8 from Apple Developer portal
 *   2. Place it at: /var/www/whatsapplikeapp/apns-key.p8
 *   3. Set environment variables in .env:
 *        APNS_KEY_ID=XXXXXXXXXX          (10-char Key ID)
 *        APNS_TEAM_ID=XXXXXXXXXX         (10-char Team ID)
 *        APNS_BUNDLE_ID=com.infexor.infexor_chat
 *        APNS_KEY_PATH=/var/www/whatsapplikeapp/apns-key.p8
 *        APNS_PRODUCTION=false           (true for App Store builds)
 */

'use strict';

const http2  = require('http2');
const fs     = require('fs');
const crypto = require('crypto');
const logger = require('../utils/logger');

// ─── Configuration ───────────────────────────────────────────────────────────

const KEY_ID     = process.env.APNS_KEY_ID;
const TEAM_ID    = process.env.APNS_TEAM_ID;
const BUNDLE_ID  = process.env.APNS_BUNDLE_ID || 'com.infexor.infexor_chat';
const KEY_PATH   = process.env.APNS_KEY_PATH  || '/var/www/whatsapplikeapp/apns-key.p8';
const PRODUCTION = process.env.APNS_PRODUCTION === 'true';

const APNS_HOST = PRODUCTION
    ? 'https://api.push.apple.com'
    : 'https://api.sandbox.push.apple.com';

// ─── JWT Generation ───────────────────────────────────────────────────────────
// APNs JWT must be regenerated at most every 60 minutes.

let _cachedJwt       = null;
let _jwtGeneratedAt  = 0;
const JWT_TTL_MS     = 50 * 60 * 1000; // 50 minutes (Apple revokes at 60)

function generateJwt() {
    const now = Date.now();
    if (_cachedJwt && (now - _jwtGeneratedAt) < JWT_TTL_MS) {
        return _cachedJwt;
    }

    if (!KEY_ID || !TEAM_ID) {
        throw new Error('APNS_KEY_ID and APNS_TEAM_ID must be set in environment');
    }

    const p8Key = fs.readFileSync(KEY_PATH, 'utf8');

    const header  = base64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID }));
    const payload = base64url(JSON.stringify({
        iss: TEAM_ID,
        iat: Math.floor(now / 1000),
    }));

    const unsigned  = `${header}.${payload}`;
    const sign      = crypto.createSign('SHA256');
    sign.update(unsigned);
    // Apple requires IEEE P1363 encoding (raw r||s), NOT DER
    const signature = sign.sign({ key: p8Key, dsaEncoding: 'ieee-p1363' }).toString('base64url');

    _cachedJwt      = `${unsigned}.${signature}`;
    _jwtGeneratedAt = now;

    logger.info('[APNs] JWT generated/refreshed');
    return _cachedJwt;
}

function base64url(str) {
    return Buffer.from(str)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

// ─── HTTP/2 Client ────────────────────────────────────────────────────────────
// Reuse a single HTTP/2 session per process for efficiency.

let _h2Session = null;

function getH2Session() {
    if (_h2Session && !_h2Session.destroyed && !_h2Session.closed) {
        return Promise.resolve(_h2Session);
    }

    return new Promise((resolve, reject) => {
        const session = http2.connect(APNS_HOST);

        session.on('error', (err) => {
            logger.error('[APNs] HTTP/2 session error:', err);
            _h2Session = null;
        });

        session.on('close', () => {
            _h2Session = null;
        });

        session.on('connect', () => {
            _h2Session = session;
            resolve(session);
        });

        // connect event fires asynchronously — also handle immediate errors
        session.on('error', reject);
    });
}

// ─── Core Send Function ──────────────────────────────────────────────────────

/**
 * Send a single APNs push.
 *
 * @param {string} deviceToken  - Hex VoIP push token from PushKit
 * @param {object} payload      - JSON payload
 * @param {object} options
 * @param {string} options.pushType   - 'voip' | 'alert' | 'background'
 * @param {string} options.topic      - APNs topic (defaults to VoIP topic)
 * @param {number} options.priority   - 10 (immediate) | 5 (power-conscious)
 * @param {number} options.expiration - Unix timestamp (0 = do not store)
 */
async function sendApns(deviceToken, payload, options = {}) {
    const {
        pushType   = 'voip',
        topic      = `${BUNDLE_ID}.voip`,
        priority   = 10,
        expiration = Math.floor(Date.now() / 1000) + 30, // 30 seconds
    } = options;

    const jwt  = generateJwt();
    const body = JSON.stringify(payload);
    const path = `/3/device/${deviceToken}`;

    const headers = {
        ':method':              'POST',
        ':path':                path,
        ':scheme':              'https',
        ':authority':           APNS_HOST.replace('https://', ''),
        'authorization':        `bearer ${jwt}`,
        'apns-push-type':       pushType,
        'apns-topic':           topic,
        'apns-priority':        String(priority),
        'apns-expiration':      String(expiration),
        'content-type':         'application/json',
        'content-length':       Buffer.byteLength(body),
    };

    const session = await getH2Session();

    return new Promise((resolve, reject) => {
        const req = session.request(headers);
        let responseData = '';
        let statusCode   = 0;

        req.on('response', (responseHeaders) => {
            statusCode = responseHeaders[':status'];
        });

        req.on('data', (chunk) => {
            responseData += chunk;
        });

        req.on('end', () => {
            if (statusCode === 200) {
                resolve({ success: true });
            } else {
                let reason = 'Unknown';
                try { reason = JSON.parse(responseData).reason; } catch {}
                const err = new Error(`APNs error ${statusCode}: ${reason}`);
                err.statusCode = statusCode;
                err.reason     = reason;
                reject(err);
            }
        });

        req.on('error', reject);

        req.write(body);
        req.end();
    });
}

// ─── Public API ───────────────────────────────────────────────────────────────

const isInitialized = () => {
    return !!(KEY_ID && TEAM_ID && fs.existsSync(KEY_PATH));
};

/**
 * Send an incoming call VoIP push to an iOS device.
 *
 * @param {string} voipToken   - PushKit VoIP token
 * @param {object} callData    - { chatId, callerId, callerName, callerAvatar, type }
 */
exports.sendCallPush = async (voipToken, callData) => {
    if (!isInitialized()) {
        logger.warn('[APNs] Not initialized — APNS_KEY_ID/TEAM_ID/KEY_PATH missing');
        return;
    }
    if (!voipToken) return;

    try {
        const payload = {
            // aps block is required by Apple even for VoIP pushes
            aps: {
                'content-available': 1,
            },
            // Call data — read by AppDelegate.swift
            type:         callData.type === 'video' ? 'video_call' : 'audio_call',
            chatId:       callData.chatId       || '',
            callId:       callData.chatId       || '',   // alias
            callerId:     callData.callerId     || '',
            callerName:   callData.callerName   || 'Unknown',
            callerAvatar: callData.callerAvatar || '',
            callerPhone:  callData.callerPhone  || '',
        };

        await sendApns(voipToken, payload, {
            pushType:   'voip',
            topic:      `${BUNDLE_ID}.voip`,
            priority:   10,
            expiration: Math.floor(Date.now() / 1000) + 30,  // 30-second TTL
        });

        logger.info(`[APNs] Call push sent to ${voipToken.slice(0, 8)}...`);
    } catch (err) {
        logger.error('[APNs] sendCallPush error:', err.message);
        // Token invalid/unregistered → caller should clear voipToken from DB
        if (err.statusCode === 410 || err.reason === 'Unregistered') {
            return { invalidToken: true };
        }
    }
};

/**
 * Send a call-control VoIP push (cancel / busy / timeout).
 * Priority 5 is fine — we just need to wake the app, not show UI.
 *
 * @param {string} voipToken
 * @param {object} data - { type: 'call_cancel'|'call_busy'|'call_timeout', chatId, callerId }
 */
exports.sendCallControl = async (voipToken, data) => {
    if (!isInitialized() || !voipToken) return;

    try {
        const payload = {
            aps: { 'content-available': 1 },
            ...data,
        };

        await sendApns(voipToken, payload, {
            pushType:   'voip',
            topic:      `${BUNDLE_ID}.voip`,
            priority:   10,
            expiration: Math.floor(Date.now() / 1000) + 10,  // 10-second TTL
        });

        logger.info(`[APNs] Control push (${data.type}) sent to ${voipToken.slice(0, 8)}...`);
    } catch (err) {
        logger.error('[APNs] sendCallControl error:', err.message);
    }
};

/**
 * Send a regular (non-VoIP) APNs notification for chat messages.
 * Uses alert push type with the regular bundle topic (not .voip).
 */
exports.sendMessagePush = async (voipToken, title, body, data = {}) => {
    if (!isInitialized() || !voipToken) return;

    try {
        const payload = {
            aps: {
                alert: { title, body },
                sound: 'default',
                badge: 1,
            },
            ...data,
        };

        await sendApns(voipToken, payload, {
            pushType:   'alert',
            topic:      BUNDLE_ID,            // NOT .voip topic for regular messages
            priority:   10,
            expiration: Math.floor(Date.now() / 1000) + 86400,
        });
    } catch (err) {
        logger.error('[APNs] sendMessagePush error:', err.message);
    }
};

exports.isInitialized = isInitialized;
