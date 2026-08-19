const crypto = require('crypto');

const ALGORITHM = 'aes-256-cbc';
const ENCRYPTION_KEY = Buffer.from(process.env.ENCRYPTION_KEY, 'hex');

/**
 * Encrypt a password using AES-256-CBC
 * @param {string} password - Plain text password
 * @returns {Object} - { encryptedPassword, iv }
 */
const encryptPassword = (password) => {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, ENCRYPTION_KEY, iv);
  let encrypted = cipher.update(password, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return {
    encryptedPassword: encrypted,
    iv: iv.toString('hex')
  };
};

/**
 * Decrypt a password using AES-256-CBC
 * @param {string} encryptedPassword - Encrypted password hex string
 * @param {string} iv - Initialization vector hex string
 * @returns {string} - Plain text password
 */
const decryptPassword = (encryptedPassword, iv) => {
  const decipher = crypto.createDecipheriv(ALGORITHM, ENCRYPTION_KEY, Buffer.from(iv, 'hex'));
  let decrypted = decipher.update(encryptedPassword, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
};

module.exports = { encryptPassword, decryptPassword };
