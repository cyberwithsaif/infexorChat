/**
 * Infexor Chat — System Metrics Collector
 * Collects CPU, RAM, disk, event loop, network, and TURN stats.
 * Caches in Redis to avoid overloading the main server.
 */

const os = require('os');
const { execSync, exec } = require('child_process');
const { getRedis } = require('../config/redis');
const logger = require('../utils/logger');

const CACHE_TTL = 5; // seconds
const CACHE_KEY = 'admin:metrics:system';

// Event loop lag tracker
let lastLoopTime = Date.now();
let eventLoopLag = 0;
setInterval(() => {
    const now = Date.now();
    eventLoopLag = Math.max(0, now - lastLoopTime - 100);
    lastLoopTime = now;
}, 100);

/**
 * Get CPU usage percentage
 */
function getCpuUsage() {
    const cpus = os.cpus();
    let totalIdle = 0, totalTick = 0;
    cpus.forEach(cpu => {
        for (const type in cpu.times) totalTick += cpu.times[type];
        totalIdle += cpu.times.idle;
    });
    const idle = totalIdle / cpus.length;
    const total = totalTick / cpus.length;
    return Math.round(((total - idle) / total) * 100);
}

/**
 * Get disk usage
 */
function getDiskUsage() {
    try {
        const output = execSync("df -B1 / | tail -1 | awk '{print $2,$3,$4,$5}'", { timeout: 3000 }).toString().trim();
        const [total, used, available, percent] = output.split(/\s+/);
        return {
            total: parseInt(total) || 0,
            used: parseInt(used) || 0,
            available: parseInt(available) || 0,
            percent: parseInt(percent) || 0,
        };
    } catch {
        return { total: 0, used: 0, available: 0, percent: 0 };
    }
}

/**
 * Get folder sizes (async, cached)
 */
function getFolderSize(path) {
    try {
        const output = execSync(`du -sb ${path} 2>/dev/null | cut -f1`, { timeout: 5000 }).toString().trim();
        return parseInt(output) || 0;
    } catch {
        return 0;
    }
}

/**
 * Get network stats
 */
function getNetworkStats() {
    try {
        const output = execSync("cat /proc/net/dev | grep -E 'eth0|ens' | head -1", { timeout: 2000 }).toString().trim();
        const parts = output.split(/\s+/);
        return {
            rxBytes: parseInt(parts[1]) || 0,
            txBytes: parseInt(parts[9]) || 0,
        };
    } catch {
        return { rxBytes: 0, txBytes: 0 };
    }
}

/**
 * Get TURN server stats from turnadmin or coturn metrics
 */
function getTurnStats() {
    try {
        const output = execSync("turnadmin -s 2>/dev/null || echo '{}'", { timeout: 3000 }).toString().trim();
        // Parse turnadmin output for active sessions
        const sessions = (output.match(/total-allocations=(\d+)/i) || [])[1] || '0';
        return {
            activeAllocations: parseInt(sessions),
            available: true,
        };
    } catch {
        return { activeAllocations: 0, available: false };
    }
}

/**
 * Get PM2 process list
 */
function getPm2Processes() {
    try {
        const output = execSync("pm2 jlist 2>/dev/null", { timeout: 5000 }).toString().trim();
        const apps = JSON.parse(output);
        return apps.map(a => ({
            name: a.name,
            pid: a.pid,
            status: a.pm2_env?.status,
            memoryMB: Math.round((a.monit?.memory || 0) / 1024 / 1024),
            cpu: a.monit?.cpu || 0,
            restarts: a.pm2_env?.restart_time || 0,
            uptime: a.pm2_env?.pm_uptime || 0,
            mode: a.pm2_env?.exec_mode || 'fork',
        }));
    } catch {
        return [];
    }
}

/**
 * Collect all system metrics
 */
async function collectMetrics() {
    const redis = getRedis();

    // Check Redis cache first
    if (redis) {
        try {
            const cached = await redis.get(CACHE_KEY);
            if (cached) return JSON.parse(cached);
        } catch { }
    }

    const mem = process.memoryUsage();
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const disk = getDiskUsage();
    const network = getNetworkStats();

    const metrics = {
        cpu: {
            percent: getCpuUsage(),
            cores: os.cpus().length,
            model: os.cpus()[0]?.model || 'Unknown',
        },
        memory: {
            totalGB: (totalMem / 1073741824).toFixed(2),
            usedGB: ((totalMem - freeMem) / 1073741824).toFixed(2),
            freeGB: (freeMem / 1073741824).toFixed(2),
            percent: Math.round(((totalMem - freeMem) / totalMem) * 100),
        },
        heap: {
            usedMB: Math.round(mem.heapUsed / 1048576),
            totalMB: Math.round(mem.heapTotal / 1048576),
            rssMB: Math.round(mem.rss / 1048576),
        },
        disk,
        network,
        eventLoopLag,
        uptime: os.uptime(),
        processUptime: process.uptime(),
        loadAvg: os.loadavg(),
        hostname: os.hostname(),
        platform: `${os.type()} ${os.release()}`,
        nodeVersion: process.version,
        timestamp: Date.now(),
    };

    // Cache in Redis
    if (redis) {
        try {
            await redis.setex(CACHE_KEY, CACHE_TTL, JSON.stringify(metrics));
        } catch { }
    }

    return metrics;
}

/**
 * Collect storage-specific metrics (heavier, cached longer)
 */
async function collectStorageMetrics() {
    const redis = getRedis();
    const cacheKey = 'admin:metrics:storage';

    if (redis) {
        try {
            const cached = await redis.get(cacheKey);
            if (cached) return JSON.parse(cached);
        } catch { }
    }

    const disk = getDiskUsage();
    const uploadsSize = getFolderSize('/var/www/whatsapplikeapp/uploads');
    const logsSize = getFolderSize('/var/www/whatsapplikeapp/logs');

    const storage = {
        disk,
        uploads: { bytes: uploadsSize, mb: (uploadsSize / 1048576).toFixed(2) },
        logs: { bytes: logsSize, mb: (logsSize / 1048576).toFixed(2) },
        timestamp: Date.now(),
    };

    if (redis) {
        try {
            await redis.setex(cacheKey, 30, JSON.stringify(storage));
        } catch { }
    }

    return storage;
}

/**
 * Collect PM2 process list (cached)
 */
async function collectPm2Metrics() {
    const redis = getRedis();
    const cacheKey = 'admin:metrics:pm2';

    if (redis) {
        try {
            const cached = await redis.get(cacheKey);
            if (cached) return JSON.parse(cached);
        } catch { }
    }

    const processes = getPm2Processes();

    if (redis) {
        try {
            await redis.setex(cacheKey, CACHE_TTL, JSON.stringify(processes));
        } catch { }
    }

    return processes;
}

module.exports = {
    collectMetrics,
    collectStorageMetrics,
    collectPm2Metrics,
    getTurnStats,
    getCpuUsage,
    getDiskUsage,
    getNetworkStats,
    eventLoopLag: () => eventLoopLag,
};
