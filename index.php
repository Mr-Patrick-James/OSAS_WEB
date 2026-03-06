<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OSAS - Office of Student Affairs and Services</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        /* Clean Modern Design Variables */
        :root {
            --primary: #D4AF37;
            --primary-dark: #B8860B;
            --primary-light: #FFDF6B;
            --text-primary: #1a1a1a;
            --text-secondary: #6b7280;
            --text-light: #9ca3af;
            --bg-white: #ffffff;
            --bg-gray: #f9fafb;
            --bg-light: #f3f4f6;
            --border: #e5e7eb;
            --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
            --radius: 12px;
            --radius-lg: 16px;
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: var(--text-primary);
            background: var(--bg-white);
            font-size: 16px;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        /* Clean Navigation */
        .navbar {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(20px);
            border-bottom: 1px solid var(--border);
            z-index: 1000;
            transition: var(--transition);
        }

        .navbar.scrolled {
            background: rgba(255, 255, 255, 0.98);
            box-shadow: var(--shadow-md);
        }

        .nav-container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 1rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--primary);
            text-decoration: none;
        }

        .logo-icon {
            width: 40px;
            height: 40px;
            background: var(--primary);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 1.2rem;
        }

        .nav-buttons {
            display: flex;
            gap: 1rem;
            align-items: center;
        }

        .btn {
            padding: 0.625rem 1.25rem;
            border-radius: var(--radius);
            text-decoration: none;
            font-weight: 500;
            font-size: 0.875rem;
            transition: var(--transition);
            cursor: pointer;
            border: none;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn-outline {
            background: transparent;
            color: var(--primary);
            border: 1.5px solid var(--primary);
        }

        .btn-outline:hover {
            background: var(--primary);
            color: white;
            transform: translateY(-1px);
            box-shadow: var(--shadow-md);
        }

        .btn-primary {
            background: var(--primary);
            color: white;
            border: 1.5px solid var(--primary);
        }

        .btn-primary:hover {
            background: var(--primary-dark);
            border-color: var(--primary-dark);
            transform: translateY(-1px);
            box-shadow: var(--shadow-lg);
        }

        /* Hero Section */
        .hero {
            padding: 8rem 2rem 4rem;
            background: linear-gradient(135deg, var(--bg-white) 0%, var(--bg-gray) 100%);
            position: relative;
            overflow: hidden;
        }

        .hero::before {
            content: '';
            position: absolute;
            top: 0;
            left: -50%;
            width: 200%;
            height: 100%;
            background: url('app/assets/img/background.jpg') center/cover;
            opacity: 0.15;
            animation: slideBackground 20s ease-in-out infinite;
            z-index: 0;
        }

        @keyframes slideBackground {
            0%, 100% { 
                transform: translateX(0) translateY(0) scale(1.1); 
            }
            25% { 
                transform: translateX(30px) translateY(-20px) scale(1.15); 
            }
            50% { 
                transform: translateX(-20px) translateY(30px) scale(1.2); 
            }
            75% { 
                transform: translateX(40px) translateY(10px) scale(1.1); 
            }
        }

        .hero::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(ellipse at center, rgba(212, 175, 55, 0.05) 0%, transparent 70%);
            animation: float 20s ease-in-out infinite;
            z-index: 1;
        }

        @keyframes float {
            0%, 100% { transform: translateX(0) translateY(0); }
            50% { transform: translateX(30px) translateY(-20px); }
        }

        .hero-container {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 4rem;
            align-items: center;
            position: relative;
            z-index: 1;
        }

        .hero-content h1 {
            font-size: 3.5rem;
            font-weight: 800;
            line-height: 1.1;
            margin-bottom: 1.5rem;
            color: var(--text-primary);
        }

        .hero-content .highlight {
            color: var(--primary);
            position: relative;
        }

        .hero-content p {
            font-size: 1.25rem;
            color: var(--text-secondary);
            margin-bottom: 2rem;
            line-height: 1.6;
        }

        .hero-buttons {
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
        }

        .btn-hero {
            padding: 1rem 2rem;
            font-size: 1rem;
            border-radius: var(--radius-lg);
        }

        .btn-hero-primary {
            background: var(--primary);
            color: white;
            border: none;
        }

        .btn-hero-primary:hover {
            background: var(--primary-dark);
            transform: translateY(-2px);
            box-shadow: var(--shadow-xl);
        }

        .btn-hero-secondary {
            background: transparent;
            color: var(--primary);
            border: 2px solid var(--primary);
        }

        .btn-hero-secondary:hover {
            background: var(--primary);
            color: white;
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .hero-visual {
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .hero-card {
            background: white;
            border-radius: var(--radius-lg);
            padding: 3rem;
            box-shadow: var(--shadow-xl);
            border: 1px solid var(--border);
            text-align: center;
            max-width: 400px;
            transform: perspective(1000px) rotateY(-5deg);
            transition: var(--transition);
        }

        .hero-card:hover {
            transform: perspective(1000px) rotateY(0deg);
        }

        .hero-icon {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, var(--primary), var(--primary-dark));
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 2rem;
            font-size: 2rem;
            color: white;
            box-shadow: var(--shadow-lg);
        }

        /* Features Section */
        .features {
            padding: 5rem 2rem;
            background: var(--bg-white);
        }

        .section-header {
            text-align: center;
            margin-bottom: 4rem;
            position: relative;
            z-index: 2;
        }

        .section-header h2 {
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 1rem;
            color: var(--text-primary);
        }

        .section-header p {
            font-size: 1.125rem;
            color: var(--text-secondary);
            max-width: 600px;
            margin: 0 auto;
        }

        .features-grid {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 2rem;
        }

        
        .feature-card {
            background: white;
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            padding: 2rem;
            text-align: center;
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .feature-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--primary), var(--primary-light));
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }

        .feature-card:hover::before {
            transform: scaleX(1);
        }

        .feature-card:hover {
            transform: translateY(-4px);
            box-shadow: var(--shadow-xl);
            border-color: var(--primary);
        }

        .feature-icon {
            width: 64px;
            height: 64px;
            background: linear-gradient(135deg, var(--primary), var(--primary-light));
            border-radius: var(--radius);
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1.5rem;
            font-size: 1.5rem;
            color: white;
            box-shadow: var(--shadow-md);
        }

        .feature-card h3 {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 1rem;
            color: var(--text-primary);
        }

        .feature-card p {
            color: var(--text-secondary);
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 2rem;
        }

        
        /* Footer */
        .footer {
            background: #121212de;
            color: white !important;
            padding: 3rem 2rem 1rem;
        }

        .footer-container {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 2rem;
            margin-bottom: 2rem;
        }

        .footer-section h4 {
            color: var(--primary) !important;
            margin-bottom: 1rem;
            font-size: 1.125rem;
            font-weight: 600;
        }

        .footer-section p {
            color: #ffffff !important;
            line-height: 1.6;
            font-size: 0.95rem;
        }

        .footer-section ul {
            list-style: none;
        }

        .footer-section ul li {
            margin-bottom: 0.5rem;
            color: #ffffff !important;
        }

        .footer-section a {
            color: #ffffff !important;
            text-decoration: none;
            transition: color 0.3s ease;
            font-size: 0.95rem;
        }

        .footer-section a:hover {
            color: var(--primary) !important;
        }

        .footer-section .fas {
            color: var(--primary) !important;
            margin-right: 0.5rem;
        }

        .footer-bottom {
            text-align: center;
            padding-top: 2rem;
            border-top: 1px solid rgba(255, 255, 255, 0.2);
            color: #ffffff !important;
            font-size: 0.9rem;
        }

        /* Dark mode footer */
        body.dark .footer {
            background: #141414 !important;
            border-top: 1px solid #2A2A2A !important;
        }

        body.dark .footer-section h4 {
            color: var(--primary) !important;
        }

        body.dark .footer-section p {
            color: #ffffff !important;
        }

        body.dark .footer-section ul li {
            color: #ffffff !important;
        }

        body.dark .footer-section a {
            color: #ffffff !important;
        }

        body.dark .footer-section a:hover {
            color: var(--primary) !important;
        }

        body.dark .footer-section .fas {
            color: var(--primary) !important;
        }

        body.dark .footer-bottom {
            border-top-color: #2A2A2A !important;
            color: #ffffff !important;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
            .hero-container {
                grid-template-columns: 1fr;
                gap: 2rem;
                text-align: center;
            }

            .hero-content h1 {
                font-size: 2.5rem;
            }

            .hero-visual {
                order: -1;
            }

            .hero-card {
                transform: none;
                max-width: 100%;
            }

            .nav-container {
                padding: 1rem;
            }

            .nav-links {
                display: none;
            }

            .nav-buttons {
                gap: 0.5rem;
            }

            .btn {
                padding: 0.5rem 1rem;
                font-size: 0.8rem;
            }

            .features-grid {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 640px) {
            .nav-container {
                padding: 1rem;
            }

            .logo {
                font-size: 1.2rem;
            }

            .logo-icon {
                width: 32px;
                height: 32px;
                font-size: 1rem;
            }

            .hero-content h1 {
                font-size: 2rem;
            }

            .hero-content p {
                font-size: 1rem;
            }

            .hero-buttons {
                flex-direction: column;
                align-items: center;
            }

            .btn-hero {
                width: 100%;
                max-width: 280px;
            }
        }

        /* Animations */
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .fade-in-up {
            animation: fadeInUp 0.8s ease forwards;
        }

        /* Dark mode toggle button */
        #theme-toggle {
            background: rgba(212, 175, 55, 0.1);
            border: 1.5px solid var(--primary);
            color: var(--primary);
            padding: 0.625rem;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: var(--transition);
        }

        #theme-toggle:hover {
            background: var(--primary);
            color: white;
            transform: rotate(180deg);
        }

        /* Light mode (default) */
        body {
            background: var(--bg-white);
            color: var(--text-primary);
        }

        /* Dark mode styles */
        body.dark {
            --text-primary: #FFFFFF;
            --text-secondary: #D0D0D0;
            --text-light: #888888;
            --bg-white: #141414;
            --bg-gray: #0A0A0A;
            --bg-light: #1E1E1E;
            --border: #2A2A2A;
            color: var(--text-primary);
            background: #141414;
        }

        body.dark .navbar {
            background: #141414 !important;
            border-bottom-color: #2A2A2A !important;
        }

        body.dark .navbar.scrolled {
            background: rgba(20, 20, 20, 0.98) !important;
        }

        body.dark .hero {
            background: linear-gradient(135deg, #141414 0%, #0A0A0A 100%);
        }

        body.dark .hero::before {
            opacity: 0.1;
        }

        body.dark .hero::after {
            background: radial-gradient(ellipse at center, rgba(212, 175, 55, 0.08) 0%, transparent 70%);
        }

        body.dark .hero-content h1 {
            color: var(--text-primary);
        }

        body.dark .feature-card,
        body.dark .hero-card {
            background: var(--bg-gray);
            border-color: var(--border);
        }

        body.dark .feature-card h3 {
            color: var(--text-primary);
        }

        body.dark .section-header h2 {
            color: var(--text-primary);
        }

        
        body.dark #theme-toggle {
            background: rgba(212, 175, 55, 0.2);
            border-color: var(--primary);
            color: var(--primary);
        }

        body.dark .nav-links {
            display: flex;
            align-items: center;
            gap: 2rem;
            margin-left: 2rem;
        }

        body.dark .nav-link {
            color: #ffffff;
            text-decoration: none;
            font-weight: 500;
            font-size: 0.95rem;
            transition: color 0.3s ease;
            position: relative;
        }

        body.dark .nav-link::after {
            content: '';
            position: absolute;
            bottom: -2px;
            left: 0;
            width: 0;
            height: 2px;
            background: var(--primary);
            transition: width 0.3s ease;
        }

        body.dark .nav-link:hover {
            color: var(--primary);
        }

        body.dark .nav-link:hover::after {
            width: 100%;
        }

        /* Light mode navigation styles */
        .nav-links {
            display: flex;
            align-items: center;
            gap: 2rem;
            margin-left: 2rem;
        }

        .nav-link {
            color: var(--text-primary);
            text-decoration: none;
            font-weight: 500;
            font-size: 0.95rem;
            transition: color 0.3s ease;
            position: relative;
        }

        .nav-link::after {
            content: '';
            position: absolute;
            bottom: -2px;
            left: 0;
            width: 0;
            height: 2px;
            background: var(--primary);
            transition: width 0.3s ease;
        }

        .nav-link:hover {
            color: var(--primary);
        }

        .nav-link:hover::after {
            width: 100%;
        }

        .nav-buttons {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        body.dark #theme-toggle:hover {
            background: var(--primary);
            color: white;
        }
    </style>
