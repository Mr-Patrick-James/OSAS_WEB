/**
 * Chatbot Module — OSAS Bot v2.1
 * Handles chatbot UI and API interactions
 */

class Chatbot {
    constructor() {
        this.isOpen = false;
        this.conversationHistory = [];
        this.useGroq = true; // Using Groq for AI responses
        this.databaseContext = null; // Cached database context
        this.contextLastFetched = null; // Timestamp of last fetch
        this.contextCacheTime = 5 * 60 * 1000; // Cache for 5 minutes
        this.apiBase = this.getAPIBasePath();
        this.historyOpen = false;
        this.currentSessionId = this.generateSessionId();
        this.init();
    }

    // ─── Chat History Helpers ─────────────────────────────────────────────────

    generateSessionId() {
        const d = new Date();
        // Group by calendar day: YYYY-MM-DD + random 6-char suffix
        const day = d.toISOString().split('T')[0];
        const rand = Math.random().toString(36).slice(2, 8);
        return `${day}_${rand}`;
    }

    getHistoryStorageKey() {
        // Namespace by user ID so each user only sees their own history
        const uid = window.OSAS_USER_ID || 'guest';
        return `osas_chat_history_${uid}`;
    }

    /**
     * Load all chat sessions from localStorage.
     * Returns: { [sessionId]: { date, messages: [{role, content, time}] } }
     */
    loadAllSessions() {
        try {
            const raw = localStorage.getItem(this.getHistoryStorageKey());
            return raw ? JSON.parse(raw) : {};
        } catch (e) {
            return {};
        }
    }

    /**
     * Save current session's messages to localStorage.
     */
    saveCurrentSession() {
        if (this.conversationHistory.length === 0) return;
        try {
            const all = this.loadAllSessions();
            const existing = all[this.currentSessionId] || { date: new Date().toISOString().split('T')[0], messages: [] };
            existing.messages = this.conversationHistory.map((m, i) => ({
                role: m.role,
                content: m.content,
                time: m.time || new Date().toISOString()
            }));
            all[this.currentSessionId] = existing;

            // Prune: keep only last 30 sessions
            const keys = Object.keys(all).sort().reverse();
            if (keys.length > 30) {
                keys.slice(30).forEach(k => delete all[k]);
            }

            localStorage.setItem(this.getHistoryStorageKey(), JSON.stringify(all));
        } catch (e) {
            console.warn('Could not save chat history:', e);
        }
    }

    /**
     * Group sessions by relative date label.
     */
    groupSessionsByDate(sessions) {
        const today = new Date();
        today.setHours(0,0,0,0);
        const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1);

