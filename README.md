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

### 🔐 Authentication & Authorization
*   **User Authentication:** Secure login and registration system.
*   **Session Management:** PHP-based session handling with cookie restoration support.
*   **Role-Based Access Control (RBAC):** Distinct admin and student (user) dashboards.
*   **Data Integrity:** Secure password hashing (BCRYPT) and management.

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
| **Backend** | PHP 7.4+ (MVC Architecture) |
| **Database** | MySQL / MariaDB |
| **Tools** | Composer (Dependency Management), PHPWord |

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

## 🚀 AWS / Production Deployment

After every `git pull` or `git reset --hard origin/main` on the server:

```bash
# Ensure the violation evidence upload folder exists with correct permissions
mkdir -p /var/www/html/app/assets/img/violations
sudo chown -R www-data:www-data /var/www/html/app/assets/img/violations
sudo chmod -R 755 /var/www/html/app/assets/img/violations
```

> **Note:** The `violations/` folder is tracked via `.gitkeep` but uploaded images are git-ignored. Permissions must be set manually after each fresh deploy or server migration.

---

## ⚠️ Critical: Service Worker `BUILD_DATE` — Do NOT Change Casually

The `service-worker.js` file contains a `BUILD_DATE` constant at the top:

```js
const BUILD_DATE = '2026-07-30-push-icon-path-fix';
const CACHE_NAME = 'osas-cache-' + BUILD_DATE;
const API_CACHE  = 'osas-api-'   + BUILD_DATE;
```

### What happens when you change it

Changing `BUILD_DATE` causes the browser to treat the service worker as a **new version**. On activation, it **deletes ALL existing caches** (`osas-cache-*` and `osas-api-*`) on every connected device. This means:

- Every user loses their offline-cached violations, students, and page data
- Any device that goes offline before re-visiting all pages will show **blank/empty data**
- Both mobile and desktop PWA users are affected

### When you SHOULD change it

Only change `BUILD_DATE` when you make **breaking asset changes** that require all devices to re-download everything:
- Renaming or moving CSS/JS files
- Changing asset paths or filenames
- Major structural changes to cached HTML/PHP pages

### When you should NOT change it

**Never change `BUILD_DATE` for normal code changes**, including:
- PHP logic fixes and bug patches
- JavaScript feature additions or bug fixes
- CSS styling changes
- API response changes
- Any server-side only changes

Normal code changes are picked up automatically on next page load via standard HTTP caching — the service worker cache does not need to be invalidated.

### Recovery

If `BUILD_DATE` was changed accidentally and offline mode is broken on user devices, the only recovery is for users to:
1. Visit the site while online
2. Browse to the violations and students pages to re-populate the offline cache
3. Then offline mode will work again

---

## 🤝 Contribution

We welcome contributions to the E-OSAS ecosystem!
-   **Bug Reports:** Open an issue to report any system anomalies.
-   **Feature Requests:** Suggest new tools or improvements.
-   **Code:** Submit pull requests for bug fixes or feature implementations.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 E-OSAS WEB SYSTEM

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<p align="center">
  Made with ❤️ for Academic Excellence.
</p>
