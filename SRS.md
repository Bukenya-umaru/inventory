# Software Requirements Specification (SRS)

## 1. Document Overview

### 1.1 Project Name
Multi-Tenant Inventory Management System

### 1.2 Document Purpose
This document defines the functional and non-functional requirements for the inventory management platform developed for business owners, administrators, employees, and developers. It describes the problem being solved, the scope of the system, the users, the major features, security requirements, and acceptance criteria.

### 1.3 Intended Audience
- Project stakeholders
- Development team
- QA/test team
- Business owners and administrators
- Future maintainers of the system

---

## 2. Introduction

### 2.1 Product Description
The system is a multi-tenant inventory and business management platform that helps businesses track products, sales, purchases, damages, supplier information, and financial performance. The platform is designed for a three-level organization model:

1. Developer
2. Admin / Business Owner
3. Employee

Each tenant has isolated data, ensuring separate businesses do not see or affect each other's inventory, records, or users.

### 2.2 Business Need
Businesses need a centralized platform to manage:
- stock levels and product inventory
- sales and purchases
- supplier relationships
- staff access and permissions
- financial reporting
- role-based administration
- audit tracking and password visibility management

### 2.3 System Goals
- Manage multiple businesses in a shared SaaS-style environment
- Support secure role-based access control
- Ensure data isolation between tenants
- Track business operations with logs and reports
- Provide a simple login flow for all user roles
- Support mobile app distribution and deployment

---

## 3. Scope

### 3.1 In Scope
- User authentication and authorization
- Multi-tenant business creation and management
- Product and category management
- Sales, purchases, and damage tracking
- Inventory monitoring and stock-level alerts
- Supplier management
- Reports and profit analysis
- Audit logs and password access tracking
- Developer/admin lifecycle management
- Mobile app download service

### 3.2 Out of Scope
- Full ERP suite beyond inventory and business operations
- E-commerce storefront or online customer checkout
- Payroll management
- Accounting integration with external systems
- Advanced BI dashboards beyond standard reporting

---

## 4. Users and Roles

### 4.1 Developer
The developer manages the platform at the top level. Responsibilities include:
- creating business tenants
- creating initial admin accounts
- assigning or controlling business lifecycle states
- viewing system-wide or tenant-level data when needed
- managing password visibility across users
- suspending/reactivating/deleting businesses

### 4.2 Admin / Business Owner
The admin manages a specific business tenant. Responsibilities include:
- managing employees
- assigning permissions
- creating categories and products
- recording purchases, sales, and damages
- reviewing inventory and profit reports
- controlling tenant-specific operations

### 4.3 Employee
The employee works within a single tenant with limited permissions. Responsibilities include:
- recording transactions
- viewing inventory and reports
- performing operational tasks assigned by the admin

---

## 5. Functional Requirements

### 5.1 Authentication and Authorization
#### FR-01: Shared Login
The system shall provide a single login form for all roles.

#### FR-02: Role-based Routing
After login, the system shall route users to the dashboard appropriate to their role.

#### FR-03: Authentication
The system shall validate user credentials before granting access.

#### FR-04: Password Security
Passwords shall be stored in a secure form using encryption and hashing techniques.

#### FR-05: Change Password
Authenticated users shall be able to change their password.

#### FR-06: Session Validation
The system shall validate authentication tokens for protected API requests.

### 5.2 Multi-Tenant Business Management
#### FR-07: Tenant Creation
The developer shall be able to create new business tenants.

#### FR-08: Tenant Data Isolation
Each tenant shall have isolated records, users, products, sales, and stock data.

#### FR-09: Tenant Status Control
The developer shall be able to suspend, reactivate, and delete businesses.

#### FR-10: Tenant Profile
A business tenant shall include business name, type, phone number, address, tax ID, email, and owner name.

### 5.3 User Management
#### FR-11: User Creation
Admin users shall be able to create employee accounts within their tenant.

#### FR-12: Granular Permissions
The system shall allow assigning specific permissions to users based on business needs.

#### FR-13: User Deletion
The admin shall be able to remove employee accounts when necessary.

#### FR-14: User Details
The system shall store user name, role, email, tenant assignment, and activity metadata.

### 5.4 Product and Category Management
#### FR-15: Category Management
Admins shall be able to create, edit, and manage product categories.

#### FR-16: Product Creation
Admins shall be able to add products with cost price, selling price, stock quantity, and minimum stock threshold.

#### FR-17: Product Updates
Admins shall be able to update product information and stock quantities as needed.

#### FR-18: Product Deletion
Admins shall be able to remove products that are no longer required.

#### FR-19: Low Stock Alerts
The system shall identify products whose stock falls below their minimum threshold.

### 5.5 Sales, Purchases, and Inventory Transactions
#### FR-20: Sales Recording
Users with appropriate permissions shall be able to record a sale.

#### FR-21: Automatic Profit Calculation
The system shall calculate profit automatically for sales transactions using cost and selling values.

#### FR-22: Purchase Recording
Users with relevant permissions shall be able to record purchases and update stock.

#### FR-23: Damage Reporting
The system shall support damage entries that reduce inventory and record the effect on stock.

#### FR-24: Inventory Adjustment
The system shall allow stock adjustments necessary for business operations.

### 5.6 Supplier Management
#### FR-25: Supplier Registry
Admins shall be able to add and manage suppliers.

#### FR-26: Supplier Linkage
Purchases shall be linked to supplier records when available.

#### FR-27: Supplier Search and Filtering
The system shall allow filtering and identifying suppliers by tenant and business context.

### 5.7 Reporting and Analytics
#### FR-28: Inventory Overview
The system shall provide an inventory summary with key values and stock levels.

