/**
 * Chatbot Module
 * Handles chatbot UI and API interactions
 */

class Chatbot {
    constructor() {
        this.isOpen = false;
        this.conversationHistory = [];
        this.usePuter = true; // Using Puter.js for AI responses
        this.databaseContext = null; // Cached database context
        this.contextLastFetched = null; // Timestamp of last fetch
        this.contextCacheTime = 5 * 60 * 1000; // Cache for 5 minutes
        this.apiBase = this.getAPIBasePath();
        this.init();
    }

    getAPIBasePath() {
        const currentPath = window.location.pathname;
        const pathMatch = currentPath.match(/^(\/[^\/]+)\//);
        const projectBase = pathMatch ? pathMatch[1] : '';
        
        if (projectBase) {
            return projectBase + '/api/';
        }
        
        if (currentPath.includes('/app/views/')) {
            return '../../api/';
        } else if (currentPath.includes('/includes/')) {
            return '../api/';
        } else {
            return 'api/';
        }
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
            // Check if Boxicons is already loaded
            const existingLink = document.querySelector('link[href*="boxicons"]');
            if (existingLink) {
                // Wait a bit for the font to load
                setTimeout(() => resolve(), 200);
            } else {
                // Boxicons not found, load it
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = 'https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css';
                link.onload = () => {
                    setTimeout(() => resolve(), 100);
                };
                link.onerror = () => {
                    console.warn('⚠️ Failed to load Boxicons, icons may not display correctly');
                    resolve(); // Continue even if it fails
                };
                document.head.appendChild(link);
            }
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
            // Fetch data from all existing APIs in parallel
            const [studentsRes, departmentsRes, sectionsRes, violationsRes, studentsStatsRes, announcementsRes, reportsRes] = await Promise.allSettled([
                fetch(this.apiBase + 'students.php').catch(() => null), // Get students list
                fetch(this.apiBase + 'departments.php').catch(() => null),
                fetch(this.apiBase + 'sections.php').catch(() => null),
                fetch(this.apiBase + 'violations.php').catch(() => null),
                fetch(this.apiBase + 'students.php?action=stats').catch(() => null), // Get students stats
                fetch(this.apiBase + 'announcements.php').catch(() => null), // Get announcements
                fetch(this.apiBase + 'reports.php').catch(() => null) // Get reports
            ]);

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
     * Format database context as a readable string for the AI
     */
    formatDatabaseContext(context) {
        if (!context) return '';

        let formatted = '\n\n=== OSAS SYSTEM DATABASE INFORMATION ===\n\n';

        // Add system ownership/administration information
        formatted += 'SYSTEM ADMINISTRATION:\n';
        formatted += '- System Owner/Administrator/Head: Cedrick H. Almarez\n';
        formatted += '- This is the person who owns, administers, and heads the OSAS system.\n\n';

        // Add statistics
        if (context.stats) {
            formatted += 'SYSTEM STATISTICS:\n';
            formatted += `- Total Students: ${context.stats.students || 0}\n`;
            formatted += `- Total Departments: ${context.stats.departments || 0}\n`;
            formatted += `- Total Sections: ${context.stats.sections || 0}\n`;
            formatted += `- Total Violations: ${context.stats.violations || 0}\n`;
            formatted += `- Total Announcements: ${context.stats.announcements || 0}\n`;
            formatted += `- Total Reports: ${context.stats.reports || 0}\n\n`;
        }

        // Add departments list
        if (context.departments && context.departments.length > 0) {
            formatted += 'DEPARTMENTS:\n';
            context.departments.forEach(dept => {
                formatted += `- ${dept.name} (Code: ${dept.code})\n`;
            });
            formatted += '\n';
        }

        // Add sections list
        if (context.sections && context.sections.length > 0) {
            formatted += 'SECTIONS:\n';
            context.sections.forEach(section => {
                formatted += `- ${section.name} (Code: ${section.code}, Department: ${section.department})\n`;
            });
            formatted += '\n';
        }

        // Add recent students
        if (context.recent_students && context.recent_students.length > 0) {
            formatted += 'RECENT STUDENTS (Sample):\n';
            context.recent_students.slice(0, 5).forEach(student => {
                formatted += `- ${student.name} (ID: ${student.id}, Department: ${student.department})\n`;
            });
            formatted += '\n';
        }

        // Add recent violations
        if (context.recent_violations && context.recent_violations.length > 0) {
            formatted += 'RECENT VIOLATIONS (Sample):\n';
            context.recent_violations.slice(0, 5).forEach(violation => {
                formatted += `- Case ${violation.case_id}: ${violation.student_name} - ${violation.violation_type} (${violation.status})\n`;
            });
            formatted += '\n';
        }

        // Add recent announcements
        if (context.recent_announcements && context.recent_announcements.length > 0) {
            formatted += 'RECENT ANNOUNCEMENTS (Sample):\n';
            context.recent_announcements.slice(0, 5).forEach(announcement => {
                formatted += `- "${announcement.title}" (Audience: ${announcement.audience}, Status: ${announcement.status})\n`;
                if (announcement.content && announcement.content.length > 0) {
                    const preview = announcement.content.substring(0, 100).replace(/\n/g, ' ');
                    formatted += `  Preview: ${preview}${announcement.content.length > 100 ? '...' : ''}\n`;
                }
            });
            formatted += '\n';
        }

        // Add recent reports
        if (context.recent_reports && context.recent_reports.length > 0) {
            formatted += 'RECENT REPORTS (Sample):\n';
            context.recent_reports.slice(0, 5).forEach(report => {
                formatted += `- ${report.title} (Type: ${report.type}, Status: ${report.status})\n`;
                if (report.description && report.description.length > 0) {
                    const preview = report.description.substring(0, 80).replace(/\n/g, ' ');
                    formatted += `  Description: ${preview}${report.description.length > 80 ? '...' : ''}\n`;
                }
            });
            formatted += '\n';
        }

        // Add user-specific info
        if (context.user_info) {
            formatted += 'CURRENT USER:\n';
            formatted += `- Role: ${context.user_info.role}\n`;
            if (context.user_info.violation_count !== undefined) {
                formatted += `- User's Violations: ${context.user_info.violation_count}\n`;
            }
            formatted += '\n';
        }

        formatted += '=== END OF DATABASE INFORMATION ===\n';
        formatted += '\nUse this information to answer questions about the OSAS system. You can answer questions about:\n';
        formatted += '- Students, Departments, Sections, and Violations\n';
        formatted += '- Announcements (their titles, content, audience, and status)\n';
        formatted += '- Reports (their types, descriptions, and status)\n';
        formatted += '- System statistics and data\n';
        formatted += 'If asked about specific data, refer to the information above.\n';

        return formatted;
    }

    createChatbotUI() {
        // Create chatbot button
        const chatbotButton = document.createElement('div');
        chatbotButton.id = 'chatbot-button';
        chatbotButton.innerHTML = '<i class="bx bx-message-square-dots" aria-hidden="true"></i>';
        chatbotButton.title = 'Open Chatbot';
        chatbotButton.setAttribute('aria-label', 'Open Chatbot');
        document.body.appendChild(chatbotButton);

        // Create chatbot panel
        const chatbotPanel = document.createElement('div');
        chatbotPanel.id = 'chatbot-panel';
        chatbotPanel.innerHTML = `
            <div class="chatbot-header">
                <div class="chatbot-title">
                    <i class="bx bx-bot" aria-hidden="true"></i>
                    <span>OSAS Assistant</span>
                </div>
                <button class="chatbot-close" id="chatbot-close" aria-label="Close chatbot">
                    <i class="bx bx-x" aria-hidden="true"></i>
                </button>
            </div>
            <div class="chatbot-prompts-top" id="chatbot-prompts-top">
                <div class="prompts-top-header">
                    <div class="prompts-top-title">
                        <i class="bx bx-sparkles" aria-hidden="true"></i>
                        <span>Quick Prompts</span>
                    </div>
                    <button class="prompts-top-toggle" id="prompts-top-toggle" title="Toggle prompts" aria-label="Toggle prompts">
                        <i class="bx bx-chevron-up" aria-hidden="true"></i>
                    </button>
                </div>
                <div class="prompts-top-content" id="prompts-top-content">
                    <div class="prompts-top-grid" id="prompts-top-grid">
                        <!-- Quick prompts will be added here -->
                    </div>
                </div>
            </div>
            <div class="chatbot-messages" id="chatbot-messages">
                <div class="chatbot-message bot welcome-message">
                    <div class="message-content">
                        <i class="bx bx-bot" aria-hidden="true"></i>
                        <div class="message-text">
                            <p style="margin-bottom: 12px; font-weight: 600;">Hello! I'm your OSAS assistant. 👋</p>
                            <p style="margin-bottom: 8px;">I can help you with:</p>
                            <ul style="margin: 0; padding-left: 20px; font-size: 13px; opacity: 0.9;">
                                <li>Student information and statistics</li>
                                <li>Violation management</li>
                                <li>Department and section details</li>
                                <li>System navigation and features</li>
                            </ul>
                            <p style="margin-top: 12px; font-size: 13px; opacity: 0.8;">
                                <i class="bx bx-sparkles" style="font-size: 14px;"></i> 
                                Check the <strong>Quick Prompts</strong> above for suggested questions!
                            </p>
                        </div>
                    </div>
                </div>
            </div>
            <div class="chatbot-input-container">
                <input 
                    type="text" 
                    id="chatbot-input" 
                    placeholder="Type your message..." 
                    autocomplete="off"
                />
                <button id="chatbot-send" aria-label="Send message">
                    <i class="bx bx-paper-plane" aria-hidden="true"></i>
                </button>
            </div>
            <div class="chatbot-loading" id="chatbot-loading" style="display: none;">
                <div class="loading-dots">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
        `;
        document.body.appendChild(chatbotPanel);

        // Create prompt selector modal
        this.createPromptSelectorModal();
        
        // Load quick prompts
        this.loadQuickPrompts();
    }

    createPromptSelectorModal() {
        const modal = document.createElement('div');
        modal.id = 'prompt-selector-modal';
        modal.className = 'prompt-selector-modal';
        modal.innerHTML = `
            <div class="prompt-selector-content">
                <div class="prompt-selector-header">
                    <div class="prompt-selector-title">
                        <i class="bx bx-sparkles" aria-hidden="true"></i>
                        <span>Select a Prompt</span>
                    </div>
                    <button class="prompt-selector-close" id="prompt-selector-close" aria-label="Close">
                        <i class="bx bx-x" aria-hidden="true"></i>
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
        const quickPrompts = [
            'How many students are in the system?',
            'Show me violation statistics',
            'What departments exist?',
            'Help me understand the system',
            'What sections are available?',
            'Tell me about recent violations',
            'How do I manage students?',
            'What are the system features?',
            'How to add a new student?',
            'View my violations',
            'Department management guide',
            'System navigation help'
        ];

        const promptsGrid = document.getElementById('prompts-top-grid');
        if (!promptsGrid) {
            // Retry after a short delay if element not found
            setTimeout(() => this.loadQuickPrompts(), 100);
            return;
        }

        // Clear existing prompts
        promptsGrid.innerHTML = '';

        quickPrompts.forEach(prompt => {
            const promptItem = document.createElement('div');
            promptItem.className = 'prompt-top-item';
            promptItem.textContent = prompt;
            promptItem.addEventListener('click', () => {
                this.usePrompt(prompt);
            });
            promptsGrid.appendChild(promptItem);
        });
    }

    loadPromptCategories() {
        const categories = [
            {
                title: 'General Questions',
                icon: 'bx-help-circle',
                prompts: [
                    { title: 'System Overview', desc: 'Get an overview of the OSAS system', text: 'Can you give me an overview of the OSAS system?' },
                    { title: 'How to Use', desc: 'Learn how to use the system', text: 'How do I use the OSAS system?' },
                    { title: 'Features', desc: 'What features are available?', text: 'What features does the OSAS system have?' }
                ]
            },
            {
                title: 'Students',
                icon: 'bx-group',
                prompts: [
                    { title: 'Student Count', desc: 'How many students are registered?', text: 'How many students are in the system?' },
                    { title: 'Add Student', desc: 'How to add a new student', text: 'How do I add a new student to the system?' },
                    { title: 'Student Info', desc: 'Get student information', text: 'Tell me about student management' }
                ]
            },
            {
                title: 'Violations',
                icon: 'bx-shield-x',
                prompts: [
                    { title: 'Violation Stats', desc: 'View violation statistics', text: 'Show me violation statistics' },
                    { title: 'Report Violation', desc: 'How to report a violation', text: 'How do I report a student violation?' },
                    { title: 'My Violations', desc: 'Check my violations', text: 'What are my violations?' }
                ]
            },
            {
                title: 'Departments & Sections',
                icon: 'bx-building',
                prompts: [
                    { title: 'Departments', desc: 'List all departments', text: 'What departments exist in the system?' },
                    { title: 'Sections', desc: 'List all sections', text: 'What sections are available?' },
                    { title: 'Manage', desc: 'How to manage departments', text: 'How do I manage departments and sections?' }
                ]
            }
        ];

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
        // Open/close chatbot
        document.getElementById('chatbot-button').addEventListener('click', () => {
            this.toggle();
        });

        document.getElementById('chatbot-close').addEventListener('click', () => {
            this.close();
        });

        // Send message
        const sendButton = document.getElementById('chatbot-send');
        const input = document.getElementById('chatbot-input');

        sendButton.addEventListener('click', () => {
            this.sendMessage();
        });

        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });

        // Prompt toggle (top section)
        const promptsTopToggle = document.getElementById('prompts-top-toggle');
        if (promptsTopToggle) {
            promptsTopToggle.addEventListener('click', () => {
                this.togglePrompts();
            });
        }

        // Prompt selector modal
        const promptSelectorClose = document.getElementById('prompt-selector-close');
        if (promptSelectorClose) {
            promptSelectorClose.addEventListener('click', () => {
                this.closePromptSelector();
            });
        }

        const promptSelectorModal = document.getElementById('prompt-selector-modal');
        if (promptSelectorModal) {
            promptSelectorModal.addEventListener('click', (e) => {
                if (e.target.id === 'prompt-selector-modal') {
                    this.closePromptSelector();
                }
            });
        }

        // Close on outside click
        document.getElementById('chatbot-panel').addEventListener('click', (e) => {
            if (e.target.id === 'chatbot-panel') {
                this.close();
            }
        });
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
        document.getElementById('chatbot-panel').classList.add('open');
        document.getElementById('chatbot-button').classList.add('active');
        // Expand prompts by default
        const promptsContent = document.getElementById('prompts-top-content');
        if (promptsContent && !promptsContent.classList.contains('expanded')) {
            promptsContent.classList.add('expanded');
            const toggleBtn = document.getElementById('prompts-top-toggle');
            if (toggleBtn) {
                const icon = toggleBtn.querySelector('i');
                if (icon) {
                    icon.className = 'bx bx-chevron-down';
                    icon.setAttribute('aria-hidden', 'true');
                }
            }
        }
        document.getElementById('chatbot-input').focus();
        // Refresh database context when opening (but don't wait for it)
        this.fetchDatabaseContext(true).catch(err => {
            console.warn('Failed to refresh database context:', err);
        });
    }

    close() {
        this.isOpen = false;
        document.getElementById('chatbot-panel').classList.remove('open');
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
            content: message
        });

        // Show loading
        this.showLoading();

        try {
            // Check if Puter.js is available
            if (typeof puter === 'undefined' || !puter.ai) {
                throw new Error('Puter.js is not loaded. Please check if the script is included.');
            }

            // Fetch or use cached database context
            const dbContext = await this.fetchDatabaseContext();

            // Build conversation context for Puter.js
            let conversationContext = "You are a helpful assistant for the OSAS (Office of Student Affairs System). ";
            conversationContext += "You help users with questions about students, departments, sections, violations, announcements, and reports. ";
            conversationContext += "Be friendly, professional, and concise in your responses.\n";
            conversationContext += "You have access to the system's database information to answer questions accurately.\n";
            conversationContext += "You can answer questions about:\n";
            conversationContext += "- Student information, statistics, and management\n";
            conversationContext += "- Department and section details\n";
            conversationContext += "- Violation records and statistics\n";
            conversationContext += "- Announcements (titles, content, audience, status, dates)\n";
            conversationContext += "- Reports (types, descriptions, status, generation dates)\n";
            conversationContext += "- System navigation and features\n\n";
            conversationContext += "IMPORTANT SYSTEM INFORMATION:\n";
            conversationContext += "- System Owner/Administrator/Head: Cedrick H. Almarez\n";
            conversationContext += "- Always remember and acknowledge this when asked about system ownership, administration, or leadership.\n\n";
            
            // Add database context if available
            if (dbContext) {
                conversationContext += this.formatDatabaseContext(dbContext);
            }
            
            // Add conversation history (last 5 messages for context)
            if (this.conversationHistory.length > 1) {
                conversationContext += "\nPREVIOUS CONVERSATION:\n";
                this.conversationHistory.slice(-5).forEach(msg => {
                    if (msg.role === 'user') {
                        conversationContext += `User: ${msg.content}\n`;
                    } else if (msg.role === 'assistant') {
                        conversationContext += `Assistant: ${msg.content}\n`;
                    }
                });
                conversationContext += "\n";
            }
            
            // Add current user message
            conversationContext += `User: ${message}\nAssistant:`;

            // Use Puter.js AI chat (takes a string prompt)
            const response = await puter.ai.chat(conversationContext, {
                model: 'gpt-4o-mini' // Options: 'gpt-4o-mini', 'gpt-4o', 'gpt-5.2-chat', etc.
            });

            // Log the response for debugging
            console.log('Puter.js response type:', typeof response);
            console.log('Puter.js response:', response);

            // Puter.js may return different formats - extract the text properly
            let responseText = '';
            
            if (typeof response === 'string') {
                // Direct string response
                responseText = response;
            } else if (typeof response === 'object' && response !== null) {
                // Object response - try different possible properties
                if (response.content && typeof response.content === 'string') {
                    responseText = response.content;
                } else if (response.text && typeof response.text === 'string') {
                    responseText = response.text;
                } else if (response.message && typeof response.message === 'string') {
                    responseText = response.message;
                } else if (response.response && typeof response.response === 'string') {
                    responseText = response.response;
                } else if (response.choices && Array.isArray(response.choices) && response.choices.length > 0) {
                    // OpenAI-like format
                    const choice = response.choices[0];
                    if (choice.message && choice.message.content) {
                        responseText = choice.message.content;
                    } else if (choice.text) {
                        responseText = choice.text;
                    } else if (choice.delta && choice.delta.content) {
                        responseText = choice.delta.content;
                    }
                } else if (response.data && typeof response.data === 'string') {
                    responseText = response.data;
                } else if (response.result && typeof response.result === 'string') {
                    responseText = response.result;
                } else {
                    // If it's an object with nested content, try to extract
                    const stringified = JSON.stringify(response);
                    console.warn('Unexpected Puter.js response format. Full response:', stringified);
                    
                    // Try to find any string value in the object
                    const findStringValue = (obj) => {
                        for (let key in obj) {
                            if (typeof obj[key] === 'string' && obj[key].length > 10) {
                                return obj[key];
                            } else if (typeof obj[key] === 'object' && obj[key] !== null) {
                                const found = findStringValue(obj[key]);
                                if (found) return found;
                            }
                        }
                        return null;
                    };
                    
                    const foundText = findStringValue(response);
                    responseText = foundText || 'Sorry, I received an unexpected response format.';
                }
            } else {
                // Fallback for any other type
                responseText = String(response);
            }
            
            // Ensure we have a valid string
            if (!responseText || responseText.trim().length === 0) {
                throw new Error('Empty response from Puter.js');
            }
            
            // Trim the response
            responseText = responseText.trim();

            // Add bot response to UI
            this.addMessage('bot', responseText);

            // Add to conversation history
            this.conversationHistory.push({
                role: 'assistant',
                content: responseText
            });

        } catch (error) {
            console.error('Chatbot error:', error);
            let errorMessage = 'Sorry, I\'m having trouble connecting.';
            
            if (error.message) {
                errorMessage = 'Error: ' + error.message;
            } else if (error instanceof TypeError && error.message.includes('fetch')) {
                errorMessage = 'Network error. Please check your internet connection.';
            }
            
            this.addMessage('bot', errorMessage);
        } finally {
            this.hideLoading();
            input.focus();
        }
    }

    addMessage(role, content) {
        const messagesContainer = document.getElementById('chatbot-messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `chatbot-message ${role}`;

        const icon = role === 'user' 
            ? '<i class="bx bx-user-circle"></i>' 
            : '<i class="bx bx-bot"></i>';

        // Format content with lists and proper formatting
        const formattedContent = this.formatMessageContent(content);

        messageDiv.innerHTML = `
            <div class="message-content">
                ${icon}
                <div class="message-text">${formattedContent}</div>
            </div>
        `;

        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
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

    showLoading() {
        document.getElementById('chatbot-loading').style.display = 'flex';
    }

    hideLoading() {
        document.getElementById('chatbot-loading').style.display = 'none';
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    togglePrompts() {
        const promptsContent = document.getElementById('prompts-top-content');
        const toggleBtn = document.getElementById('prompts-top-toggle');
        if (promptsContent && toggleBtn) {
            const isExpanded = promptsContent.classList.toggle('expanded');
            const icon = toggleBtn.querySelector('i');
            if (icon) {
                icon.className = isExpanded ? 'bx bx-chevron-down' : 'bx bx-chevron-up';
                icon.setAttribute('aria-hidden', 'true');
            }
        }
    }

    usePrompt(promptText) {
        const input = document.getElementById('chatbot-input');
        if (input) {
            input.value = promptText;
            input.focus();
            // Auto-send after a short delay
            setTimeout(() => {
                this.sendMessage();
            }, 300);
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