        const groups = {};
        Object.entries(sessions)
            .sort(([a], [b]) => b.localeCompare(a)) // newest first
            .forEach(([id, session]) => {
                const d = new Date(session.date + 'T00:00:00');
                let label;
                if (d >= today) {
                    label = 'Today';
                } else if (d >= yesterday) {
                    label = 'Yesterday';
                } else {
                    const diffDays = Math.floor((today - d) / 86400000);
                    if (diffDays <= 6) {
                        label = `${diffDays} days ago`;
                    } else if (diffDays <= 13) {
                        label = 'Last week';
                    } else if (diffDays <= 30) {
                        label = `${Math.ceil(diffDays/7)} weeks ago`;
                    } else {
                        label = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
                    }
                }
                if (!groups[label]) groups[label] = [];
                groups[label].push({ id, ...session });
            });
        return groups;
    }

    /**
     * Get first user message as session title.
     */
    getSessionTitle(session) {
        const firstUser = (session.messages || []).find(m => m.role === 'user');
        if (firstUser && firstUser.content) {
            return firstUser.content.length > 45
                ? firstUser.content.substring(0, 45) + '…'
                : firstUser.content;
        }
        return 'Chat session';
    }

    getAPIBasePath() {
        const p = window.location.pathname.split('/').filter(Boolean);
        const d = ['app','api','includes','assets','public'];
        return ((p.length===0||d.includes(p[0]))?'':'/'+p[0])+'/api/';
    }
    
    getProjectRoot() {
        const parts = window.location.pathname.split('/').filter(Boolean);
        const appDirs = ['app', 'api', 'includes', 'assets', 'public'];
        return (parts.length === 0 || appDirs.includes(parts[0])) ? '' : '/' + parts[0];
    }
    
    async loadImage(url) {
        return new Promise((resolve) => {
            const img = new Image();
            img.crossOrigin = 'Anonymous';
            img.onload = () => {
                const canvas = document.createElement('canvas');
                canvas.width = img.width;
                canvas.height = img.height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0);
                resolve(canvas.toDataURL('image/png'));
            };
            img.onerror = () => resolve(null);
            img.src = url;
        });
    }

    init() {
        // Wait for Boxicons to load before creating UI
        this.waitForBoxicons().then(() => {
            this.createChatbotUI();
            this.attachEventListeners();
            // Pre-fetch database context
            this.fetchDatabaseContext();

        });
    }



    waitForBoxicons() {
        return new Promise((resolve) => {
            // Always ensure 2.1.4 is loaded (has all icons used by chatbot)
            const alreadyLoaded = document.querySelector('link[href*="boxicons@2.1.4"]');
            if (alreadyLoaded) {
                setTimeout(() => resolve(), 100);
                return;
            }
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = 'https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css';
            link.onload = () => setTimeout(() => resolve(), 100);
            link.onerror = () => resolve();
            document.head.appendChild(link);
        });
    }

    /**
     * Fetch database context from existing APIs
     */
    async fetchDatabaseContext(forceRefresh = false) {
        // Check if we have cached context and it's still valid
        if (!forceRefresh && this.databaseContext && this.contextLastFetched) {
            const now = Date.now();
            if (now - this.contextLastFetched < this.contextCacheTime) {
                return this.databaseContext;
            }
        }

        try {
            // Determine user role from the URL or session storage
            const currentPath = window.location.pathname;
            const userRole = currentPath.includes('/user_dashboard.php') || currentPath.includes('/user/') ? 'user' : 'admin';
            
            // Fetch data from all existing APIs in parallel
            // If user is a student, restrict access to sensitive APIs
            const fetchPromises = [
                userRole === 'admin' ? fetch(this.apiBase + 'students.php').catch(() => null) : Promise.resolve(null),
                fetch(this.apiBase + 'departments.php').catch(() => null),
                fetch(this.apiBase + 'sections.php').catch(() => null),
                userRole === 'admin' ? fetch(this.apiBase + 'violations.php').catch(() => null) : Promise.resolve(null),
                userRole === 'admin' ? fetch(this.apiBase + 'students.php?action=stats').catch(() => null) : Promise.resolve(null),
                fetch(this.apiBase + 'announcements.php').catch(() => null),
                userRole === 'admin' ? fetch(this.apiBase + 'reports.php').catch(() => null) : Promise.resolve(null)
            ];

            const [studentsRes, departmentsRes, sectionsRes, violationsRes, studentsStatsRes, announcementsRes, reportsRes] = await Promise.allSettled(fetchPromises);

            const context = {
                stats: {},
                departments: [],
                sections: [],
                recent_students: [],
                recent_violations: [],
                recent_announcements: [],
                recent_reports: [],
                user_info: null
            };

            // Parse students data
            if (studentsRes.status === 'fulfilled' && studentsRes.value && studentsRes.value.ok) {
                try {
                    const studentsData = await studentsRes.value.json();
                    // Handle different response formats
                    let students = [];
                    if (Array.isArray(studentsData)) {
                        students = studentsData;
                    } else if (studentsData.data && Array.isArray(studentsData.data)) {
                        students = studentsData.data;
                    } else if (studentsData.students && Array.isArray(studentsData.students)) {
                        students = studentsData.students;
                    }
                    
                    context.recent_students = students.slice(0, 10).map(s => ({
                        id: s.studentId || s.student_id || '',
                        name: `${s.firstName || s.first_name || ''} ${s.middleName || s.middle_name || ''} ${s.lastName || s.last_name || ''}`.trim(),
                        email: s.email || '',
                        department: s.department || s.department_name || '',
                        section_id: s.sectionId || s.section_id || ''
                    }));
                    context.stats.students = students.length;
                } catch (e) {
                    console.warn('Error parsing students data:', e);
                }
            }

            // Parse students stats (if available)
            if (studentsStatsRes.status === 'fulfilled' && studentsStatsRes.value && studentsStatsRes.value.ok) {
                try {
                    const statsData = await studentsStatsRes.value.json();
                    if (statsData.data) {
                        // Override with stats if available
                        context.stats.students = statsData.data.total || statsData.data.active || context.stats.students || 0;
                    }
                } catch (e) {
                    console.warn('Error parsing stats data:', e);
                }
            }

            // Parse departments data
            if (departmentsRes.status === 'fulfilled' && departmentsRes.value && departmentsRes.value.ok) {
                try {
                    const deptData = await departmentsRes.value.json();
                    // Handle different response formats
                    let departments = [];
                    if (Array.isArray(deptData)) {
                        departments = deptData;
                    } else if (deptData.data && Array.isArray(deptData.data)) {
                        departments = deptData.data;
                    } else if (deptData.departments && Array.isArray(deptData.departments)) {
                        departments = deptData.departments;
                    }
                    
                    context.departments = departments.slice(0, 20).map(d => ({
                        code: d.departmentCode || d.department_code || '',
                        name: d.departmentName || d.department_name || ''
                    }));
                    context.stats.departments = departments.length;
                } catch (e) {
                    console.warn('Error parsing departments data:', e);
                }
            }

            // Parse sections data
            if (sectionsRes.status === 'fulfilled' && sectionsRes.value && sectionsRes.value.ok) {
                try {
                    const sectionsData = await sectionsRes.value.json();
                    // Handle different response formats
                    let sections = [];
                    if (Array.isArray(sectionsData)) {
                        sections = sectionsData;
                    } else if (sectionsData.data && Array.isArray(sectionsData.data)) {
                        sections = sectionsData.data;
                    } else if (sectionsData.sections && Array.isArray(sectionsData.sections)) {
                        sections = sectionsData.sections;
                    }
                    
                    context.sections = sections.slice(0, 30).map(s => ({
                        id: s.id || '',
                        code: s.sectionCode || s.section_code || '',
                        name: s.sectionName || s.section_name || '',
                        department: s.departmentCode || s.department_code || ''
                    }));
                    context.stats.sections = sections.length;
                } catch (e) {
                    console.warn('Error parsing sections data:', e);
                }
            }

            // Parse violations data
            if (violationsRes.status === 'fulfilled' && violationsRes.value && violationsRes.value.ok) {
                try {
                    const violationsData = await violationsRes.value.json();
                    // Handle different response formats
                    let violations = [];
                    if (Array.isArray(violationsData)) {
                        violations = violationsData;
                    } else if (violationsData.data && Array.isArray(violationsData.data)) {
                        violations = violationsData.data;
                    } else if (violationsData.violations && Array.isArray(violationsData.violations)) {
                        violations = violationsData.violations;
                    }
                    
                    context.recent_violations = violations.slice(0, 10).map(v => ({
                        id: v.id || '',
                        case_id: v.caseId || v.case_id || '',
                        student_id: v.studentId || v.student_id || '',
                        student_name: v.studentName || `${v.firstName || v.first_name || ''} ${v.lastName || v.last_name || ''}`.trim() || 'Unknown',
                        violation_type: v.violationType || v.violation_type || '',
                        violation_level: v.violationLevel || v.violation_level || '',
                        status: v.status || '',
                        date: v.violationDate || v.violation_date || v.dateReported || ''
                    }));
                    context.stats.violations = violations.length;
                } catch (e) {
                    console.warn('Error parsing violations data:', e);
                }
            }

            // Parse announcements data
            if (announcementsRes.status === 'fulfilled' && announcementsRes.value && announcementsRes.value.ok) {
                try {
                    const announcementsData = await announcementsRes.value.json();
                    // Handle different response formats
                    let announcements = [];
                    if (Array.isArray(announcementsData)) {
                        announcements = announcementsData;
                    } else if (announcementsData.data && Array.isArray(announcementsData.data)) {
                        announcements = announcementsData.data;
                    } else if (announcementsData.announcements && Array.isArray(announcementsData.announcements)) {
                        announcements = announcementsData.announcements;
                    }
                    
                    context.recent_announcements = announcements.slice(0, 10).map(a => ({
                        id: a.id || a.announcementId || a.announcement_id || '',
                        title: a.title || a.announcementTitle || a.announcement_title || '',
                        content: a.content || a.description || a.body || '',
                        audience: a.audience || a.targetAudience || a.target_audience || '',
                        status: a.status || '',
                        date: a.createdAt || a.created_at || a.dateCreated || a.date_created || '',
                        author: a.author || a.createdBy || a.created_by || ''
                    }));
                    context.stats.announcements = announcements.length;
                } catch (e) {
                    console.warn('Error parsing announcements data:', e);
                }
            }

            // Parse reports data
            if (reportsRes.status === 'fulfilled' && reportsRes.value && reportsRes.value.ok) {
                try {
                    const reportsData = await reportsRes.value.json();
                    // Handle different response formats
                    let reports = [];
                    if (Array.isArray(reportsData)) {
                        reports = reportsData;
                    } else if (reportsData.data && Array.isArray(reportsData.data)) {
                        reports = reportsData.data;
                    } else if (reportsData.reports && Array.isArray(reportsData.reports)) {
                        reports = reportsData.reports;
                    }
                    
                    context.recent_reports = reports.slice(0, 10).map(r => ({
                        id: r.id || r.reportId || r.report_id || '',
                        title: r.title || r.reportTitle || r.report_title || '',
                        type: r.type || r.reportType || r.report_type || '',
                        description: r.description || r.summary || '',
                        status: r.status || '',
                        date: r.createdAt || r.created_at || r.dateCreated || r.date_created || '',
                        generated_by: r.generatedBy || r.generated_by || r.createdBy || r.created_by || ''
                    }));
                    context.stats.reports = reports.length;
                } catch (e) {
                    console.warn('Error parsing reports data:', e);
                }
            }

            // Get user info from session (if available)
            // This would need to be passed from the backend or stored in a cookie
            // For now, we'll leave it null

            this.databaseContext = context;
            this.contextLastFetched = Date.now();
            return this.databaseContext;

        } catch (error) {
            console.warn('Error fetching database context:', error);
            // Don't throw - context is optional
        }

        return this.databaseContext;
    }

    /**
     * Build advanced system prompt based on user role
     */
    buildAdvancedSystemPrompt(userRole) {
        let prompt = `You are **OSAS Bot**, the intelligent virtual assistant for the **E-OSAS (Electronic Office of Student Affairs System)** — a web-based student discipline and records management platform.

IDENTITY & PERSONALITY:
- Name: OSAS Bot
- Tone: Friendly, professional, helpful, and concise
- Language: Respond in the same language the user uses (English or Filipino/Tagalog). If the user mixes languages (Taglish), match that style.
- System Owner/Administrator/Head: Cedrick H. Almarez

CORE CAPABILITIES:
1. Student Records — Look up student info, counts, departments, sections
2. Violations & Discipline — Explain violation types, levels, statuses, sanctions, and processes
3. Announcements — Summarize active announcements, explain how to create/manage them
4. Reports — Explain report generation, types, and how to export data
5. Departments & Sections — List, explain, and help manage organizational units
6. System Navigation — Guide users on how to use each module/page of E-OSAS
7. Policies & Procedures — Explain the student discipline process, due process, and sanctions
8. Troubleshooting — Help with common issues (login problems, data not showing, etc.)

VIOLATION LEVELS & SANCTIONS:
- 1st Offense: Verbal reminder — please comply with dress code
- 2nd Offense: Written reminder — dress code must be followed
- 3rd Offense: First formal warning — counseling referral possible
- 4th Offense: Second formal warning — parent conference required
- 5th Offense: Final warning — automatically triggers Disciplinary Action
- Disciplinary Action: Referral to discipline office; suspension or serious sanctions apply
- Due process: Notice → Hearing → Decision → Appeal (if applicable)
- Records tracked per semester; may be archived at semester end

SYSTEM MODULES:
- Dashboard: Statistics overview — students, violations, departments, recent activity
- Students: Add, import (Excel), edit, search, view profiles with photos
- Violations: Record violations, assign types/levels, track status (pending → resolved → archived), generate entrance slips
- Departments: Create/manage academic departments with codes
- Sections: Create sections linked to departments
- Announcements: Create, publish, target audience (all/students/staff)
- Reports: Generate PDF/Excel reports with date/department/type filters
- Settings: System config, user management, backup/restore
- Entrance Slip: Auto-generated return-to-class document after violation

RESPONSE RULES:
1. ONLY use ACTUAL DATA from context below. NEVER invent student names, IDs, case numbers, or stats.
2. If data is unavailable, say: "I don't have that specific information in my current data. You can check the [relevant module] directly."
3. Use bullet points and bold for clarity. Keep responses scannable.
4. Be concise: simple questions = 1-3 sentences; how-to = step-by-step.
5. Only answer E-OSAS/student affairs topics. Redirect unrelated questions politely.
6. Respect student privacy based on user role.
7. Offer suggestions if user seems confused.
8. For problems, provide troubleshooting steps.

`;

        if (userRole === 'user') {
            prompt += `CURRENT USER ROLE: Student

STUDENT PORTAL PAGES (these are the ONLY pages available to students):
1. **My Dashboard** — Shows a compliance overview with total violations, permitted count, warning count, and a recent violations list. Also shows "Tips to Stay Compliant".
2. **My Violations** — Full list of the student's own violation records. Can filter by time period (this month / all history), violation type, and status. Has table, list, and grid view modes. Can download a personal violation report.
3. **Announcements** — Read-only list of announcements published by OSAS. Can filter by category and status.

WHAT STUDENTS CAN DO:
- View their own violations and check status (Pending, Permitted, Warning, Disciplinary, Resolved)
- Download their own violation report
- Read school announcements
- Ask about violation policies, levels, and sanctions
- Ask what their violation status means and what happens next
- Ask about the entrance slip process
- Ask how to appeal a violation

WHAT STUDENTS CANNOT DO (do NOT describe these as available):
- There is NO Departments page for students
- There is NO Reports module for students (only a personal download button)
- There is NO Students management page
- There is NO Settings page
- Students CANNOT create, edit, or delete violations
- Students CANNOT see other students' records

If asked about other students' data, total student counts, or system-wide statistics, respond:
"That information is only available to authorized OSAS administrators and staff. I can only help you with your own records and general system guidance."

HOW-TO FOR STUDENTS:
- Check your violations: Click "My Violations" in the top navigation
- Filter violations: Use the time period, type, and status dropdowns on the My Violations page
- Download your report: Click the "Download Report" button on the My Violations page
- Read announcements: Click "Announcements" in the top navigation
- Understand your status: Ask me what "Permitted", "Warning", or "Disciplinary" means
- Entrance slip: If you received a violation, an entrance slip may be generated — show it to your instructor to return to class
- Appeal a violation: Contact the OSAS office directly to file an appeal

`;
        } else {
            prompt += `CURRENT USER ROLE: Admin/Staff (${userRole})

ADMIN PORTAL PAGES:
1. **Dashboard** — System overview with total students, active violations, departments, recent activity
2. **Students** — Add, edit, search, import (Excel), view student profiles with photos
3. **Violations** — Record new violations, assign types/levels, track status, generate entrance slips, archive records
4. **Departments** — Create and manage academic departments with codes
5. **Sections** — Create sections linked to departments
6. **Announcements** — Create, edit, publish announcements with audience targeting
7. **Reports** — Generate PDF/Excel reports filtered by date, department, violation type
8. **Settings** — System config, user management, backup/restore

HOW-TO FOR ADMINS:
- Record a violation: Violations → Add Violation → Select student → Choose type/level → Save
- Import students: Students → Import → Download template → Fill data → Upload → Confirm
- Generate report: Reports → Select type → Set filters → Generate → Download PDF/Excel
- Create announcement: Announcements → New → Enter title/message → Select audience → Publish
- Manage departments: Departments → Add/Edit → Enter name and code → Save
- Backup system: Settings → Backup → Download database backup

`;
        }

        return prompt;
    }

    /**
     * Format database context as a readable string for the AI
     */
    formatDatabaseContext(context) {
        if (!context) return '';

        let formatted = '\n\n═══ LIVE SYSTEM DATA (from database) ═══\n\n';

        // Add system ownership/administration information
        formatted += '📋 SYSTEM ADMINISTRATION:\n';
        formatted += '- System Owner/Administrator/Head: Cedrick H. Almarez\n\n';

        // Add statistics
        if (context.stats) {
            formatted += '📊 CURRENT STATISTICS:\n';
            if (context.stats.students !== undefined) formatted += `- Total Students Enrolled: ${context.stats.students}\n`;
            if (context.stats.departments !== undefined) formatted += `- Total Departments: ${context.stats.departments}\n`;
            if (context.stats.sections !== undefined) formatted += `- Total Sections: ${context.stats.sections}\n`;
            if (context.stats.violations !== undefined) formatted += `- Active Violations (this period): ${context.stats.violations}\n`;
            if (context.stats.announcements !== undefined) formatted += `- Active Announcements: ${context.stats.announcements}\n`;
            if (context.stats.reports !== undefined) formatted += `- Reports Generated: ${context.stats.reports}\n`;
            formatted += '\n';
        }

        // Add departments list
        if (context.departments && context.departments.length > 0) {
            formatted += '🏢 DEPARTMENTS:\n';
            context.departments.forEach(dept => {
                formatted += `- ${dept.name} (Code: ${dept.code})\n`;
            });
            formatted += '\n';
        }

        // Add sections list
        if (context.sections && context.sections.length > 0) {
            formatted += '📁 SECTIONS:\n';
            context.sections.forEach(section => {
                formatted += `- ${section.name} (Code: ${section.code}, Dept: ${section.department})\n`;
            });
            formatted += '\n';
        }

        // Add recent students
        if (context.recent_students && context.recent_students.length > 0) {
            formatted += '👥 RECENT STUDENTS (sample from database):\n';
            context.recent_students.forEach(student => {
                formatted += `- ${student.name} | ID: ${student.id} | Dept: ${student.department}\n`;
            });
            formatted += '\n';
        }

        // Add recent violations with more detail
        if (context.recent_violations && context.recent_violations.length > 0) {
            formatted += '⚠️ RECENT VIOLATIONS (actual records):\n';
            context.recent_violations.forEach(violation => {
                formatted += `- Case ${violation.case_id || violation.id}: ${violation.student_name} (ID: ${violation.student_id}) — Type: ${violation.violation_type}, Level: ${violation.violation_level}, Status: ${violation.status}, Date: ${violation.date}\n`;
            });
            formatted += '\n';
        }

        // Add recent announcements with content preview
        if (context.recent_announcements && context.recent_announcements.length > 0) {
            formatted += '📢 ACTIVE ANNOUNCEMENTS:\n';
            context.recent_announcements.forEach(announcement => {
                formatted += `- "${announcement.title}" (Audience: ${announcement.audience || 'all'}, Status: ${announcement.status || 'active'}, Date: ${announcement.date})\n`;
                if (announcement.content && announcement.content.length > 0) {
                    const preview = announcement.content.substring(0, 150).replace(/\n/g, ' ').trim();
                    formatted += `  Content: ${preview}${announcement.content.length > 150 ? '...' : ''}\n`;
                }
            });
            formatted += '\n';
        }

        // Add recent reports
        if (context.recent_reports && context.recent_reports.length > 0) {
            formatted += '📄 RECENT REPORTS:\n';
            context.recent_reports.forEach(report => {
                formatted += `- ${report.title || 'Untitled'} (Type: ${report.type || 'N/A'}, Status: ${report.status || 'N/A'}, Date: ${report.date})\n`;
            });
            formatted += '\n';
        }

        // Add user-specific info
        if (context.user_info) {
            formatted += '👤 CURRENT USER:\n';
            formatted += `- Role: ${context.user_info.role}\n`;
            if (context.user_info.violation_count !== undefined) {
                formatted += `- User's Violation Count: ${context.user_info.violation_count}\n`;
            }
            formatted += '\n';
        }

        formatted += '═══ END OF LIVE DATA ═══\n\n';
        formatted += 'INSTRUCTIONS: Use the data above to answer factual questions. If the user asks about something not in this data, say you don\'t have that specific information and suggest where they can find it in the system.\n';

        return formatted;
    }

    createChatbotUI() {
        const botImgPath = this.apiBase.replace('/api/', '/app/assets/img/bot.png');
        const currentPath = window.location.pathname;
        const isUser = currentPath.includes('/user_dashboard.php') || currentPath.includes('/user/');

        // ── Floating trigger button ──────────────────────────────────────
        const chatbotButton = document.createElement('div');
        chatbotButton.id = 'chatbot-button';
        chatbotButton.setAttribute('aria-label', 'Open chat');
        chatbotButton.title = 'Chat with OSAS Bot';
        chatbotButton.innerHTML = `<img src="${botImgPath}" alt="Chat" class="chatbot-btn-img">`;
        document.body.appendChild(chatbotButton);

        // Role-specific welcome content
        const welcomeText = isUser
            ? `<p>Hi there 👋 I'm <strong>OSAS Bot</strong>.</p><p>Ask me about your violations, announcements, or how to use the student portal.</p>`
            : `<p>Hi there 👋 I'm <strong>OSAS Bot</strong>.</p><p>Ask me anything about students, violations, departments, or how to use the system.</p>`;

        const chips = isUser
            ? `<button class="cb-chip" data-prompt="What are my current violations and their status?">My violations</button>
               <button class="cb-chip" data-prompt="Show me the latest announcements I should know about">Announcements</button>
               <button class="cb-chip" data-prompt="Explain the violation levels and what sanctions I could face">Sanctions info</button>
               <button class="cb-chip" data-prompt="How do I navigate and use the student portal? What pages are available to me?">Portal help</button>
               <button class="cb-chip" data-prompt="I received an entrance slip. What do I do with it?">Entrance slip</button>
               <button class="cb-chip" data-prompt="How do I appeal a violation?">Appeal process</button>`
            : `<button class="cb-chip" data-prompt="Give me a summary of today's system stats — students, violations, departments">System summary</button>
               <button class="cb-chip" data-prompt="Show me the current violation statistics by type and level">Violation stats</button>
               <button class="cb-chip" data-prompt="How do I record a new student violation? Step by step.">Record violation</button>
               <button class="cb-chip" data-prompt="What departments and sections exist in the system?">Departments</button>
               <button class="cb-chip" data-prompt="How do I generate and export a report?">Generate report</button>
               <button class="cb-chip" data-prompt="How do I import students from an Excel file?">Import students</button>`;

        // ── Main panel ───────────────────────────────────────────────────
        const chatbotPanel = document.createElement('div');
        chatbotPanel.id = 'chatbot-panel';
        chatbotPanel.innerHTML = `
            <!-- HISTORY SIDEBAR -->
            <div class="cb-history-sidebar" id="cb-history-sidebar">
                <div class="cb-history-header">
                    <span class="cb-history-title">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="16" height="16"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                        Chat History
                    </span>
                    <button class="cb-history-close-btn" id="cb-history-close" aria-label="Close history">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" width="14" height="14"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                    </button>
                </div>
                <button class="cb-history-new-btn" id="cb-history-new">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" width="14" height="14"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                    New Conversation
                </button>
                <div class="cb-history-list" id="cb-history-list">
                    <div class="cb-history-empty">No previous chats yet.</div>
                </div>
            </div>

            <!-- HEADER -->
            <div class="cb-header">
                <button class="cb-history-btn" id="cb-history-toggle" aria-label="Chat history" title="Chat History">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="18" height="18"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                </button>
                <div class="cb-header-avatar">
                    <img src="${botImgPath}" alt="OSAS Bot" class="cb-avatar-img">
                    <span class="cb-online-dot"></span>
                </div>
                <div class="cb-header-info">
                    <span class="cb-header-name">OSAS Bot</span>
                    <span class="cb-header-sub">AI · Always here to help</span>
                </div>
                <button class="cb-close-btn" id="chatbot-close" aria-label="Close">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" width="18" height="18">
                        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>

            <!-- MESSAGES -->
            <div class="cb-messages" id="chatbot-messages">
                <div class="cb-msg-row cb-bot-row">
                    <img src="${botImgPath}" alt="" class="cb-bubble-avatar">
                    <div class="cb-bubble cb-bot-bubble">${welcomeText}</div>
                </div>
                <div class="cb-chips" id="cb-chips">${chips}</div>
            </div>

            <!-- INPUT BAR -->
            <div class="cb-input-bar">
                <input type="text" id="chatbot-input" class="cb-input" placeholder="Write a reply…" autocomplete="off">
                <button id="chatbot-send" class="cb-send-btn" aria-label="Send">
                    <svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
                </button>
            </div>

            <!-- TYPING INDICATOR -->
            <div class="cb-typing" id="chatbot-loading" style="display:none">
                <img src="${botImgPath}" alt="" class="cb-bubble-avatar">
                <div class="cb-typing-dots"><span></span><span></span><span></span></div>
            </div>
        `;
        document.body.appendChild(chatbotPanel);
    }

    // ─── History Sidebar Methods ──────────────────────────────────────────────

    toggleHistory() {
        if (this.historyOpen) {
            this.closeHistory();
        } else {
            this.openHistory();
        }
    }

    async openHistory() {
        this.historyOpen = true;
        
        // Fetch from DB first, then update localStorage
        try {
            const res = await fetch(this.apiBase + 'chatbot_history.php');
            const data = await res.json();
            if (data.success && data.sessions) {
                localStorage.setItem(this.getHistoryStorageKey(), JSON.stringify(data.sessions));
            }
        } catch (e) {
            console.warn('Could not fetch history from DB:', e);
        }

        const sidebar = document.getElementById('cb-history-sidebar');
        if (sidebar) {
            this.renderHistoryList();
            sidebar.classList.add('open');
        }
        const btn = document.getElementById('cb-history-toggle');
        if (btn) btn.classList.add('active');
    }

    closeHistory() {
        this.historyOpen = false;
        const sidebar = document.getElementById('cb-history-sidebar');
        if (sidebar) sidebar.classList.remove('open');
        const btn = document.getElementById('cb-history-toggle');
        if (btn) btn.classList.remove('active');
    }

    renderHistoryList() {
        const listEl = document.getElementById('cb-history-list');
        if (!listEl) return;

        const all = this.loadAllSessions();
        const sessionKeys = Object.keys(all);

        if (sessionKeys.length === 0) {
            listEl.innerHTML = '<div class="cb-history-empty">No previous chats yet.<br>Start chatting to save history!</div>';
            return;
        }

        const groups = this.groupSessionsByDate(all);
        listEl.innerHTML = '';

        Object.entries(groups).forEach(([label, sessions]) => {
            const groupEl = document.createElement('div');
            groupEl.className = 'cb-history-group';

            const labelEl = document.createElement('div');
            labelEl.className = 'cb-history-group-label';
            labelEl.textContent = label;
            groupEl.appendChild(labelEl);

            sessions.forEach(session => {
                const item = document.createElement('div');
                item.className = 'cb-history-item';
                if (session.id === this.currentSessionId) {
                    item.classList.add('current');
                }

                const title = this.getSessionTitle(session);
                const msgCount = (session.messages || []).filter(m => m.role === 'user').length;

                item.innerHTML = `
                    <div class="cb-history-item-icon">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                    </div>
                    <div class="cb-history-item-body">
                        <div class="cb-history-item-title">${this.escapeHtml(title)}</div>
                        <div class="cb-history-item-meta">${msgCount} message${msgCount !== 1 ? 's' : ''}</div>
                    </div>
                    ${session.id !== this.currentSessionId ? `<button class="cb-history-delete-btn" data-session-id="${session.id}" title="Delete" aria-label="Delete session">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" width="11" height="11"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/></svg>
                    </button>` : '<span class="cb-history-current-badge">Current</span>'}
                `;

                // Restore session on click
                item.addEventListener('click', (e) => {
                    if (e.target.closest('.cb-history-delete-btn')) return;
                    if (session.id !== this.currentSessionId) {
                        this.restoreSession(session);
                    }
                    this.closeHistory();
                });

                // Delete session
                const deleteBtn = item.querySelector('.cb-history-delete-btn');
                if (deleteBtn) {
                    deleteBtn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        this.deleteSession(session.id);
                    });
                }

                groupEl.appendChild(item);
            });

            listEl.appendChild(groupEl);
        });
    }

    restoreSession(session) {
        const botImgPath = this.apiBase.replace('/api/', '/app/assets/img/bot.png');
        const container = document.getElementById('chatbot-messages');
        if (!container) return;

        // Clear current chat
        container.innerHTML = '';
        this.conversationHistory = session.messages ? [...session.messages] : [];
        this.currentSessionId = session.id;

        // Add a "viewing history" banner -> "Continuing chat from"
        const bannerRow = document.createElement('div');
        bannerRow.className = 'cb-history-banner';
        bannerRow.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            Continuing chat from <strong>${new Date(session.date + 'T00:00:00').toLocaleDateString(undefined, { weekday:'short', month:'short', day:'numeric' })}</strong>
            <button class="cb-history-back-btn" id="cb-history-back">← New chat</button>
        `;
        container.appendChild(bannerRow);

        // Replay messages
        (session.messages || []).forEach(msg => {
            const row = document.createElement('div');
            row.className = `cb-msg-row ${msg.role === 'user' ? 'cb-user-row' : 'cb-bot-row'}`;
            const formatted = this.formatMessageContent(msg.content);
            if (msg.role === 'user') {
                row.innerHTML = `<div class="cb-bubble cb-user-bubble"><div class="cb-bubble-text">${formatted}</div></div>`;
            } else {
                row.innerHTML = `<img src="${botImgPath}" alt="" class="cb-bubble-avatar"><div class="cb-bubble cb-bot-bubble"><div class="cb-bubble-text">${formatted}</div></div>`;
            }
            container.appendChild(row);
        });

        container.scrollTop = container.scrollHeight;

        // ENABLE input instead of disabling it so they can continue chatting
        const input = document.getElementById('chatbot-input');
        const sendBtn = document.getElementById('chatbot-send');
        if (input) { 
            input.disabled = false; 
            input.placeholder = 'Write a reply…'; 
            input.focus(); 
        }
        if (sendBtn) {
            sendBtn.disabled = false;
        }

        // Back button — start fresh
        const backBtn = document.getElementById('cb-history-back');
        if (backBtn) {
            backBtn.addEventListener('click', () => this.startNewConversation());
        }
    }

    async deleteSession(sessionId) {
        try {
            await fetch(this.apiBase + 'chatbot_history.php', {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ session_id: sessionId })
            });
            const all = this.loadAllSessions();
            delete all[sessionId];
            localStorage.setItem(this.getHistoryStorageKey(), JSON.stringify(all));
            this.renderHistoryList();
        } catch (e) {
            console.warn('Could not delete session:', e);
        }
    }

    startNewConversation() {
        const botImgPath = this.apiBase.replace('/api/', '/app/assets/img/bot.png');
        const currentPath = window.location.pathname;
        const isUser = currentPath.includes('/user_dashboard.php') || currentPath.includes('/user/');
        const welcomeText = isUser
            ? `<p>Hi there 👋 I'm <strong>OSAS Bot</strong>.</p><p>Ask me about your violations, announcements, or how to use the student portal.</p>`
            : `<p>Hi there 👋 I'm <strong>OSAS Bot</strong>.</p><p>Ask me anything about students, violations, departments, or how to use the system.</p>`;

        // Save current before resetting
        this.saveCurrentSession();

        // Reset state
        this.currentSessionId = this.generateSessionId();
        this.conversationHistory = [];

        const container = document.getElementById('chatbot-messages');
        if (container) {
            container.innerHTML = `
                <div class="cb-msg-row cb-bot-row">
                    <img src="${botImgPath}" alt="" class="cb-bubble-avatar">
                    <div class="cb-bubble cb-bot-bubble">${welcomeText}</div>
                </div>
            `;
        }

        // Re-enable input
        const input = document.getElementById('chatbot-input');
        const sendBtn = document.getElementById('chatbot-send');
        if (input) { input.disabled = false; input.placeholder = 'Write a reply…'; input.focus(); }
        if (sendBtn) sendBtn.disabled = false;

        this.closeHistory();
    }

    createPromptSelectorModal() {
        const modal = document.createElement('div');
        modal.id = 'prompt-selector-modal';
        modal.className = 'prompt-selector-modal';
        modal.innerHTML = `
            <div class="prompt-selector-content">
                <div class="prompt-selector-header">
                    <div class="prompt-selector-title">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="18" height="18"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
                        <span>Select a Prompt</span>
                    </div>
                    <button class="prompt-selector-close" id="prompt-selector-close" aria-label="Close">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" width="18" height="18"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                    </button>
                </div>
                <div class="prompt-selector-body" id="prompt-selector-body">
                    <!-- Prompt categories will be added here -->
                </div>
            </div>
        `;
        document.body.appendChild(modal);
        this.loadPromptCategories();
    }

    loadQuickPrompts() {
        // Chips are now inline in the welcome HTML — nothing to do here
    }

    loadPromptCategories() {
        const currentPath = window.location.pathname;
        const isUser = currentPath.includes('/user_dashboard.php') || currentPath.includes('/user/');

        const adminCategories = [
            {
                title: 'General & Navigation',
                icon: 'bx-help-circle',
                prompts: [
                    { title: 'System Overview', desc: 'What is E-OSAS and what can it do?', text: 'Give me a complete overview of the E-OSAS system and all its features.' },
                    { title: 'Quick Start Guide', desc: 'How to get started as admin', text: 'Give me a quick start guide for using E-OSAS as an administrator.' },
                    { title: 'Dashboard Explained', desc: 'What do the dashboard stats mean?', text: 'Explain what each statistic on the dashboard means and how to interpret them.' },
                    { title: 'Troubleshooting', desc: 'Common issues and fixes', text: 'What are common issues in E-OSAS and how do I fix them?' }
                ]
            },
            {
                title: 'Students Management',
                icon: 'bx-group',
                prompts: [
                    { title: 'Student Count', desc: 'Total registered students', text: 'How many students are currently registered in the system?' },
                    { title: 'Import Students', desc: 'Bulk import from Excel', text: 'How do I import students from an Excel file? Give me step-by-step instructions.' },
                    { title: 'Search Students', desc: 'Find a specific student', text: 'How do I search for a specific student by name or ID?' },
                    { title: 'Student Profiles', desc: 'Managing student records', text: 'What information is stored in a student profile and how do I update it?' }
                ]
            },
            {
                title: 'Violations & Discipline',
                icon: 'bx-shield-x',
                prompts: [
                    { title: 'Violation Stats', desc: 'Current violation overview', text: 'Show me the current violation statistics — how many active violations, by type and level.' },
                    { title: 'Record a Violation', desc: 'Step-by-step guide', text: 'How do I record a new student violation? Walk me through the process.' },
                    { title: 'Violation Levels', desc: '1st–5th Offense explained', text: 'Explain the different violation levels (1st to 5th Offense and Disciplinary Action) and their corresponding sanctions.' },
                    { title: 'Due Process', desc: 'Discipline procedure', text: 'What is the due process for student discipline? Explain the steps from notice to resolution.' },
                    { title: 'Entrance Slip', desc: 'How entrance slips work', text: 'How does the entrance slip system work? When is it generated and what does the student do with it?' },
                    { title: 'Resolve Violations', desc: 'Closing a case', text: 'How do I resolve or close a violation case? What are the possible statuses?' }
                ]
            },
            {
                title: 'Departments & Sections',
                icon: 'bx-building',
                prompts: [
                    { title: 'List Departments', desc: 'All departments in the system', text: 'What departments currently exist in the system? List them all.' },
                    { title: 'Add Department', desc: 'Create a new department', text: 'How do I add a new department to the system?' },
                    { title: 'Manage Sections', desc: 'Sections under departments', text: 'How do I create and manage sections? How are they linked to departments?' },
                    { title: 'Department Stats', desc: 'Students per department', text: 'How many students are in each department?' }
                ]
            },
            {
                title: 'Announcements',
                icon: 'bx-megaphone',
                prompts: [
                    { title: 'Active Announcements', desc: 'Currently published', text: 'What announcements are currently active? Show me their titles and details.' },
                    { title: 'Create Announcement', desc: 'How to publish one', text: 'How do I create and publish a new announcement? What options are available?' },
                    { title: 'Target Audience', desc: 'Who sees what', text: 'How does announcement targeting work? Can I send to specific departments or all students?' }
                ]
            },
            {
                title: 'Reports & Data',
                icon: 'bx-file',
                prompts: [
                    { title: 'Generate Report', desc: 'Create PDF/Excel reports', text: 'How do I generate a report? What types of reports are available and what filters can I use?' },
                    { title: 'Export Data', desc: 'Download system data', text: 'How do I export data from the system? What formats are supported?' },
                    { title: 'Monthly Summary', desc: 'This month overview', text: 'Give me a summary of this month — violations recorded, students affected, and any trends.' },
                    { title: 'Backup System', desc: 'Database backup', text: 'How do I backup the system database? How often should I do it?' }
                ]
            }
        ];

        const userCategories = [
            {
                title: 'My Account',
                icon: 'bx-user',
                prompts: [
                    { title: 'My Violations', desc: 'Check your violation records', text: 'What are my current violations? Show me the details and status of each one.' },
                    { title: 'Violation Status', desc: 'What does my status mean?', text: 'What do the different violation statuses mean (pending, resolved, archived)?' },
                    { title: 'My Profile', desc: 'View your student info', text: 'What information does the system have about me?' },
                    { title: 'Clear Record', desc: 'When are violations cleared?', text: 'When do my violation records get cleared or archived? Is there a reset period?' }
                ]
            },
            {
                title: 'Understanding Violations',
                icon: 'bx-shield-x',
                prompts: [
                    { title: 'Violation Levels', desc: '1st to 5th Offense', text: 'Explain the different violation levels (1st to 5th Offense) and what sanctions I might face for each. What happens at the 5th offense?' },
                    { title: 'Due Process', desc: 'Your rights', text: 'What is my right to due process if I receive a violation? Can I appeal?' },
                    { title: 'Entrance Slip', desc: 'What to do with it', text: 'I received an entrance slip. What do I do with it and who do I show it to?' },
                    { title: 'Sanctions', desc: 'What happens next', text: 'What are the possible sanctions for violations and how do they escalate with repeated offenses?' },
                    { title: 'Appeal Process', desc: 'How to contest', text: 'How do I appeal a violation if I believe it was unfair or incorrect?' }
                ]
            },
            {
                title: 'Announcements & Info',
                icon: 'bx-megaphone',
                prompts: [
                    { title: 'Latest Announcements', desc: 'What is new', text: 'Show me the latest announcements. Are there any urgent ones I should know about?' },
                    { title: 'School Policies', desc: 'Rules and regulations', text: 'What are the main school policies I should be aware of regarding student conduct?' },
                    { title: 'Contact OSAS', desc: 'How to reach the office', text: 'How do I contact the Office of Student Affairs if I need help or have questions?' }
                ]
            },
            {
                title: 'Portal Help',
                icon: 'bx-help-circle',
                prompts: [
                    { title: 'How to Use Portal', desc: 'Navigate the student portal', text: 'How do I use the student portal? What pages are available to me as a student — My Dashboard, My Violations, and Announcements?' },
                    { title: 'Check My Violations', desc: 'View and filter your records', text: 'How do I check my violations? How do I filter by type, status, or time period?' },
                    { title: 'Download My Report', desc: 'Get your personal report', text: 'How do I download my own violation report?' },
                    { title: 'Login Issues', desc: 'Cannot access account', text: 'I am having trouble logging in. What should I do?' },
                    { title: 'About E-OSAS', desc: 'What is this system?', text: 'What is E-OSAS and why does our school use it?' }
                ]
            }
        ];

        const categories = isUser ? userCategories : adminCategories;

        const selectorBody = document.getElementById('prompt-selector-body');
        if (!selectorBody) return;

        categories.forEach(category => {
            const categoryDiv = document.createElement('div');
            categoryDiv.className = 'prompt-category';
            
            const categoryTitle = document.createElement('div');
            categoryTitle.className = 'prompt-category-title';
            categoryTitle.innerHTML = `<i class="bx ${category.icon}"></i><span>${category.title}</span>`;
            
            const categoryGrid = document.createElement('div');
            categoryGrid.className = 'prompt-category-grid';
            
            category.prompts.forEach(prompt => {
                const promptCard = document.createElement('div');
                promptCard.className = 'prompt-card';
                promptCard.innerHTML = `
                    <div class="prompt-card-icon"><i class="bx ${category.icon}" aria-hidden="true"></i></div>
                    <div class="prompt-card-title">${prompt.title}</div>
                    <div class="prompt-card-desc">${prompt.desc}</div>
                `;
                promptCard.addEventListener('click', () => {
                    this.usePrompt(prompt.text);
                    this.closePromptSelector();
                });
                categoryGrid.appendChild(promptCard);
            });
            
            categoryDiv.appendChild(categoryTitle);
            categoryDiv.appendChild(categoryGrid);
            selectorBody.appendChild(categoryDiv);
        });
    }

    attachEventListeners() {
        document.getElementById('chatbot-button').addEventListener('click', () => this.toggle());
        document.getElementById('chatbot-close').addEventListener('click',  () => this.close());

        const sendBtn = document.getElementById('chatbot-send');
        const input   = document.getElementById('chatbot-input');
        sendBtn.addEventListener('click', () => this.sendMessage());
        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); this.sendMessage(); }
        });

        // Suggestion chips
        document.getElementById('chatbot-messages').addEventListener('click', (e) => {
            const chip = e.target.closest('.cb-chip');
            if (chip) {
                const prompt = chip.dataset.prompt;
                // Remove chips after first use
                const chipsEl = document.getElementById('cb-chips');
                if (chipsEl) chipsEl.remove();
                input.value = prompt;
                this.sendMessage();
            }
        });

        // History toggle button
        const historyToggle = document.getElementById('cb-history-toggle');
        if (historyToggle) historyToggle.addEventListener('click', () => this.toggleHistory());

        // History close button
        const historyClose = document.getElementById('cb-history-close');
        if (historyClose) historyClose.addEventListener('click', () => this.closeHistory());

        // New conversation button
        const historyNew = document.getElementById('cb-history-new');
        if (historyNew) historyNew.addEventListener('click', () => this.startNewConversation());

        // Close history on outside click within the panel
        const panel = document.getElementById('chatbot-panel');
        if (panel) {
            panel.addEventListener('click', (e) => {
                if (this.historyOpen && !e.target.closest('#cb-history-sidebar') && !e.target.closest('#cb-history-toggle')) {
                    this.closeHistory();
                }
            });
        }

        // Prompt selector modal (kept for compatibility)
        const promptSelectorClose = document.getElementById('prompt-selector-close');
        if (promptSelectorClose) promptSelectorClose.addEventListener('click', () => this.closePromptSelector());
        const promptSelectorModal = document.getElementById('prompt-selector-modal');
        if (promptSelectorModal) {
            promptSelectorModal.addEventListener('click', (e) => {
                if (e.target.id === 'prompt-selector-modal') this.closePromptSelector();
            });
        }

        this.initDrag();
    }

    initDrag() {
        const panel  = document.getElementById('chatbot-panel');
        if (!panel) return;
        const handle = panel.querySelector('.cb-header');
        if (!handle) return;

        let dragging = false;
        let startX, startY, startLeft, startTop;

        const onStart = (e) => {
            if (e.target.closest('#chatbot-close') || e.target.closest('#cb-history-toggle')) return;
            if (!panel.classList.contains('open')) return;
            dragging = true;
            const touch = e.touches ? e.touches[0] : e;
            startX = touch.clientX;
            startY = touch.clientY;
            const rect = panel.getBoundingClientRect();
            panel.style.setProperty('transition', 'none', 'important');
            panel.style.setProperty('transform',  'none', 'important');
            panel.style.left   = rect.left + 'px';
            panel.style.top    = rect.top  + 'px';
            panel.style.right  = 'auto';
            panel.style.bottom = 'auto';
            startLeft = rect.left;
            startTop  = rect.top;
            document.body.style.userSelect = 'none';
            e.preventDefault();
        };

        const onMove = (e) => {
            if (!dragging) return;
            const touch = e.touches ? e.touches[0] : e;
            const newLeft = Math.max(0, Math.min(startLeft + touch.clientX - startX, window.innerWidth  - panel.offsetWidth));
            const newTop  = Math.max(0, Math.min(startTop  + touch.clientY - startY, window.innerHeight - panel.offsetHeight));
            panel.style.left = newLeft + 'px';
            panel.style.top  = newTop  + 'px';
            e.preventDefault();
        };

        const onEnd = () => {
            if (!dragging) return;
            dragging = false;
            document.body.style.userSelect = '';
            panel.style.removeProperty('transition');
            panel.style.removeProperty('transform');
        };

        handle.addEventListener('mousedown',  onStart);
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup',   onEnd);
        handle.addEventListener('touchstart',  onStart, { passive: false });
        document.addEventListener('touchmove', onMove,  { passive: false });
        document.addEventListener('touchend',  onEnd);
    }

    toggle() {
        if (this.isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        this.isOpen = true;
        const panel = document.getElementById('chatbot-panel');
        if (panel.style.transform === 'none') {
            panel.style.transform  = '';
            panel.style.transition = '';
        }
        panel.classList.add('open');
        document.getElementById('chatbot-button').classList.add('active');
        const input = document.getElementById('chatbot-input');
        if (input) input.focus();
        this.fetchDatabaseContext(true).catch(() => {});
    }

    close() {
        this.isOpen = false;
        const panel = document.getElementById('chatbot-panel');
        panel.classList.remove('open');
        panel.style.left = panel.style.top = panel.style.right = panel.style.bottom = '';
        panel.style.transform = panel.style.transition = '';
        document.getElementById('chatbot-button').classList.remove('active');
    }

    async sendMessage() {
        const input = document.getElementById('chatbot-input');
        const message = input.value.trim();

        if (!message) return;

        // Clear input
        input.value = '';

        // Add user message to UI
        this.addMessage('user', message);

        // Add to conversation history
        this.conversationHistory.push({
            role: 'user',
            content: message,
            time: new Date().toISOString()
        });

        // Show loading
        this.showLoading();

        try {
            let responseText = '';

            // Call server-side API (Groq with key rotation)
            try {
                const serverRes = await fetch(this.apiBase + 'chatbot.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    credentials: 'include',
                    body: JSON.stringify({
                        session_id: this.currentSessionId,
                        title: this.getSessionTitle({messages: this.conversationHistory}),
                        message: message,
                        history: this.conversationHistory.slice(-10)
                    })
                });

                const rawText = await serverRes.text();
                let serverData;
                try {
                    serverData = JSON.parse(rawText);
                } catch (parseErr) {
                    console.error('Non-JSON response:', rawText.substring(0, 300));
                    throw new Error('Server error. Check PHP logs.');
                }

                if (serverData.success && serverData.response) {
                    responseText = serverData.response;
                } else if (serverData.error) {
                    throw new Error(serverData.error);
                } else {
                    throw new Error('Unexpected server response.');
                }
            } catch (fetchErr) {
                if (fetchErr instanceof TypeError) {
                    throw new Error('Network error — cannot reach server.');
                }
                throw fetchErr;
            }

            // Ensure we have a valid string
            if (!responseText || responseText.trim().length === 0) {
                throw new Error('Empty response from server.');
            }
            
            // Trim the response
            responseText = responseText.trim();

            // Extract actions from response
            console.log('🤖 Raw AI Response:', responseText);
            const { cleanText, actions } = this.extractActions(responseText);
            console.log('🤖 Clean Text:', cleanText);
            console.log('🤖 Extracted Actions:', actions);
            responseText = cleanText;

            // Add bot response to UI
            this.addMessage('bot', responseText);

            // Execute actions if any
            if (actions && actions.length > 0) {
                this.executeActions(actions);
            }

            // Add to conversation history
            this.conversationHistory.push({
                role: 'assistant',
                content: responseText,
                time: new Date().toISOString()
            });

            // Persist to localStorage
            this.saveCurrentSession();

        } catch (error) {
            console.error('Chatbot error:', error);
            let errorMessage = error.message || 'Something went wrong. Please try again.';
            
            // Make rate limit errors more user-friendly
            if (errorMessage.toLowerCase().includes('rate limit')) {
                errorMessage = 'I\'m a bit busy right now. Please wait a few seconds and try again.';
            }
            
            this.addMessage('bot', errorMessage);
        } finally {
            this.hideLoading();
            input.focus();
        }
    }

    addMessage(role, content) {
        const container = document.getElementById('chatbot-messages');
        const botImgPath = this.apiBase.replace('/api/', '/app/assets/img/bot.png');
        const row = document.createElement('div');
        row.className = `cb-msg-row ${role === 'user' ? 'cb-user-row' : 'cb-bot-row'}`;

        const formattedContent = this.formatMessageContent(content);

        if (role === 'user') {
            row.innerHTML = `<div class="cb-bubble cb-user-bubble"><div class="cb-bubble-text">${formattedContent}</div></div>`;
        } else {
            row.innerHTML = `
                <img src="${botImgPath}" alt="" class="cb-bubble-avatar">
                <div class="cb-bubble cb-bot-bubble"><div class="cb-bubble-text">${formattedContent}</div></div>
            `;
        }

        container.appendChild(row);
        container.scrollTop = container.scrollHeight;
    }

    showLoading() {
        const el = document.getElementById('chatbot-loading');
        if (el) el.style.display = 'flex';
        const container = document.getElementById('chatbot-messages');
        if (container) container.scrollTop = container.scrollHeight;
    }

    hideLoading() {
        const el = document.getElementById('chatbot-loading');
        if (el) el.style.display = 'none';
    }

    /**
     * Format message content with lists, bullet points, and proper HTML
     */
    formatMessageContent(content) {
        if (!content) return '';

        // Step 1: Convert markdown-style formatting to HTML (before escaping)
        // First, convert **bold** to <strong> (handle multiple occurrences)
        content = content.replace(/\*\*([^*]+?)\*\*/g, '<strong>$1</strong>');
        
        // Then convert remaining single *italic* to <em>
        // This works because we already converted **bold** above
        content = content.replace(/\*([^*\n]+?)\*/g, '<em>$1</em>');
        
        // Step 2: Remove any remaining standalone asterisks
        // This handles cases where asterisks appear alone or incorrectly formatted
        content = content.replace(/\*/g, '');
        
        // Step 3: Escape HTML (but preserve our added tags)
        let formatted = content;
        
        // Temporarily replace our HTML tags with placeholders
        formatted = formatted.replace(/<strong>/g, '___STRONG_START___');
        formatted = formatted.replace(/<\/strong>/g, '___STRONG_END___');
        formatted = formatted.replace(/<em>/g, '___EM_START___');
        formatted = formatted.replace(/<\/em>/g, '___EM_END___');
        
        // Escape HTML
        formatted = this.escapeHtml(formatted);
        
        // Restore our HTML tags
        formatted = formatted.replace(/___STRONG_START___/g, '<strong>');
        formatted = formatted.replace(/___STRONG_END___/g, '</strong>');
        formatted = formatted.replace(/___EM_START___/g, '<em>');
        formatted = formatted.replace(/___EM_END___/g, '</em>');

        // Split content into lines for better processing
        const lines = formatted.split('\n');
        const processedLines = [];
        let inNumberedList = false;
        let inBulletList = false;
        let listItems = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            
            // Check for numbered list items (1. 2. 3. or 1) 2) 3))
            const numberedMatch = line.match(/^(\d+)[\.\)]\s+(.+)$/);
            if (numberedMatch) {
                if (!inNumberedList) {
                    // Close previous bullet list if open
                    if (inBulletList && listItems.length > 0) {
                        processedLines.push(`<ul class="message-list">${listItems.join('')}</ul>`);
                        listItems = [];
                        inBulletList = false;
                    }
                    inNumberedList = true;
                }
                listItems.push(`<li>${numberedMatch[2]}</li>`);
                continue;
            }

            // Check for bullet points (-, *, •, or - )
            const bulletMatch = line.match(/^[-*•]\s+(.+)$/);
            if (bulletMatch) {
                if (!inBulletList) {
                    // Close previous numbered list if open
                    if (inNumberedList && listItems.length > 0) {
                        processedLines.push(`<ol class="message-list">${listItems.join('')}</ol>`);
                        listItems = [];
                        inNumberedList = false;
                    }
                    inBulletList = true;
                }
                listItems.push(`<li>${bulletMatch[1]}</li>`);
                continue;
            }

            // Empty line - close any open lists
            if (line === '') {
                if (inNumberedList && listItems.length > 0) {
                    processedLines.push(`<ol class="message-list">${listItems.join('')}</ol>`);
                    listItems = [];
                    inNumberedList = false;
                } else if (inBulletList && listItems.length > 0) {
                    processedLines.push(`<ul class="message-list">${listItems.join('')}</ul>`);
                    listItems = [];
                    inBulletList = false;
                }
                processedLines.push('');
                continue;
            }

            // Regular text line
            if (inNumberedList && listItems.length > 0) {
                processedLines.push(`<ol class="message-list">${listItems.join('')}</ol>`);
                listItems = [];
                inNumberedList = false;
            } else if (inBulletList && listItems.length > 0) {
                processedLines.push(`<ul class="message-list">${listItems.join('')}</ul>`);
                listItems = [];
                inBulletList = false;
            }
            processedLines.push(line);
        }

        // Close any remaining lists
        if (inNumberedList && listItems.length > 0) {
            processedLines.push(`<ol class="message-list">${listItems.join('')}</ol>`);
        } else if (inBulletList && listItems.length > 0) {
            processedLines.push(`<ul class="message-list">${listItems.join('')}</ul>`);
        }

        // Join lines and format paragraphs
        formatted = processedLines.join('\n');

        // Convert line breaks to <br> for paragraphs
        formatted = formatted.split('\n\n').map(paragraph => {
            // Skip if it's already a list
            if (paragraph.includes('<ol') || paragraph.includes('<ul')) {
                return paragraph;
            }
            // Convert single line breaks to <br>
            paragraph = paragraph.replace(/\n/g, '<br>');
            // Wrap in <p> if it's not empty
            return paragraph.trim() ? `<p>${paragraph.trim()}</p>` : '';
        }).join('');

        // Clean up empty paragraphs
        formatted = formatted.replace(/<p>\s*<\/p>/g, '');
        formatted = formatted.replace(/<p><br><\/p>/g, '');

        return formatted;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Extract JSON actions from AI response
     */
    extractActions(text) {
        const actions = [];
        let cleanText = text;

        // 1. FIRST: Find ALL possible code blocks (json or not)
        const allCodeBlockRegex = /```(?:json)?\s*([\s\S]*?)\s*```/g;
        let match;
        let tempText = text;
        const matchesToRemove = [];
        
        // Collect all code blocks first
        while ((match = allCodeBlockRegex.exec(tempText)) !== null) {
            try {
                // Strip JS-style comments before parsing (AI sometimes adds // comments)
                const stripped = match[1].trim()
                    .replace(/\/\/[^\n]*/g, '')   // remove // line comments
                    .replace(/\/\*[\s\S]*?\*\//g, ''); // remove /* block comments */
                const actionData = JSON.parse(stripped);
                if (actionData.action) {
                    actions.push(actionData);
                    matchesToRemove.push(match[0]);
                    console.log('🤖 Extracted action from code block:', actionData);
                }
            } catch (e) {
                // Not valid JSON, skip
                console.warn('Code block not valid action JSON:', e);
            }
        }
        
        // 2. Now remove all the matched code blocks from cleanText
        matchesToRemove.forEach(block => {
            cleanText = cleanText.replace(block, '');
        });
        
        // 3. If still no actions, try loose JSON matching
        if (actions.length === 0) {
            const looseJsonRegex = /\{[\s\S]*?"action"[\s\S]*?\}/g;
            while ((match = looseJsonRegex.exec(text)) !== null) {
                try {
                    const actionData = JSON.parse(match[0]);
                    if (actionData.action) {
                        actions.push(actionData);
                        cleanText = cleanText.replace(match[0], '');
                        console.log('🤖 Extracted loose action JSON:', actionData);
                    }
                } catch (e) {
                    console.warn('Failed to parse loose JSON:', e);
                }
            }
        }

        // 4. FINAL CLEANUP: Remove extra newlines/whitespace from cleanText
        cleanText = cleanText
            .replace(/\n\s*\n\s*\n/g, '\n\n') // Collapse multiple blank lines
            .replace(/^\s+|\s+$/g, '')       // Trim
            .trim();

        return { cleanText, actions };
    }

    /**
     * Execute actions suggested by the AI
     */
    async executeActions(actions) {
        console.log('🤖 executeActions called with:', actions);

        // Deduplicate: only ever execute ONE create_violation per response.
        // If multiple exist, prefer the one with student_id (most reliable).
        // This prevents the AI's summary/example blocks from also executing.
        const deduped = [];
        let bestViolationAction = null;

        for (const actionData of actions) {
            if (actionData.action === 'create_violation') {
                const p = actionData.params || {};
                const hasStudent = !!(p.student_id || p.student_name);
                const hasType = !!(p.violation_type_id || p.violation_type_name);
                if (!hasStudent || !hasType) continue; // skip incomplete ones entirely

                // Prefer student_id over student_name (more reliable)
                if (!bestViolationAction) {
                    bestViolationAction = actionData;
                } else if (p.student_id && !(bestViolationAction.params || {}).student_id) {
                    bestViolationAction = actionData; // upgrade to one with actual ID
                }
                // else keep current best - intentionally ignore extras
            } else {
                deduped.push(actionData);
            }
        }

        if (bestViolationAction) {
            deduped.push(bestViolationAction); // add exactly one violation action
        }

        for (const actionData of deduped) {
            const { action, params } = actionData;
            console.log('🤖 Executing system action:', action, params);

            try {
                switch (action) {
                    case 'create_violation_type':
                        await this.handleCreateType(params);
                        break;
                    case 'create_violation_level':
                        await this.handleCreateLevel(params);
                        break;
                    case 'create_violation':
                        // Extra validation: Don't execute if params are empty or missing critical data
                        if (!params || (!params.student_id && !params.student_name)) {
                            console.warn('🤖 create_violation blocked: missing student identifier', params);
                            // Don't show error to user - AI shouldn't have sent this
                            break;
                        }
                        if (!params.violation_type_id && !params.violation_type_name) {
                            console.warn('🤖 create_violation blocked: missing violation type', params);
                            // Don't show error to user - AI shouldn't have sent this
                            break;
                        }
                        await this.handleCreateViolation(params);
                        break;
                    case 'export_pdf':
                        console.log('🤖 Calling handleExportPDF');
                        await this.handleExportPDF(params);
                        break;
                    default:
                        console.warn('Unknown action:', action);
                }
            } catch (err) {
                console.error(`Action ${action} failed:`, err);
                this.addMessage('bot', `⚠️ I tried to perform that action but encountered an error: ${err.message}`);
            }
        }
    }

    async handleCreateType(params) {
        if (!params.name) throw new Error('Type name is required');
        
        const res = await fetch(this.apiBase + 'violations.php?action=create_type', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: params.name })
        });
        const data = await res.json();
        if (data.status === 'success') {
            this.addMessage('bot', `✅ Successfully created violation type: **${params.name}**`);
            // Trigger UI refresh if we are on the violations page
            if (typeof loadViolationTypes === 'function') loadViolationTypes(true);
        } else throw new Error(data.message);
    }

    async handleCreateLevel(params) {
        if (!params.type_id || !params.name) throw new Error('Type ID and Level Name are required');
        
        const res = await fetch(this.apiBase + 'violations.php?action=create_level', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                violation_type_id: params.type_id,
                name: params.name,
                default_status: params.status || 'Warning',
                status_color: '#f59e0b'
            })
        });
        const data = await res.json();
        if (data.status === 'success') {
            this.addMessage('bot', `✅ Successfully added level **${params.name}** to the violation type.`);
            if (typeof loadViolationTypes === 'function') loadViolationTypes(true);
        } else throw new Error(data.message);
    }

    async handleExportPDF(params) {
        console.log('🤖 handleExportPDF called with params:', params);
        
        // Validation check
        if (!params || !params.module) {
            console.error('Bot Export Error: Missing module parameter', params);
            this.addMessage('bot', `⚠️ I tried to export a report but didn't know which module to use. Please specify if you want a **violations**, **students**, **departments**, or **sections** report.`);
            return;
        }

        const moduleName = params.module.charAt(0).toUpperCase() + params.module.slice(1);
        
        try {
            // Identify what data we need to fetch
            let apiEndpoint = '';
            let columns = [];
            let title = `OSAS ${params.module.toUpperCase()} REPORT`;

            if (params.module === 'violations') {
                apiEndpoint = 'violations.php?action=get&filter=active&limit=all';
                columns = [
                    { header: 'Student', dataKey: 'studentName' },
                    { header: 'Type', dataKey: 'violationType' },
                    { header: 'Level', dataKey: 'violationLevel' },
                    { header: 'Status', dataKey: 'status' },
                    { header: 'Date', dataKey: 'violationDate' }
                ];
            } else if (params.module === 'students') {
                apiEndpoint = 'students.php?action=get&filter=active&limit=all';
                columns = [
                    { header: 'ID', dataKey: 'studentId' },
                    { header: 'First Name', dataKey: 'firstName' },
                    { header: 'Last Name', dataKey: 'lastName' },
                    { header: 'Department', dataKey: 'department' },
                    { header: 'Section', dataKey: 'section' }
                ];
            } else if (params.module === 'departments') {
                apiEndpoint = 'departments.php?action=get&filter=active&limit=1000';
                columns = [
                    { header: 'Code', dataKey: 'code' },
                    { header: 'Department Name', dataKey: 'name' },
                    { header: 'HOD', dataKey: 'hod' },
                    { header: 'Students', dataKey: 'student_count' }
                ];
            } else if (params.module === 'sections') {
                apiEndpoint = 'sections.php?action=get&filter=active&limit=all';
                columns = [
                    { header: 'Section Name', dataKey: 'name' },
                    { header: 'Department', dataKey: 'department' },
                    { header: 'Academic Year', dataKey: 'academic_year' },
                    { header: 'Students', dataKey: 'student_count' },
                    { header: 'Status', dataKey: 'status' }
                ];
            } else {
                throw new Error(`Unknown module: ${params.module}`);
            }
            
            console.log('🤖 handleExportPDF - apiEndpoint:', this.apiBase + apiEndpoint);
            
            // Check if container exists
            const container = document.getElementById('chatbot-messages');
            if (!container) {
                throw new Error('Chat messages container not found');
            }
            
            // Create a custom bubble with a download button
            const botImgPath = this.apiBase.replace('/api/', '/app/assets/img/bot.png');
            const row = document.createElement('div');
            row.className = 'cb-msg-row cb-bot-row';
            
            const timestamp = new Date().toISOString().slice(0,10);
            const fileName = `OSAS_${params.module}_Report_${timestamp}.pdf`;

            row.innerHTML = `
                <img src="${botImgPath}" alt="" class="cb-bubble-avatar">
                <div class="cb-bubble cb-bot-bubble">
                    <div class="cb-bubble-text">
                        <div style="margin-bottom: 10px;">📄 Your <strong>${moduleName}</strong> report is ready:</div>
                        <button class="cb-download-btn" id="dl-btn-${Date.now()}" style="display: flex; align-items: center; gap: 8px; background: var(--gold); color: #fff; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-weight: 600; width: 100%; justify-content: center; transition: opacity 0.2s;">
                            <i class='bx bxs-file-pdf' style="font-size: 18px;"></i>
                            Download PDF
                        </button>
                    </div>
                </div>
            `;

            container.appendChild(row);
            container.scrollTop = container.scrollHeight;
            console.log('🤖 handleExportPDF - Download button added to DOM');

            // Attach click event to the newly created button
            const btn = row.querySelector('.cb-download-btn');
            if (!btn) {
                throw new Error('Download button not found after creation');
            }
            
            btn.onclick = async () => {
                btn.disabled = true;
                btn.innerHTML = `<i class='bx bx-loader-alt bx-spin'></i> Generating...`;
                
                try {
                    console.log('🤖 handleExportPDF - Fetching data from:', this.apiBase + apiEndpoint);
                    const res = await fetch(this.apiBase + apiEndpoint);
                    const responseData = await res.json();
                    console.log('🤖 handleExportPDF - API response:', responseData);
                    
                    // Standardize data extraction based on our API structure
                    let exportData = [];
                    if (responseData.status === 'success') {
                        if (params.module === 'departments') {
                            exportData = responseData.data.departments || [];
                        } else if (params.module === 'violations') {
                            exportData = responseData.data.violations || responseData.data || [];
                        } else if (params.module === 'students') {
                            exportData = responseData.data.students || responseData.data || [];
                        } else if (params.module === 'sections') {
                            exportData = responseData.data.sections || [];
                        }
                    }

                    // Apply any filters from params
                    if (params.module === 'violations') {
                        let startDate = null;
                        let endDate = new Date();
                        
                        if (params.date === 'today') {
                            startDate = new Date();
                            endDate = new Date();
                        } else if (params.date === 'yesterday' || params.date === 'last day') {
                            startDate = new Date();
                            startDate.setDate(startDate.getDate() - 1);
                            endDate = new Date(startDate);
                        } else if (params.date === 'last week' || params.date === 'past week') {
                            startDate = new Date();
                            startDate.setDate(startDate.getDate() - 7);
                        } else if (params.date === 'last month' || params.date === 'past month') {
                            startDate = new Date();
                            startDate.setMonth(startDate.getMonth() - 1);
                        } else if (params.date) {
                            // Parse relative dates like "3 days ago", "2 weeks ago", "1 month ago"
                            const daysMatch = params.date.match(/(\d+)\s*days?\s*ago/i);
                            const weeksMatch = params.date.match(/(\d+)\s*weeks?\s*ago/i);
                            const monthsMatch = params.date.match(/(\d+)\s*months?\s*ago/i);
                            const lastXDaysMatch = params.date.match(/last\s*(\d+)\s*days?/i);
                            const lastXWeeksMatch = params.date.match(/last\s*(\d+)\s*weeks?/i);
                            const lastXMonthsMatch = params.date.match(/last\s*(\d+)\s*months?/i);
                            
                            if (daysMatch) {
                                const daysAgo = parseInt(daysMatch[1]);
                                startDate = new Date();
                                startDate.setDate(startDate.getDate() - daysAgo);
                                endDate = new Date();
                            } else if (weeksMatch) {
                                const weeksAgo = parseInt(weeksMatch[1]);
                                startDate = new Date();
                                startDate.setDate(startDate.getDate() - (weeksAgo * 7));
                                endDate = new Date();
                            } else if (monthsMatch) {
                                const monthsAgo = parseInt(monthsMatch[1]);
                                startDate = new Date();
                                startDate.setMonth(startDate.getMonth() - monthsAgo);
                                endDate = new Date();
                            } else if (lastXDaysMatch) {
                                const days = parseInt(lastXDaysMatch[1]);
                                startDate = new Date();
                                startDate.setDate(startDate.getDate() - days);
                                endDate = new Date();
                            } else if (lastXWeeksMatch) {
                                const weeks = parseInt(lastXWeeksMatch[1]);
                                startDate = new Date();
                                startDate.setDate(startDate.getDate() - (weeks * 7));
                                endDate = new Date();
                            } else if (lastXMonthsMatch) {
                                const months = parseInt(lastXMonthsMatch[1]);
                                startDate = new Date();
                                startDate.setMonth(startDate.getMonth() - months);
                                endDate = new Date();
                            }
                        }
                        
                        if (startDate) {
                            const startStr = startDate.toISOString().split('T')[0];
                            const endStr = endDate.toISOString().split('T')[0];
                            
                            exportData = exportData.filter(violation => {
                                const violationDate = violation.violationDate || violation.dateReported;
                                if (!violationDate) return false;
                                const vDate = new Date(violationDate).toISOString().split('T')[0];
                                return vDate >= startStr && vDate <= endStr;
                            });
                        }
                    }
                    console.log('🤖 handleExportPDF - Export data ready, count:', exportData.length);

                    if (exportData.length > 0 && typeof window.jspdf !== 'undefined' && window.jspdf.jsPDF) {
                        console.log('🤖 handleExportPDF - Generating PDF');
                        const { jsPDF } = window.jspdf;
                        const doc = new jsPDF();
                        
                        // Add proper header logo
                        const headerPath = this.getProjectRoot() + '/app/assets/headers/header.png';
                        const headerData = await this.loadImage(headerPath);
                        
                        if (headerData) {
                            doc.addImage(headerData, 'PNG', 38, 5, 140, 25);
                        } else {
                            doc.setFontSize(22);
                            doc.setTextColor(44, 62, 80);
                            doc.setFont('helvetica', 'bold');
                            doc.text('E-OSAS SYSTEM', 14, 20);
                            doc.setFontSize(10);
                            doc.setFont('helvetica', 'normal');
                            doc.setTextColor(127, 140, 141);
                            doc.text('Office of Student Affairs and Services', 14, 28);
                        }
                        
                        // Report title and date
                        doc.setFontSize(12);
                        doc.setTextColor(44, 62, 80);
                        doc.setFont('helvetica', 'bold');
                        doc.text(title, 14, 45);
                        doc.setFontSize(10);
                        doc.setFont('helvetica', 'normal');
                        doc.setTextColor(127, 140, 141);
                        doc.text(`Generated by OSAS Bot on ${new Date().toLocaleString()}`, 14, 51);

                        doc.autoTable({
                            startY: 55,
                            head: [columns.map(col => col.header)],
                            body: exportData.map(row => columns.map(col => row[col.dataKey] || '')),
                            theme: 'striped',
                            headStyles: { fillColor: [212, 175, 55] }
                        });

                        doc.save(fileName);
                        btn.innerHTML = `<i class='bx bx-check'></i> Downloaded`;
                        btn.style.background = '#10b981'; // Green
                    } else {
                        if (typeof window.jspdf === 'undefined') {
                            throw new Error('PDF library (jsPDF) not loaded');
                        }
                        if (exportData.length === 0) {
                            throw new Error('No data available to export');
                        }
                        throw new Error('PDF generation failed');
                    }
                } catch (err) {
                    btn.innerHTML = `<i class='bx bx-error'></i> Error`;
                    btn.style.background = '#ef4444';
                    console.error('Download failed:', err);
                    this.addMessage('bot', `❌ Download failed: ${err.message}`);
                }
            };

        } catch (err) {
            console.error('Bot Export UI Error:', err);
            this.addMessage('bot', `❌ Failed to prepare the download: ${err.message}`);
        }
    }

    /**
     * Find student by name
     */
    async findStudentByName(studentName) {
        try {
            console.log('🤖 findStudentByName called with:', studentName);
            const res = await fetch(this.apiBase + 'students.php?filter=active&limit=all');
            const data = await res.json();
            console.log('🤖 Students API response status:', data.status, '| count:', data.data?.students?.length);
            
            if (data.status !== 'success') return null;
            
            // API returns { data: { students: [...] } }
            const students = data.data?.students || data.data || [];
            console.log('🤖 Total students loaded:', students.length);
            if (students.length > 0) console.log('🤖 Sample student object keys:', Object.keys(students[0]));
            
            const nameLower = studentName.toLowerCase().trim();
            
            // Fields are camelCase: studentId, firstName, middleName, lastName
            for (const s of students) {
                const first = (s.firstName || s.first_name || '').toLowerCase().trim();
                const last  = (s.lastName  || s.last_name  || '').toLowerCase().trim();
                const mid   = (s.middleName || s.middle_name || '').toLowerCase().trim();
                
                const fullName       = `${first} ${last}`.trim();
                const fullWithMid    = `${first} ${mid} ${last}`.trim();
                const reverseName    = `${last} ${first}`.trim();
                const reverseWithMid = `${last} ${first} ${mid}`.trim();
                
                if ([fullName, fullWithMid, reverseName, reverseWithMid].includes(nameLower)) {
                    console.log('🤖 Exact match found:', s);
                    return s;
                }
            }
            
            // Partial match
            const matches = students.filter(s => {
                const first = (s.firstName || s.first_name || '').toLowerCase();
                const last  = (s.lastName  || s.last_name  || '').toLowerCase();
                const mid   = (s.middleName || s.middle_name || '').toLowerCase();
                return `${first} ${last}`.includes(nameLower) ||
                       `${last} ${first}`.includes(nameLower) ||
                       `${first} ${mid} ${last}`.includes(nameLower) ||
                       first.includes(nameLower) || last.includes(nameLower);
            });
            
            console.log('🤖 Partial matches:', matches.length);
            if (matches.length === 1) return matches[0];
            return matches;
        } catch (err) {
            console.error('Error finding student:', err);
            return null;
        }
    }

    /**
     * Find violation type by name or ID
     */
    async findViolationType(typeNameOrId) {
        try {
            const res = await fetch(this.apiBase + 'violations.php?action=types');
            const data = await res.json();
            if (data.status !== 'success') return null;
            
            const types = data.data || [];
            const searchLower = String(typeNameOrId).toLowerCase().trim();
            
            for (const t of types) {
                if (String(t.id) === String(typeNameOrId) || t.name.toLowerCase().trim() === searchLower) {
                    return t;
                }
            }
            
            // Try partial match
            const matches = types.filter(t => t.name.toLowerCase().trim().includes(searchLower));
            if (matches.length === 1) return matches[0];
            
            return matches;
        } catch (err) {
            console.error('Error finding violation type:', err);
            return null;
        }
    }

    /**
     * Get next violation level for a student and type
     */
    async getNextViolationLevel(studentId, violationTypeId) {
        try {
            console.log('🤖 getNextViolationLevel called with:', { studentId, violationTypeId });
            
            const res = await fetch(this.apiBase + 'violations.php?action=types');
            const data = await res.json();
            console.log('🤖 Violation types response:', data);
            
            if (data.status !== 'success') return null;
            
            const types = data.data || [];
            const type = types.find(t => t.id == violationTypeId);
            console.log('🤖 Found violation type:', type);
            
            if (!type || !type.levels || type.levels.length === 0) {
                console.warn('🤖 No levels found for type:', type);
                return null;
            }
            
            // Get student's previous violations for this type
            const violRes = await fetch(this.apiBase + 'violations.php?is_archived=0');
            const violData = await violRes.json();
            console.log('🤖 Student violations response:', violData);
            
            if (violData.status !== 'success') {
                console.log('🤖 Returning first level (no previous violations)');
                return type.levels[0];
            }
            
            const violations = violData.violations || violData.data || [];
            const studentViolations = violations.filter(v => {
                // API returns: studentId, violationType (number), violationLevel (number)
                const vStudentId = v.studentId || v.student_id || '';
                const vTypeId    = v.violationType || v.violation_type_id || v.violationTypeId || '';
                return String(vStudentId) === String(studentId) &&
                       String(vTypeId)    === String(violationTypeId);
            }).sort((a, b) => {
                const dateA = new Date(a.created_at || a.createdAt || a.dateReported);
                const dateB = new Date(b.created_at || b.createdAt || b.dateReported);
                return dateB - dateA;
            });
            
            console.log('🤖 Student violations for this type:', studentViolations.length, studentViolations.map(v => ({ caseId: v.caseId, level: v.violationLevel, label: v.violationLevelLabel })));
            
            const lastViolation = studentViolations[0];
            
            if (!lastViolation) {
                console.log('🤖 No previous violations, returning first level:', type.levels[0]);
                return type.levels[0];
            }
            
            // API returns violationLevel as the level ID (number)
            const lastLevelId = lastViolation.violationLevel || lastViolation.violation_level_id || lastViolation.violationLevelId;
            const currentLevelIndex = type.levels.findIndex(l => String(l.id) === String(lastLevelId));
            
            console.log('🤖 Last violation level ID:', lastLevelId);
            console.log('🤖 Current level index in levels array:', currentLevelIndex);
            console.log('🤖 All levels for this type:', type.levels.map(l => ({ id: l.id, name: l.name, order: l.level_order })));
            
            if (currentLevelIndex === -1) {
                console.warn('🤖 Previous level not found in current levels array, returning first level');
                return type.levels[0];
            }
            
            if (currentLevelIndex < type.levels.length - 1) {
                const nextLevel = type.levels[currentLevelIndex + 1];
                console.log('🤖 Moving to next level:', nextLevel);
                return nextLevel;
            }
            
            console.log('🤖 Already at max level, keeping current level:', type.levels[type.levels.length - 1]);
            return type.levels[type.levels.length - 1]; // Last level if already max
        } catch (err) {
            console.error('Error getting next violation level:', err);
            return null;
        }
    }

    /**
     * Handle create violation action
     */
    async handleCreateViolation(params) {
        try {
            console.log('🤖 handleCreateViolation called with params:', params);
            
            let studentId = params.student_id;
            if (!studentId && params.student_name) {
                console.log('🤖 Looking up student by name:', params.student_name);
                const studentResult = await this.findStudentByName(params.student_name);
                console.log('🤖 Student lookup result:', studentResult);
                
                if (!studentResult || (Array.isArray(studentResult) && studentResult.length === 0)) {
                    throw new Error(`Student "${params.student_name}" not found in the system.`);
                }
                if (Array.isArray(studentResult) && studentResult.length > 1) {
                    const names = studentResult.slice(0,5).map(s => `${s.firstName} ${s.lastName} (${s.studentId})`).join(', ');
                    this.addMessage('bot', `⚠️ Found ${studentResult.length} students matching "${params.student_name}": ${names}. Please be more specific or use the student ID.`);
                    return;
                }
                const student = Array.isArray(studentResult) ? studentResult[0] : studentResult;
                // Model returns camelCase: studentId
                studentId = student.studentId || student.student_id;
                if (!studentId) {
                    console.error('🤖 Student object has no ID field:', student);
                    throw new Error(`Could not resolve student ID for "${params.student_name}". Student object: ${JSON.stringify(student)}`);
                }
                console.log('🤖 Resolved student ID:', studentId);
            }
            
            let violationTypeId = params.violation_type_id;
            if (!violationTypeId && params.violation_type_name) {
                console.log('🤖 Looking up violation type by name:', params.violation_type_name);
                const typeResult = await this.findViolationType(params.violation_type_name);
                console.log('🤖 Violation type lookup result:', typeResult);
                
                if (!typeResult) {
                    throw new Error(`Violation type "${params.violation_type_name}" not found.`);
                }
                if (Array.isArray(typeResult) && typeResult.length > 1) {
                    this.addMessage('bot', `⚠️ Found multiple violation types matching "${params.violation_type_name}". Please be more specific.`);
                    return;
                }
                violationTypeId = Array.isArray(typeResult) ? typeResult[0].id : typeResult.id;
                console.log('🤖 Resolved violation type ID:', violationTypeId);
            }
            
            if (!studentId) {
                throw new Error('Student ID or name is required.');
            }
            if (!violationTypeId) {
                throw new Error('Violation type ID or name is required.');
            }
            
            const nextLevel = await this.getNextViolationLevel(studentId, violationTypeId);
            // Always auto-detect the next level - ignore any level ID the AI may have passed
            console.log('🤖 getNextViolationLevel returned:', nextLevel);
            
            if (!nextLevel) {
                throw new Error('No violation levels found for this violation type.');
            }
            
            if (!nextLevel.id) {
                console.error('🤖 nextLevel missing id property:', nextLevel);
                throw new Error('Invalid violation level data - missing ID.');
            }
            
            const violationDate = params.violation_date || new Date().toISOString().split('T')[0];
            const violationTime = params.violation_time || new Date().toTimeString().slice(0, 5);
            const location = params.location || 'School Campus';
            const status = params.status || nextLevel.default_status || 'warning';
            const notes = params.notes || '';
            
            console.log('🤖 Creating violation with:', {
                studentId,
                violationTypeId,
                levelId: nextLevel.id,
                levelName: nextLevel.name,
                violationDate,
                violationTime,
                location,
                status,
                notes
            });
            
            const formData = new FormData();
            formData.append('studentId', studentId);
            formData.append('violationType', violationTypeId);
            formData.append('violationLevel', nextLevel.id);
            formData.append('violationDate', violationDate);
            formData.append('violationTime', violationTime);
            formData.append('location', location);
            formData.append('status', status);
            formData.append('notes', notes);
            
            const res = await fetch(this.apiBase + 'violations.php?action=create', {
                method: 'POST',
                body: formData
            });
            
            const data = await res.json();
            if (data.status !== 'success') {
                throw new Error(data.message || 'Failed to create violation.');
            }
            
            this.addMessage('bot', `✅ Violation recorded successfully! Case ID: ${data.data?.case_id || 'N/A'}\nLevel: ${nextLevel.name}`);
            
            // Refresh violations list if function exists
            if (typeof window.refreshViolationsList === 'function') {
                window.refreshViolationsList();
            } else if (typeof window.loadViolations === 'function') {
                window.loadViolations();
            }
            
        } catch (err) {
            console.error('handleCreateViolation failed:', err);
            this.addMessage('bot', `❌ Failed to record violation: ${err.message}`);
        }
    }

    togglePrompts() { /* no-op — prompts are now inline chips */ }

    usePrompt(promptText) {
        const input = document.getElementById('chatbot-input');
        if (input) {
            input.value = promptText;
            input.focus();
            setTimeout(() => this.sendMessage(), 300);
        }
    }

    openPromptSelector() {
        const modal = document.getElementById('prompt-selector-modal');
        if (modal) {
            modal.classList.add('show');
            document.body.style.overflow = 'hidden';
            // Open chatbot if not open
            if (!this.isOpen) {
                this.open();
            }
        }
    }

    closePromptSelector() {
        const modal = document.getElementById('prompt-selector-modal');
        if (modal) {
            modal.classList.remove('show');
            document.body.style.overflow = '';
        }
    }
}

// Initialize chatbot when DOM is ready
let chatbotInstance = null;

function initChatbot() {
    if (!chatbotInstance && !window.chatbotInstance) {
        chatbotInstance = new Chatbot();
        // Make it globally accessible
        window.chatbotInstance = chatbotInstance;
    }
    return chatbotInstance || window.chatbotInstance;
}

// Auto-initialize if DOM is already loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        initChatbot();
    });
} else {
    initChatbot();
}

// Also try on window load as fallback
window.addEventListener('load', function() {
    if (!window.chatbotInstance) {
        initChatbot();
    }
});

// Sidebar buttons removed - no longer needed

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = Chatbot;
}

