module.exports = {
    apps: [
        {
            name: 'infexor-chat-backend',
            script: 'server.js',
            instances: 'max',
            exec_mode: 'cluster',
            env: {
                NODE_ENV: 'development',
            },
            env_production: {
                NODE_ENV: 'production',
            },
            watch: false,
            max_memory_restart: '1G',
            error_file: 'logs/err.log',
            out_file: 'logs/out.log',
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
        },
    ],
};