</head>
<body>
    <!-- Navigation -->
    <nav class="navbar" id="navbar">
        <div class="nav-container">
            <a href="#" class="logo">
                <div class="logo-icon">
                    <i class="fas fa-graduation-cap"></i>
                </div>
                <span>OSAS</span>
            </a>
            <div class="nav-links">
                <a href="#features" class="nav-link">Features</a>
                <a href="#contact" class="nav-link">Contact</a>
            </div>
            <div class="nav-buttons">
                <button class="btn btn-outline" id="theme-toggle" title="Toggle dark mode">
                    <i class="fas fa-moon" id="theme-icon"></i>
                </button>
                <a href="login_page.php?direct=true" class="btn btn-outline">
                    <i class="fas fa-sign-in-alt"></i>
                    Login
                </a>
                
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <section class="hero">
        <div class="hero-container">
            <div class="hero-content fade-in-up">
                <h1>Office of <span class="highlight">Student Affairs</span> and Services</h1>
                <p>Comprehensive student management system designed to streamline administrative processes and enhance student experience through innovative technology solutions.</p>
                <div class="hero-buttons">
                    <a href="login_page.php?direct=true" class="btn btn-hero btn-hero-primary">
                        <i class="fas fa-rocket"></i>
                        Get Started
                    </a>
                    <a href="#features" class="btn btn-hero btn-hero-secondary">
                        <i class="fas fa-play-circle"></i>
                        Learn More
                    </a>
                </div>
            </div>
            <div class="hero-visual fade-in-up">
                <div class="hero-card">
                    <div class="hero-icon">
                        <i class="fas fa-graduation-cap"></i>
                    </div>
                    <h3>Empowering Education</h3>
                    <p>Modern solutions for student success and institutional excellence</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Features Section -->
    <section class="features" id="features">
        <div class="section-header">
            <h2>Powerful Features</h2>
            <p>Everything you need to manage student services efficiently</p>
        </div>
        <div class="features-grid">
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-user-graduate"></i>
                </div>
                <h3>Student Profiles</h3>
                <p>Centralized student records with profile details and account access.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-shield-alt"></i>
                </div>
                <h3>Violation Tracking</h3>
                <p>Monitor violations, view histories, and keep discipline records organized.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-bullhorn"></i>
                </div>
                <h3>Announcements</h3>
                <p>Publish announcements and notify users of important updates.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-chart-line"></i>
                </div>
                <h3>Reports & Exports</h3>
                <p>Generate reports and export data for documentation and review.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-layer-group"></i>
                </div>
                <h3>Sections & Departments</h3>
                <p>Organize academic structure with section and department management.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">
                    <i class="fas fa-user-shield"></i>
                </div>
                <h3>Role-Based Access</h3>
                <p>Separate admin and student access with secure permissions.</p>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="footer" id="contact">
        <div class="footer-container">
            <div class="footer-section">
                <h4>About OSAS</h4>
                <p>The Office of Student Affairs and Services provides comprehensive support for student development and welfare through innovative management solutions.</p>
            </div>
            <div class="footer-section">
                <h4>Quick Links</h4>
                <ul>
                    <li><a href="login_page.php?direct=true">Login</a></li>
                    <li><a href="app/views/auth/signup.php">Sign Up</a></li>
                    <li><a href="#features">Features</a></li>
                </ul>
            </div>
            <div class="footer-section">
                <h4>Support</h4>
                <ul>
                    <li><a href="#">Documentation</a></li>
                    <li><a href="#">Help Center</a></li>
                    <li><a href="#">Contact Support</a></li>
                    <li><a href="#">System Status</a></li>
                </ul>
            </div>
            <div class="footer-section">
                <h4>Contact</h4>
                <ul>
                    <li><i class="fas fa-envelope"></i>osas@colegiodenaujan.edu.ph</li>
                    <li><i class="fas fa-phone"></i> +123 456 7890</li>
                    <li><i class="fas fa-map-marker-alt"></i> University Campus</li>
                </ul>
            </div>
        </div>
        <div class="footer-bottom">
            <p>&copy; 2024 OSAS - Office of Student Affairs and Services. All rights reserved.</p>
        </div>
    </footer>

    <script>
        // Dark mode toggle functionality
        const themeToggle = document.getElementById('theme-toggle');
        const themeIcon = document.getElementById('theme-icon');
        const body = document.body;
        
        // Check for saved theme preference
        const currentTheme = localStorage.getItem('theme') || 'light';
        
        // Apply the saved theme on page load
        if (currentTheme === 'dark') {
            body.classList.add('dark');
            themeIcon.classList.remove('fa-moon');
            themeIcon.classList.add('fa-sun');
        }

        // Theme toggle event listener
        themeToggle.addEventListener('click', () => {
            body.classList.toggle('dark');
            
            if (body.classList.contains('dark')) {
                // Switch to dark mode
                themeIcon.classList.remove('fa-moon');
                themeIcon.classList.add('fa-sun');
                localStorage.setItem('theme', 'dark');
                themeToggle.setAttribute('title', 'Switch to light mode');
            } else {
                // Switch to light mode
                themeIcon.classList.remove('fa-sun');
                themeIcon.classList.add('fa-moon');
                localStorage.setItem('theme', 'light');
                themeToggle.setAttribute('title', 'Switch to dark mode');
            }
        });

        // Smooth scrolling
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
        });

        // Navbar scroll effect
        window.addEventListener('scroll', () => {
            const navbar = document.getElementById('navbar');
            if (window.scrollY > 50) {
                navbar.classList.add('scrolled');
                // Force navbar to stay white in light mode
                if (!body.classList.contains('dark')) {
                    navbar.style.background = 'rgba(255, 255, 255, 0.98)';
                    navbar.style.borderBottom = '1px solid #e5e7eb';
                }
            } else {
                navbar.classList.remove('scrolled');
                // Reset to original style
                if (!body.classList.contains('dark')) {
                    navbar.style.background = 'rgba(255, 255, 255, 0.95)';
                    navbar.style.borderBottom = '1px solid #e5e7eb';
                }
            }
        });

        // Intersection Observer for animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }
            });
        }, observerOptions);

        // Observe cards
        document.querySelectorAll('.feature-card').forEach(card => {
            card.style.opacity = '0';
            card.style.transform = 'translateY(30px)';
            card.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
            observer.observe(card);
        });
    </script>
</body>
</html>
