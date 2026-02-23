const axios = require('axios');
const env = require('../config/env');
const logger = require('../utils/logger');

// MSG91 Widget API Endpoints
const SEND_OTP_URL = 'https://control.msg91.com/api/v5/widget/sendOtp';
const RETRY_OTP_URL = 'https://control.msg91.com/api/v5/widget/retryOtp';
const VERIFY_OTP_URL = 'https://control.msg91.com/api/v5/widget/verifyOtp';

class OtpService {
  constructor() {
    this.authKey = process.env.MSG91_AUTH_KEY || ''; // Will be loaded from env
    this.widgetId = process.env.MSG91_WIDGET_ID || '';
  }

  /**
   * Send OTP via MSG91 Widget API
   * @param {string} phone - Phone number with country code (e.g. 919876543210)
   * @returns {Promise<{success: boolean, reqId: string, message: string}>}
   */
  async sendOtp(phone) {
    if (!this.widgetId || !this.authKey) {
      logger.error('MSG91 credentials missing');
      return { success: false, message: 'SMS service not configured' };
    }

    try {
      // Remove any non-digit chars
      const cleanPhone = phone.replace(/\D/g, '');
      logger.info(`Sending OTP to ${cleanPhone} via MSG91...`);

      const response = await axios.post(SEND_OTP_URL, {
        widgetId: this.widgetId,
        identifier: cleanPhone,
      }, {
        headers: {
          'authkey': this.authKey,
          'Content-Type': 'application/json',
        },
      });

      if (response.data.type === 'success') {
        const reqId = response.data.message;
        logger.info(`MSG91 OTP Sent. reqId: ${reqId}`);
        return { success: true, reqId, message: 'OTP sent successfully' };
      } else {
        logger.error('MSG91 Send Failed:', response.data);
        return { success: false, message: response.data.message || 'Failed to send OTP' };
      }
    } catch (error) {
      logger.error('MSG91 Network Error:', error.message);
      return { success: false, message: 'Network error sending OTP' };
    }
  }

  /**
   * Verify OTP via MSG91 Widget API
   * @param {string} reqId - Request ID from sendOtp response
   * @param {string} otp - User entered OTP
   * @returns {Promise<{success: boolean, message: string}>}
   */
  async verifyOtp(reqId, otp) {
    if (!this.widgetId || !this.authKey) {
      return { success: false, message: 'SMS service not configured' };
    }

    try {
      logger.info(`Verifying OTP for reqId: ${reqId}`);

      const response = await axios.post(VERIFY_OTP_URL, {
        widgetId: this.widgetId,
        reqId,
        otp,
      }, {
        headers: {
          'authkey': this.authKey,
          'Content-Type': 'application/json',
        },
      });

      if (response.data.type === 'success') {
        logger.info('MSG91 OTP Verify Success');
        return { success: true, message: 'OTP verified successfully' };
      } else {
        logger.warn('MSG91 Verify Failed:', response.data);
        return { success: false, message: response.data.message || 'Invalid OTP' };
      }
    } catch (error) {
      // Handle strict errors (e.g. 400 Bad Request if OTP invalid)
      if (error.response && error.response.data) {
        logger.warn('MSG91 Verify Error Response:', error.response.data);
        return { success: false, message: error.response.data.message || 'Invalid OTP' };
      }
      logger.error('MSG91 Verify Network Error:', error.message);
      return { success: false, message: 'Verification service error' };
    }
  }

  /**
   * Retry OTP
   */
  async retryOtp(reqId, retryChannel) {
    if (!this.widgetId || !this.authKey) return { success: false, message: 'Config missing' };

    try {
      const payload = { widgetId: this.widgetId, reqId };
      if (retryChannel) payload.retryChannel = retryChannel;

      const response = await axios.post(RETRY_OTP_URL, payload, {
        headers: {
          'authkey': this.authKey,
          'Content-Type': 'application/json',
        },
      });

      if (response.data.type === 'success') {
        return { success: true, message: 'OTP resent successfully' };
      } else {
        return { success: false, message: response.data.message || 'Retry failed' };
      }
    } catch (error) {
      return { success: false, message: 'Retry network error' };
    }
  }
}

module.exports = new OtpService();
