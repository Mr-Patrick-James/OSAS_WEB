<?php
// Landing page — no session logic here to avoid logout redirect loops.
// Auto-login redirect is handled by login_page.php only.
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OSAS - Office of Student Affairs and Services</title>
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#D4AF37">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root {
            --primary: #D4AF37;
            --primary-dark: #B8860B;
            --primary-light: #FFDF6B;
            --radius: 12px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        html { scroll-behavior: smooth; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f8f9fa;
            color: #1a1a1a;
            -webkit-font-smoothing: antialiased;
        }

        body.dark {
            background: #0a0a0a;
            color: #fff;
        }

        /* ── NAVBAR ── */
        .navbar {
            position: fixed;
            top: 0; left: 0; right: 0;
            z-index: 100;
            padding: 1.25rem 2.5rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            transition: var(--transition);
        }

        .navbar.scrolled {
            background: rgba(255,255,255,0.97);
            backdrop-filter: blur(20px);
            border-bottom: 1px solid #e5e7eb;
            padding: 0.9rem 2.5rem;
        }

        .nav-brand {
            display: flex;
            align-items: center;
            gap: 0.6rem;
            text-decoration: none;
        }

        .nav-brand-icon {
            width: 36px; height: 36px;
            background: rgba(212,175,55,0.15);
            border: 1px solid rgba(212,175,55,0.4);
            border-radius: 8px;
            display: flex; align-items: center; justify-content: center;
            overflow: hidden;
        }

        .nav-brand-icon img { width: 100%; height: 100%; object-fit: contain; }

        .nav-brand-text {
            font-size: 0.85rem;
            font-weight: 600;
            color: #1a1a1a;
            line-height: 1.2;
        }

        .nav-brand-sub {
            font-size: 0.7rem;
            color: #6b7280;
            font-weight: 400;
        }

        .nav-links {
            display: flex;
            align-items: center;
            gap: 2.5rem;
            list-style: none;
        }

        .nav-links a {
            color: #4b5563;
            text-decoration: none;
            font-size: 0.9rem;
            font-weight: 500;
            transition: color 0.2s;
        }

        .nav-links a:hover { color: #1a1a1a; }

        .btn-signin {
            padding: 0.55rem 1.4rem;
            background: transparent;
            border: 1.5px solid #1a1a1a;
            color: #1a1a1a;
            border-radius: 8px;
            font-size: 0.875rem;
            font-weight: 500;
            text-decoration: none;
            transition: var(--transition);
        }

        .btn-signin:hover {
            background: #1a1a1a;
            color: #fff;
        }

        /* ── HERO ── */
        .hero {
            position: relative;
            height: 100vh;
            min-height: 600px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            text-align: center;
            overflow: hidden;
        }

        .hero-bg {
            position: absolute;
            inset: 0;
            background: url('app/assets/img/background.jpg') center/cover no-repeat;
            transform: scale(1.05);
            animation: slowZoom 20s ease-in-out infinite alternate;
        }

        @keyframes slowZoom {
            from { transform: scale(1.05); }
            to   { transform: scale(1.12); }
        }

        .hero-overlay {
            position: absolute;
            inset: 0;
            background: linear-gradient(
                to bottom,
                rgba(0,0,0,0.55) 0%,
                rgba(0,0,0,0.45) 50%,
                rgba(0,0,0,0.75) 100%
            );
        }

        .hero-content {
            position: relative;
            z-index: 2;
            max-width: 780px;
            padding: 0 1.5rem;
            animation: fadeUp 1s ease forwards;
        }

        @keyframes fadeUp {
            from { opacity: 0; transform: translateY(30px); }
            to   { opacity: 1; transform: translateY(0); }
        }

        .hero-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(255,255,255,0.1);
            border: 1px solid rgba(255,255,255,0.2);
            backdrop-filter: blur(10px);
            color: rgba(255,255,255,0.9);
            font-size: 0.75rem;
            font-weight: 600;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            padding: 0.45rem 1.1rem;
            border-radius: 999px;
            margin-bottom: 1.75rem;
        }

        .hero-badge span { color: var(--primary-light); }

        .hero-title {
            font-size: clamp(2.8rem, 6vw, 5rem);
            font-weight: 800;
            line-height: 1.08;
            letter-spacing: -0.02em;
            margin-bottom: 1.5rem;
            color: #fff;
        }

        .hero-title .accent {
            color: var(--primary);
            display: block;
        }

        .hero-desc {
            font-size: 1.1rem;
            color: rgba(255,255,255,0.7);
            line-height: 1.7;
            max-width: 560px;
            margin: 0 auto 2.5rem;
        }

        .hero-actions {
            display: flex;
            gap: 1rem;
            justify-content: center;
            flex-wrap: wrap;
        }

        .btn-access {
            padding: 0.85rem 2rem;
            background: var(--primary);
            color: #0a0a0a;
            border: none;
            border-radius: 10px;
            font-size: 0.95rem;
            font-weight: 700;
            text-decoration: none;
            transition: var(--transition);
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn-access:hover {
            background: var(--primary-light);
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(212,175,55,0.4);
        }

        .btn-learn {
            padding: 0.85rem 2rem;
            background: rgba(255,255,255,0.1);
            color: #fff;
            border: 1.5px solid rgba(255,255,255,0.3);
            border-radius: 10px;
            font-size: 0.95rem;
            font-weight: 600;
            text-decoration: none;
            backdrop-filter: blur(8px);
            transition: var(--transition);
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn-learn:hover {
            background: rgba(255,255,255,0.2);
            border-color: rgba(255,255,255,0.5);
            transform: translateY(-2px);
        }

        /* scroll indicator */
        .scroll-hint {
            position: absolute;
            bottom: 2rem;
            left: 50%;
            transform: translateX(-50%);
            z-index: 2;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 0.4rem;
            color: rgba(255,255,255,0.4);
            font-size: 0.7rem;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            animation: bounce 2s ease-in-out infinite;
        }

        @keyframes bounce {
            0%,100% { transform: translateX(-50%) translateY(0); }
            50%      { transform: translateX(-50%) translateY(6px); }
        }

        /* ── FEATURES ── */
        .features {
            background: #f1f5f9;
            padding: 6rem 2rem;
        }

        .section-label {
            text-align: center;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--primary);
            margin-bottom: 1rem;
        }

        .section-title {
            text-align: center;
            font-size: clamp(1.8rem, 3.5vw, 2.6rem);
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 0.75rem;
        }

        .section-sub {
            text-align: center;
            color: #6b7280;
            font-size: 1rem;
            max-width: 520px;
            margin: 0 auto 3.5rem;
            line-height: 1.6;
        }

        .features-grid {
            max-width: 1100px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
        }

        .feature-card {
            background: #ffffff;
            border: 1px solid #e5e7eb;
            border-radius: 16px;
            padding: 2rem;
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .feature-card::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0;
            height: 2px;
            background: linear-gradient(90deg, var(--primary), var(--primary-light));
            transform: scaleX(0);
            transform-origin: left;
            transition: transform 0.35s ease;
        }

        .feature-card:hover {
            background: #fff;
            border-color: var(--primary);
            transform: translateY(-4px);
            box-shadow: 0 8px 30px rgba(212,175,55,0.15);
        }

        .feature-card:hover::before { transform: scaleX(1); }

        .feature-icon {
            width: 52px; height: 52px;
            background: rgba(212,175,55,0.12);
            border: 1px solid rgba(212,175,55,0.25);
            border-radius: 12px;
            display: flex; align-items: center; justify-content: center;
            font-size: 1.3rem;
            color: var(--primary);
            margin-bottom: 1.25rem;
        }

        .feature-card h3 {
            font-size: 1.05rem;
            font-weight: 600;
            color: #1a1a1a;
            margin-bottom: 0.6rem;
        }

        .feature-card p {
            font-size: 0.9rem;
            color: #6b7280;
            line-height: 1.6;
        }

        /* ── FOOTER ── */
        .footer {
            background: #ffffff;
            border-top: 1px solid #e5e7eb;
            padding: 3.5rem 2rem 1.5rem;
        }

        .footer-grid {
            max-width: 1100px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 2fr 1fr 1.5fr;
            gap: 3rem;
            margin-bottom: 2.5rem;
        }

        .footer-brand p {
            color: #6b7280;
            font-size: 0.875rem;
            line-height: 1.7;
            margin-top: 0.75rem;
            max-width: 300px;
        }

        .footer-col h5 {
            font-size: 0.8rem;
            font-weight: 700;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--primary);
            margin-bottom: 1rem;
        }

        .footer-col ul { list-style: none; }

        .footer-col ul li {
            margin-bottom: 0.6rem;
            font-size: 0.875rem;
            color: #6b7280;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .footer-col ul li a {
            color: #6b7280;
            text-decoration: none;
            transition: color 0.2s;
        }

        .footer-col ul li a:hover { color: var(--primary); }

        .footer-col ul li i { color: var(--primary); font-size: 0.8rem; }

        .footer-bottom {
            max-width: 1100px;
            margin: 0 auto;
            padding-top: 1.5rem;
            border-top: 1px solid #e5e7eb;
            text-align: center;
            font-size: 0.8rem;
            color: #9ca3af;
        }

        /* ── THEME TOGGLE BUTTON ── */
        .btn-theme {
            width: 36px; height: 36px;
            border-radius: 8px;
            border: 1.5px solid rgba(0,0,0,0.2);
            background: rgba(0,0,0,0.05);
            color: #4b5563;
            display: flex; align-items: center; justify-content: center;
            cursor: pointer;
            font-size: 0.9rem;
            transition: var(--transition);
            flex-shrink: 0;
        }
        .btn-theme:hover {
            background: rgba(0,0,0,0.1);
        }
        /* ── DARK MODE explicit overrides (body.dark) ── */
        body.dark .features { background: #0f0f0f; }
        body.dark .section-title { color: #fff; }
        body.dark .section-sub   { color: rgba(255,255,255,0.5); }
        body.dark .feature-card  { background: rgba(255,255,255,0.04); border-color: rgba(255,255,255,0.08); }
        body.dark .feature-card:hover { background: rgba(255,255,255,0.07); border-color: rgba(212,175,55,0.3); }
        body.dark .feature-card h3 { color: #fff; }
        body.dark .feature-card p  { color: rgba(255,255,255,0.5); }
        body.dark .footer          { background: #080808; border-top-color: rgba(255,255,255,0.07); }
        body.dark .footer-brand p  { color: rgba(255,255,255,0.45); }
        body.dark .footer-col ul li     { color: rgba(255,255,255,0.5); }
        body.dark .footer-col ul li a   { color: rgba(255,255,255,0.5); }
        body.dark .footer-col ul li a:hover { color: var(--primary); }
        body.dark .footer-bottom { border-top-color: rgba(255,255,255,0.07); color: rgba(255,255,255,0.3); }
        body.dark .nav-brand-text { color: rgba(255,255,255,0.9); }
        body.dark .nav-brand-sub  { color: rgba(255,255,255,0.45); }
        body.dark .nav-links a    { color: rgba(255,255,255,0.75); }
        body.dark .nav-links a:hover { color: #fff; }
        body.dark .btn-signin     { border-color: rgba(255,255,255,0.6); color: #fff; }
        body.dark .btn-signin:hover { background: #fff; color: #0a0a0a; }
        body.dark .btn-theme      { border-color: rgba(255,255,255,0.35); background: rgba(255,255,255,0.08); color: rgba(255,255,255,0.85); }
        body.dark .navbar.scrolled { background: rgba(10,10,10,0.92); border-bottom-color: rgba(255,255,255,0.08); }

        @media (max-width: 768px) {
            .navbar { padding: 1rem 1.25rem; }
            .nav-links { display: none; }
            .hero-title { font-size: 2.4rem; }
            .footer-grid { grid-template-columns: 1fr; gap: 2rem; }
        }
    </style>
</head>
<body>

<!-- NAVBAR -->
<nav class="navbar" id="navbar">
    <a href="#" class="nav-brand">
        <div class="nav-brand-icon">
            <img src="./app/assets/img/default.png" alt="OSAS">
        </div>
        <div>
            <div class="nav-brand-text">E-OSAS</div>
            <div class="nav-brand-sub">Student Affairs System</div>
        </div>
    </a>

    <ul class="nav-links">
        <li><a href="#features">Features</a></li>
        <li><a href="#contact">Contact</a></li>
    </ul>

    <div style="display:flex;align-items:center;gap:0.6rem;">
        <button class="btn-theme" id="themeToggle" title="Toggle theme">
            <i class="fas fa-sun" id="themeIcon"></i>
        </button>
        <a href="login_page.php?force_login=true" class="btn-signin">Sign In</a>
    </div>
</nav>

<!-- HERO -->
<section class="hero">
    <div class="hero-bg"></div>
    <div class="hero-overlay"></div>

    <div class="hero-content">
        <div class="hero-badge">
            <i class="fas fa-map-marker-alt"></i>
            Colegio de Naujan &nbsp;·&nbsp; <span>Santiago, Oriental Mindoro</span>
        </div>

        <h1 class="hero-title">
            Empowering Students,
            <span class="accent">Elevating Services</span>
        </h1>

        <p class="hero-desc">
            The official student affairs management system of Colegio de Naujan — digitally managing violations, records, and student welfare for a better campus experience.
        </p>

        <div class="hero-actions">
            <a href="login_page.php?force_login=true" class="btn-access">
                <i class="fas fa-sign-in-alt"></i> Access System
            </a>
            <a href="#features" class="btn-learn">
                Learn More <i class="fas fa-chevron-down"></i>
            </a>
        </div>
    </div>

    <div class="scroll-hint">
        <span>Scroll</span>
        <i class="fas fa-chevron-down"></i>
    </div>
</section>

<!-- FEATURES -->
<section class="features" id="features">
    <div class="section-label">What We Offer</div>
    <h2 class="section-title">Everything in One Place</h2>
    <p class="section-sub">Tools designed to streamline student affairs management and keep everything organized.</p>

    <div class="features-grid">
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-user-graduate"></i></div>
            <h3>Student Profiles</h3>
            <p>Centralized student records with profile details, photos, and account access management.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-shield-alt"></i></div>
            <h3>Violation Tracking</h3>
            <p>Monitor violations, view histories, and keep discipline records organized and accessible.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-bullhorn"></i></div>
            <h3>Announcements</h3>
            <p>Publish and broadcast announcements to notify students of important updates instantly.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-chart-line"></i></div>
            <h3>Reports & Exports</h3>
            <p>Generate detailed reports and export data as PDF, Excel, or Word for documentation.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-layer-group"></i></div>
            <h3>Sections & Departments</h3>
            <p>Organize the academic structure with full section and department management tools.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon"><i class="fas fa-user-shield"></i></div>
            <h3>Role-Based Access</h3>
            <p>Separate admin and student portals with secure, permission-based access control.</p>
        </div>
    </div>
</section>

<!-- FOOTER -->
<footer class="footer" id="contact">
    <div class="footer-grid">
        <div class="footer-brand">
            <a href="#" class="nav-brand" style="text-decoration:none;">
                <div class="nav-brand-icon">
                    <img src="./app/assets/img/default.png" alt="OSAS">
                </div>
                <div>
                    <div class="nav-brand-text">E-OSAS</div>
                    <div class="nav-brand-sub">Colegio de Naujan</div>
                </div>
            </a>
            <p>The Office of Student Affairs and Services provides comprehensive support for student development and welfare through innovative digital solutions.</p>
        </div>

        <div class="footer-col">
            <h5>Quick Links</h5>
            <ul>
                <li><a href="login_page.php?force_login=true"><i class="fas fa-sign-in-alt"></i> Login</a></li>
                <li><a href="#features"><i class="fas fa-star"></i> Features</a></li>
                <li><a href="#contact"><i class="fas fa-envelope"></i> Contact</a></li>
            </ul>
        </div>

        <div class="footer-col">
            <h5>Contact</h5>
            <ul>
                <li><i class="fas fa-envelope"></i> osas@colegiodenaujan.edu.ph</li>
                <li><i class="fas fa-phone"></i> +63 998 913 4594</li>
                <li><i class="fas fa-map-marker-alt"></i> Santiago, Naujan, Oriental Mindoro</li>
            </ul>
        </div>
    </div>

    <div class="footer-bottom">
        &copy; 2026 E-OSAS &mdash; Office of Student Affairs and Services, Colegio de Naujan. All rights reserved.
    </div>
</footer>

<script>
    // Navbar scroll effect
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        navbar.classList.toggle('scrolled', window.scrollY > 60);
    });

    // ── THEME TOGGLE ──
    const themeToggle = document.getElementById('themeToggle');
    const themeIcon   = document.getElementById('themeIcon');
    const body        = document.body;

    // Use the same key as login.js ('theme'), default to light to match login page default
    const savedTheme = localStorage.getItem('theme') || 'light';
    applyTheme(savedTheme);

    themeToggle.addEventListener('click', () => {
        const next = body.classList.contains('light') ? 'dark' : 'light';
        applyTheme(next);
        localStorage.setItem('theme', next);
    });

    function applyTheme(theme) {
        if (theme === 'light') {
            body.classList.add('light');
            body.classList.remove('dark');
            themeIcon.className = 'fas fa-moon';
            themeToggle.title = 'Switch to dark mode';
        } else {
            body.classList.remove('light');
            body.classList.add('dark');
            themeIcon.className = 'fas fa-sun';
            themeToggle.title = 'Switch to light mode';
        }
    }

    // Feature card entrance animation
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('.feature-card').forEach((card, i) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(24px)';
        card.style.transition = `opacity 0.5s ease ${i * 0.08}s, transform 0.5s ease ${i * 0.08}s`;
        observer.observe(card);
    });
</script>
</body>
</html>