#### FR-29: Profit Reports
The system shall support daily, monthly, and yearly profit reporting.

#### FR-30: Transaction Views
Users shall be able to view sales and purchase transactions in relevant screens.

#### FR-31: Dashboard Statistics
The system shall provide summary metrics for business operations.

### 5.8 Audit and Security Logs
#### FR-32: Activity Logging
The system shall log significant user and business actions for auditing purposes.

#### FR-33: Password View Logs
Whenever a password is viewed, the system shall record the event, including who accessed it and when.

#### FR-34: Audit Access
Users with proper authority shall be able to review audit trails.

### 5.9 App Distribution and Download
#### FR-35: APK Hosting
The system shall host downloadable mobile app files from a secure backend endpoint.

#### FR-36: Release Metadata
The system shall provide app release metadata such as version name, version code, file name, and notes.

#### FR-37: Download Access
Users shall be able to download the mobile app from the app or web experience.

---

## 6. Non-Functional Requirements

### 6.1 Security
- All sensitive operations shall require authentication and authorization.
- Passwords shall not be stored in plain text.
- Tenant data shall be isolated and protected by query and role boundaries.
- API traffic shall be rate-limited.
- CORS and origin restrictions shall be enforced.
- Sensitive logs and secrets shall be kept in environment variables.

### 6.2 Performance
- API responses should be fast for normal operational use.
- Inventory and report queries should support common business operations without excessive delays.
- The system shall support multiple concurrent users in a single tenant.

### 6.3 Usability
- The interface shall be simple enough for business users with minimal technical experience.
- All primary operations shall be accessible in a few steps from the dashboard.
- Role-specific dashboards shall help users focus on relevant functions.

### 6.4 Reliability
- The system shall handle invalid data inputs gracefully.
- Database operations shall fail safely and return meaningful error messages.
- Critical actions shall be tracked in audit logs.

### 6.5 Scalability
- The architecture shall support multiple tenants without major code changes.
- The system shall be able to accommodate additional products, users, and transactions over time.

### 6.6 Compatibility
- The backend shall support standard RESTful API traffic.
- The frontend shall work across web and mobile contexts.
- The system shall support Android app deployment and browser-based access.

---

## 7. Data Requirements

### 7.1 Core Entities
The system shall maintain data for the following entities:
- User
- Tenant
- Category
- Product
- Sale
- Purchase
- Damage
- Supplier
- Audit Log
- Password View Log

### 7.2 Data Security
- Tenant records shall be scoped by tenantId.
- User permissions shall be enforced for all protected actions.
- Password reveal operations shall be restricted to authorized roles.

### 7.3 Data Integrity
- Product, sales, and purchase values shall be validated before saving.
- Stock updates shall remain consistent with inventory actions.
- Business records shall remain traceable through createdBy and audit references.

---

## 8. User Stories

### 8.1 Developer
- As a developer, I want to create a business so that a tenant can start using the system.
- As a developer, I want to suspend or reactivate a tenant so that I can manage platform-level operations.
- As a developer, I want to view protected passwords when needed so that I can support business-level administration.

### 8.2 Admin
- As an admin, I want to create employees so that workers can access the business system.
- As an admin, I want to assign permissions so that responsibilities are properly controlled.
- As an admin, I want to record sales so that the business can track revenue and stock movement.
- As an admin, I want to view profit reports so that I can evaluate business performance.

### 8.3 Employee
- As an employee, I want to view available stock so that I can support daily operations.
- As an employee, I want to record sales and purchases so that inventory stays accurate.
- As an employee, I want to access allowed reports so that I can contribute to business monitoring.

---

## 9. System Constraints

- The application uses Node.js and Express.js on the backend.
- MongoDB is the primary data store.
- Flutter is used for the frontend application.
- The system depends on environment-based configuration and secrets.
- The system is designed around role hierarchy and tenant ownership.

---

## 10. Assumptions and Dependencies

### 10.1 Assumptions
- Each tenant is managed by at least one admin user.
- Developers are the platform-level administrators.
- The business environment uses a single shared backend with isolated dataset boundaries.
- Users are authenticated with token-based sessions.

### 10.2 Dependencies
- MongoDB instance or Atlas deployment
- Node.js runtime
- Flutter SDK for frontend development
- Environment variables for secrets and app configuration
- App packaging support for Android distribution

---

## 11. Acceptance Criteria

### 11.1 Login and Access
- A user can log in using the shared login form.
- The system routes the user correctly based on role.
- Unauthorized users cannot access protected endpoints.

### 11.2 Tenant Management
- A developer can create, suspend, reactivate, and delete tenants.
- Tenant data remains isolated from other tenants.

### 11.3 Inventory Management
- An admin can create categories and products.
- Product stock can be updated via purchase, sale, and damage entries.
- Low-stock products are identifiable.

### 11.4 Reporting
- Daily, monthly, and yearly profitability reports can be generated.
- Sales and purchases can be reviewed through the application.

### 11.5 Security and Audit
- Sensitive passwords are protected and logged when viewed.
- Audit entries are created for user and tenant operations.

### 11.6 App Delivery
- An APK can be built and served through the backend download endpoint.
- Release metadata is available to the client application.

---

## 12. Future Enhancements
- Email notifications and reminders
- Automated low-stock restock suggestions
- Advanced analytics and charts
- Integration with external accounting tools
- Multiple warehouse support
- Offline sync for mobile devices
- Payment and invoice management

---

## 13. Summary
This system is a role-based, multi-tenant inventory and business management platform designed for secure business operations. It covers user administration, inventory control, sales and purchase processing, issue tracking, reporting, audit compliance, and app distribution. It is suitable for small to medium businesses that need centralized management while preserving tenant isolation and role-based access.
