const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config({ path: __dirname + '/../.env' });

const User = require('../models/User');
const Tenant = require('../models/Tenant');
const Category = require('../models/Category');
const Product = require('../models/Product');
const { encryptPassword } = require('../utils/encryption');

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // Check if developer exists
    const existingDev = await User.findOne({ role: 'developer' });
    if (existingDev) {
      console.log('Developer account already exists. Skipping seed.');
      process.exit(0);
    }

    // Create developer account
    const devPassword = 'admin123';
    const { encryptedPassword, iv } = encryptPassword(devPassword);
    const passwordHash = await bcrypt.hash(devPassword, 12);

    const developer = new User({
      name: 'System Developer',
      email: 'developer@system.com',
      encryptedPassword,
      passwordIV: iv,
      passwordHash,
      role: 'developer'
    });
    await developer.save();
    console.log('✅ Developer account created: developer@system.com / admin123');

    // Create sample business
    const adminPassword = 'admin123';
    const { encryptedPassword: adminEnc, iv: adminIv } = encryptPassword(adminPassword);
    const adminHash = await bcrypt.hash(adminPassword, 12);

    const tenant = new Tenant({
      businessName: 'ABC Retail Store',
      businessType: 'Retail',
      phoneNumber: '1-800-555-0123',
      address: '123 Main Street, City, State',
      taxId: '12-3456789',
      email: 'john@abcretail.com',
      ownerName: 'John Doe',
      createdBy: developer._id
    });
    await tenant.save();

    const admin = new User({
      name: 'John Doe',
      email: 'john@abcretail.com',
      encryptedPassword: adminEnc,
      passwordIV: adminIv,
      passwordHash: adminHash,
      role: 'admin',
      tenantId: tenant._id,
      createdBy: developer._id,
      createdByRole: 'developer',
      creationReason: 'primary',
      permissions: [
        'manage_categories', 'create_products', 'edit_products', 'delete_products',
        'record_sales', 'record_purchases', 'record_damages', 'view_inventory',
        'view_transactions', 'view_profits', 'adjust_inventory', 'view_reports'
      ]
    });
    await admin.save();
    console.log('✅ Admin account created: john@abcretail.com / admin123');

    // Create categories
    const catNames = ['Electronics', 'Clothing', 'Food & Beverage', 'Furniture', 'Books', 'Health & Beauty'];
    const categories = [];
    for (const name of catNames) {
      const cat = new Category({ name, tenantId: tenant._id, createdBy: admin._id });
      await cat.save();
      categories.push(cat);
    }
    console.log('✅ Default categories created');

    // Create sample products
    const products = [
      { name: 'Wireless Mouse', categoryId: categories[0]._id, costPrice: 15, sellingPrice: 29.99, currentStock: 50, minimumStock: 10 },
      { name: 'USB-C Cable', categoryId: categories[0]._id, costPrice: 5, sellingPrice: 12.99, currentStock: 100, minimumStock: 20 },
      { name: 'Cotton T-Shirt', categoryId: categories[1]._id, costPrice: 8, sellingPrice: 19.99, currentStock: 75, minimumStock: 15 },
      { name: 'Java Programming Book', categoryId: categories[4]._id, costPrice: 20, sellingPrice: 39.99, currentStock: 3, minimumStock: 5 },
      { name: 'Vitamin C Supplements', categoryId: categories[5]._id, costPrice: 10, sellingPrice: 24.99, currentStock: 40, minimumStock: 10 },
    ];

    for (const p of products) {
      const product = new Product({ ...p, tenantId: tenant._id, sku: `SKU-${Date.now().toString(36).toUpperCase()}`, createdBy: admin._id });
      await product.save();
    }
    console.log('✅ Sample products created');

    // Create sample employees
    const empNames = [
      { name: 'Sarah Johnson', email: 'sarah@abcretail.com' },
      { name: 'Mike R.', email: 'mike@abcretail.com' }
    ];

    for (const emp of empNames) {
      const empPassword = 'admin123';
      const { encryptedPassword: empEnc, iv: empIv } = encryptPassword(empPassword);
      const empHash = await bcrypt.hash(empPassword, 12);

      const employee = new User({
        name: emp.name,
        email: emp.email,
        encryptedPassword: empEnc,
        passwordIV: empIv,
        passwordHash: empHash,
        role: 'employee',
        tenantId: tenant._id,
        createdBy: admin._id,
        createdByRole: 'admin',
        creationReason: 'primary',
        employeeId: `EMP-${Date.now().toString(36).toUpperCase()}`,
        permissions: ['record_sales', 'record_purchases', 'record_damages', 'view_inventory', 'view_transactions', 'view_reports']
      });
      await employee.save();
    }
    console.log('✅ Sample employees created');

    console.log('\n🎉 Seed completed successfully!');
    console.log('\nLogin credentials:');
    console.log('  Developer: developer@system.com / admin123');
    console.log('  Admin:     john@abcretail.com / admin123');
    console.log('  Employee:  sarah@abcretail.com / admin123');

    process.exit(0);
  } catch (error) {
    console.error('Seed error:', error);
    process.exit(1);
  }
};

seed();
