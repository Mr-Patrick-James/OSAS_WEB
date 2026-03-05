# 🌐 OSAS WEB SYSTEM

A modern, full-stack web-based system designed for the **Office of Student Affairs and Services (OSAS)** to manage departments, sections, students, violations, and reports — all in one centralized platform.

---

## 📁 Project Structure

```text
OSAS_WEB/
├── api/                      # API endpoints (announcements, dashboard, settings, students, etc.)
├── app/                      # Main application logic
│   ├── assets/               # Static assets
│   │   ├── img/              # Images (students, violations, system defaults)
│   │   ├── js/               # JavaScript files (modules, utils, dashboard logic)
│   │   └── styles/           # CSS stylesheets
│   ├── config/               # Configuration files (AI config, DB connect)
│   ├── controllers/          # MVC Controllers (Auth, Student, Violation, etc.)
│   ├── core/                 # Core framework classes (Model, Controller, Session, View, Router)
│   ├── entry/                # Dashboard entry points (dashboard.php, user_dashboard.php)
│   ├── models/               # MVC Models (StudentModel, ViolationModel, UserModel, etc.)
│   └── views/                # MVC Views
│       ├── admin/            # Admin interface views
│       ├── auth/             # Authentication views (login, register, OTP)
│       ├── layouts/          # Layout templates (admin, user)
│       ├── partials/         # Reusable view components (sidebar, topnav)
│       └── user/             # Student/User interface views
├── config/                   # Root level configuration
├── includes/                 # Root level dashboard and signup includes
├── migrations/               # SQL database migration files
├── scripts/                  # Utility scripts (data population, parsing)
├── index.php                 # Main entry point (Login page)
├── manifest.json             # PWA manifest
└── service-worker.js         # PWA service worker
```

---

## ✨ Features

### 🔐 Authentication & Authorization
* **User Authentication:** Secure login and registration system.
* **OTP Verification:** Email-based One-Time Password for enhanced security.
* **Session Management:** PHP-based session handling with cookie restoration support.
* **Role-Based Access:** Distinct admin and student (user) dashboards.
* **Password Security:** Secure password hashing (BCRYPT) and management.

### 📊 Admin Dashboard
* **Dashboard Overview:** Real-time system statistics and analytics.
* **Department & Section Management:** Organize students by academic structure.
* **Student Records:** Comprehensive student management with profile images.
* **Violation Tracking:** Record and monitor student violations with image evidence.
* **Reports & Analytics:** Generate detailed summaries and exportable reports.
* **System Settings:** Centralized configuration for system-wide preferences.

### 👤 Student Dashboard
* **Personalized Overview:** Quick view of active violations and account status.
* **My Violations:** Detailed history of personal violation records.
* **Announcements:** Stay updated with the latest system and campus announcements.
* **Account Settings:** Update profile picture, username, and **change password** securely.

### 🤖 Smart Features
* **AI Chatbot:** Integrated support assistant for student inquiries.
* **Announcement System:** Real-time updates for important information.

### 📱 Progressive Web App (PWA)
* **Installable:** Install as a mobile or desktop application.
* **Offline Support:** Service worker for basic offline functionality.
* **Responsive Design:** Optimized for mobile, tablet, and desktop viewports.

---

## ⚙️ Technologies Used

* **Frontend:**
  * HTML5 & CSS3
  * JavaScript (ES6+)
  * Chart.js (for analytics and reports)
  * Boxicons & Font Awesome (icons)
  * PWA (Service Workers, Manifest)

* **Backend:**
  * PHP 7.4+ (MVC Architecture)
  * MySQL/MariaDB
  * Composer (Dependency Management)
  * PHPMailer (Email notifications/OTP)
  * PHPWord (Document generation)

* **Tools & Libraries:**
  * Docxtemplater & Pizzip (Client-side document processing)
  * jsPDF (PDF generation)
  * Puter.js (Cloud-based storage/utilities)
