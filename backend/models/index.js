const Tenant = require('./Tenant');
const User = require('./User');
const Category = require('./Category');
const Product = require('./Product');
const Sale = require('./Sale');
const Damage = require('./Damage');
const Purchase = require('./Purchase');
const AuditLog = require('./AuditLog');
const PasswordViewLog = require('./PasswordViewLog');

module.exports = {
  Tenant,
  User,
  Category,
  Product,
  Sale,
  Damage,
  Purchase,
  AuditLog,
  PasswordViewLog
};