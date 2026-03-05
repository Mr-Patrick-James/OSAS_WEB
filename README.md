# <p align="center">🌐 E-OSAS WEB SYSTEM</p>

<p align="center">
  <img src="https://img.shields.io/badge/PHP-7.4+-777BB4?style=for-the-badge&logo=php&logoColor=white" />
  <img src="https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white" />
  <img src="https://img.shields.io/badge/PWA-5A0FC8?style=for-the-badge&logo=pwa&logoColor=white" />
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<p align="center">
  <b>A comprehensive, modern, and highly-scalable management solution for the Office of Student Affairs and Services.</b>
  <br />
  <i>Empowering campus management through automation, real-time tracking, and AI-driven support.</i>
</p>

---

## 🚀 Overview

The **E-OSAS WEB SYSTEM** is a full-stack, enterprise-ready platform designed to centralize and automate student affairs operations. Built with a custom MVC architecture, it provides seamless management for departments, violations, and student records while offering students a personalized dashboard and AI assistance.

---

## ✨ Key Features

### 🔐 Enterprise-Grade Security
*   **Multi-Factor Authentication (OTP):** Secure account creation with email-based One-Time Passwords via **PHPMailer**.
*   **Role-Based Access Control (RBAC):** Granular permissions for Administrators and Students.
*   **Session Resilience:** Robust session management with persistent login support via encrypted cookies.
*   **Data Integrity:** Secure password hashing using **BCRYPT** and prepared SQL statements to prevent injection.

### 📊 Advanced Administration
*   **Real-time Analytics:** Visualized system data using **Chart.js** for violation trends and student demographics.
*   **Automated Document Generation:** Export violation reports and official letters directly to **.docx** and **.pdf** formats.
*   **Academic Hierarchy:** Seamless management of Departments and Sections.
*   **Digital Evidence:** Support for student profile images and violation photo evidence.

### 👤 Student Experience
*   **Interactive Dashboard:** At-a-glance view of active violations, clean-day streaks, and campus updates.
*   **Self-Service Profile:** Independent management of personal details and **secure password updates**.
*   **Smart Assistant:** Integrated **AI Chatbot** to provide instant answers to common student inquiries.

### 📱 Progressive Web App (PWA)
*   **Installability:** Cross-platform installation on Android, iOS, and Desktop.
*   **Reliability:** Service worker integration for fast loading and offline data access.
*   **UX-First Design:** Fully responsive interface optimized for all screen sizes.

---

## 🏗️ System Architecture

```text
OSAS_WEB/
├── 🔌 api/                  # RESTful API Endpoints (JSON-driven)
├── ⚙️ app/                  # Core MVC Engine
│   ├── 🛠️ core/             # Base Framework (Model, Controller, Router, View)
│   ├── 📦 models/           # Data Abstraction & Database Logic
│   ├── 🎮 controllers/      # Application Logic & Request Handling
│   ├── 🖼️ views/             # Template Engine & UI Components
│   └── 🎨 assets/           # Client-side Resources (SASS/JS/Images)
├── 📂 config/               # Global Environment & Connection Configs
├── 📜 migrations/           # Version-controlled Database Schemas
└── 🚀 index.php             # Unified Entry Point
```

---

## ⚙️ Tech Stack

| Component | Technology |
| :--- | :--- |
| **Language** | PHP 7.4+ |
| **Database** | MySQL / MariaDB |
| **Frontend** | HTML5, CSS3, JavaScript (ES6+) |
| **Architecture** | Custom MVC Framework |
| **Libraries** | PHPMailer, PHPWord, Chart.js, jsPDF, Puter.js |
| **Mobile** | Progressive Web App (PWA) |

---

## 🛠️ Quick Start

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/your-repo/osas-web.git
    ```
2.  **Environment Setup:**
    -   Import `migrations/osas.sql` into your MySQL database.
    -   Configure `config/db_connect.php` with your database credentials.
3.  **Dependency Installation:**
    ```bash
    composer install
    ```
4.  **Run locally:**
    -   Serve via WAMP/XAMPP or any PHP-compatible web server.

---

## 🤝 Contribution

We welcome contributions to the E-OSAS ecosystem!
-   **Bug Reports:** Open an issue to report any system anomalies.
-   **Feature Requests:** Suggest new tools or improvements.
-   **Code:** Submit pull requests for bug fixes or feature implementations.

---

<p align="center">
  Made with ❤️ for Academic Excellence.
</p>
