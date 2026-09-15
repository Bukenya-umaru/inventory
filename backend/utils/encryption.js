const crypto = require('crypto');

const ALGORITHM = 'aes-256-cbc';
const ENCRYPTION_KEY = Buffer.from(process.env.ENCRYPTION_KEY, 'hex');

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

const decryptPassword = (encryptedPassword, iv) => {
  const decipher = crypto.createDecipheriv(ALGORITHM, ENCRYPTION_KEY, Buffer.from(iv, 'hex'));
  let decrypted = decipher.update(encryptedPassword, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
};

module.exports = { encryptPassword, decryptPassword };