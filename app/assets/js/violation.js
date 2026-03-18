// violations.js - COMPLETE WORKING VERSION
function initViolationsModule() {
    // Prevent double initialization to avoid duplicate event listeners and race conditions
    // This fixes the "Violation details not found" error caused by duplicate table click handlers
    const initCheck = document.getElementById('ViolationsTableBody');
    if (initCheck) {
        if (initCheck.dataset.moduleInitialized === 'true') {
            console.log('⚠️ Violations module already initialized on this table. Skipping to prevent duplicate listeners.');
            return;
        }
        initCheck.dataset.moduleInitialized = 'true';
    }

    console.log('🛠 Violations module initializing...');
    
    try {
        // ========== DYNAMIC API PATH DETECTION ==========
        // Detect the correct API path based on current page location
        function getAPIBasePath() {
            const currentPath = window.location.pathname;
            console.log('📍 Current path:', currentPath);
            
            // Try to extract the base project path from the URL
            // e.g., /OSAS_WEBSYS/app/views/loader.php -> /OSAS_WEBSYS/
            const pathMatch = currentPath.match(/^(\/[^\/]+)\//);
            const projectBase = pathMatch ? pathMatch[1] : '';
            console.log('📁 Project base:', projectBase);
            
            // Use absolute path from project root for reliability
            if (projectBase) {
                // We have a project folder (e.g., /OSAS_WEBSYS)
                return projectBase + '/api/';
            }
            
            // Fallback to relative paths
            // Check if we're in app/views/ directory
            if (currentPath.includes('/app/views/')) {
                return '../../api/';
            }
            // Check if we're in includes/ directory
            else if (currentPath.includes('/includes/')) {
                return '../api/';
            }
            // Default: we're in the root or another location
            else {
                return 'api/';
            }
        }
        
        const API_BASE = getAPIBasePath();
        console.log('🔗 API Base Path:', API_BASE);
        console.log('🌐 Full API URL will be:', window.location.origin + API_BASE + 'violations.php');

        // Helper function to convert relative image paths to absolute URLs
        function getImageUrl(imagePath, fallbackName = 'Student') {
            if (!imagePath || imagePath.trim() === '') {
                // Return a default avatar with the name
                return `https://ui-avatars.com/api/?name=${encodeURIComponent(fallbackName)}&background=ffd700&color=333&size=80`;
            }
            
            // If it's already a full URL (http/https or data:), return as-is
            if (imagePath.startsWith('http://') || imagePath.startsWith('https://') || imagePath.startsWith('data:')) {
                return imagePath;
            }
            
            // Extract project base from API_BASE (e.g., /OSAS_WEBSYS/)
            const projectBase = API_BASE.replace('/api/', '/');

            // IDEMPOTENCY CHECK: If it already starts with projectBase, return it to avoid double prefixing
            if (imagePath.startsWith(projectBase)) {
                return imagePath;
            }
            
            // If the path starts with assets/, prepend the project base
            if (imagePath.startsWith('assets/') || imagePath.startsWith('app/assets/')) {
                // Normalize to app/assets/
                const normalizedPath = imagePath.startsWith('app/assets/') ? imagePath : imagePath.replace('assets/', 'app/assets/');
                return projectBase + normalizedPath;
            }
            
            // If the path starts with ../, it's a relative path from app/views/
            if (imagePath.startsWith('../')) {
                // Remove ../ and use project base with app/assets/
                return projectBase + 'app/' + imagePath.replace(/^\.\.\//, '');
            }
            
            // If it's just a filename, assume it's in app/assets/img/students/
            if (!imagePath.includes('/')) {
                return projectBase + 'app/assets/img/students/' + imagePath;
            }
            
            // Default: prepend project base
            return projectBase + imagePath;
        }

        // Elements
        const tableBody = document.getElementById('ViolationsTableBody');
        const btnAddViolation = document.getElementById('btnAddViolations');
        const btnRecordFirst = document.getElementById('btnRecordFirstViolation');
        const recordModal = document.getElementById('ViolationRecordModal');
        const detailsModal = document.getElementById('ViolationDetailsModal');
        const closeRecordBtn = document.getElementById('closeRecordModal');
        const closeDetailsBtn = document.getElementById('closeDetailsModal');
        const cancelRecordBtn = document.getElementById('cancelRecordModal');
        const recordOverlay = document.getElementById('ViolationModalOverlay');
        const detailsOverlay = document.getElementById('DetailsModalOverlay');
        const searchInput = document.getElementById('searchViolation');
        const deptFilter = document.getElementById('ViolationsFilter');
        const statusFilter = document.getElementById('ViolationsStatusFilter');
        const dateFromFilter = document.getElementById('ViolationDateFrom');
        const dateToFilter = document.getElementById('ViolationDateTo');
        const exportBtn = document.getElementById('btnExportViolations');
        const exportModal = document.getElementById('ExportViolationsModal');
        const closeExportBtn = document.getElementById('closeExportModal');
        const exportModalOverlay = document.getElementById('ExportModalOverlay');
        const exportPDFBtn = document.getElementById('exportPDF');
        const exportExcelBtn = document.getElementById('exportExcel');
        const exportWordBtn = document.getElementById('exportWord');
        const studentSearchInput = document.getElementById('studentSearch');
        const searchStudentBtn = document.getElementById('searchStudentBtn');
        const selectedStudentCard = document.getElementById('selectedStudentCard');
        const violationForm = document.getElementById('ViolationRecordForm');

        // Debug logging
        console.log('🔍 Modal found:', recordModal);
        console.log('🔍 Button found:', btnAddViolation);

        if (!btnAddViolation) {
            console.error('❌ #btnAddViolations NOT FOUND!');
            return;
        }

        if (!recordModal) {
            console.error('❌ #ViolationRecordModal NOT FOUND!');
            return;
        }

        const modalEntranceBtn = document.getElementById('modalEntranceBtn');

        // ========== DATA & CONFIG ==========
        
        // Dynamic data
        let violations = [];
        let filteredViolations = []; // To store currently filtered items for printing/stats
        let currentView = 'current'; // 'current' or 'archive'
        let students = [];
        let violationTypes = [];
        let isLoading = false;
        let isSubmitting = false; // Form submission lock
        let currentPage = 1;
        let itemsPerPage = 10;
        let totalRecords = 0;
        let totalPages = 0;
        let selectedFiles = []; // To store selected attachment files

        function getCurrentAdminName() {
            const sessionStr = localStorage.getItem('userSession');
            if (!sessionStr) return 'Admin';
            try {
                const session = JSON.parse(sessionStr);
                return session.full_name || session.name || session.username || 'Admin';
            } catch (e) {
                return 'Admin';
            }
        }

        // Student data will be loaded dynamically

        // ========== DATA LOADING FUNCTIONS ==========

        /**
         * Load departments from the database and populate the filter dropdowns
         */
        async function loadDepartments() {
            try {
                console.log('🔄 Loading departments for filters...');
                const response = await fetch(API_BASE + 'departments.php');
                if (!response.ok) throw new Error('Failed to load departments');
                
                const data = await response.json();
                if (data.status === 'success' && Array.isArray(data.data)) {
                    const depts = data.data;
                    console.log('✅ Loaded departments:', depts.length);
                    
                    const filters = [
                        document.getElementById('ViolationsFilter'),
                        document.getElementById('ArchiveDeptFilter')
                    ];

                    filters.forEach(select => {
                        if (!select) return;

                        const currentVal = select.value;
                        // Keep only the "All Departments" option
                        select.innerHTML = '<option value="all">All Departments</option>';

                        // Add departments from database
                        depts.forEach(dept => {
                            const option = document.createElement('option');
                            option.value = dept.code || dept.department_code;
                            option.textContent = dept.name || dept.department_name || dept.code || dept.department_code;
                            select.appendChild(option);
                        });
                        
                        // Restore previous value if possible
                        if (currentVal) select.value = currentVal;
                    });
                }
            } catch (error) {
                console.error('❌ Error loading departments:', error);
            }
        }

        // Check API connectivity - using GET instead of HEAD for better compatibility
        async function checkAPIConnectivity() {
            try {
                console.log('🔍 Checking API connectivity...');
                console.log('🔗 Using API path:', API_BASE);

                let violationsOk = false;
                let studentsOk = false;

                // Test violations API with actual GET request
                try {
                    const violationsResponse = await fetch(API_BASE + 'violations.php');
                    console.log('Violations API status:', violationsResponse.status);
                    // Consider it OK if we get any response (even error JSON is fine - means API is accessible)
                    violationsOk = violationsResponse.status !== 404;
                    if (violationsOk) {
                        const text = await violationsResponse.text();
                        console.log('Violations API response preview:', text.substring(0, 100));
                        // Check if it's valid JSON (not an HTML error page)
                        try {
                            JSON.parse(text);
                            violationsOk = true;
                        } catch (e) {
                            console.warn('Violations API returned non-JSON:', text.substring(0, 200));
                            violationsOk = false;
                        }
                    }
                } catch (e) {
                    console.error('Violations API check error:', e);
                }

                // Test students API with actual GET request
                try {
                    const studentsResponse = await fetch(API_BASE + 'students.php');
                    console.log('Students API status:', studentsResponse.status);
                    studentsOk = studentsResponse.status !== 404;
                    if (studentsOk) {
                        const text = await studentsResponse.text();
                        console.log('Students API response preview:', text.substring(0, 100));
                        try {
                            JSON.parse(text);
                            studentsOk = true;
                        } catch (e) {
                            console.warn('Students API returned non-JSON:', text.substring(0, 200));
                            studentsOk = false;
                        }
                    }
                } catch (e) {
                    console.error('Students API check error:', e);
                }

                return {
                    violations: violationsOk,
                    students: studentsOk
                };
            } catch (error) {
                console.error('API connectivity check failed:', error);
                return { violations: false, students: false };
            }
        }

        // Show/Hide global loading overlay
        function showLoadingOverlay(message = 'Loading...') {
            let overlay = document.getElementById('ViolationsLoadingOverlay');
            if (!overlay) {
                overlay = document.createElement('div');
                overlay.id = 'ViolationsLoadingOverlay';
                overlay.className = 'violations-loading-overlay';
                overlay.innerHTML = `
                    <div class="violations-loading-content">
                        <i class='bx bx-loader-alt bx-spin'></i>
                        <div class="violations-loading-text">${message}</div>
                    </div>
                `;
                document.body.appendChild(overlay);
            }
            overlay.style.display = 'flex';
            overlay.querySelector('.violations-loading-text').textContent = message;
        }

        function hideLoadingOverlay() {
            const overlay = document.getElementById('ViolationsLoadingOverlay');
            if (overlay) {
                overlay.style.display = 'none';
            }
        }
        async function loadViolations(showLoading = false) {
            try {
                if (showLoading) showLoadingOverlay('Loading violations...');
                console.log('🔄 Fetching violations data...', { currentView });
        
                // Add timestamp to prevent caching and include is_archived parameter
                const isArchived = currentView === 'archive' ? 1 : 0;

                // CHECK OFFLINE STATUS
                if (!navigator.onLine && window.offlineDB) {
                    console.log('📡 OFFLINE: Loading violations from IndexedDB...');
                    const cachedViolations = await window.offlineDB.getViolations();
                    if (cachedViolations && cachedViolations.length > 0) {
                        violations = cachedViolations;
                        console.log(`✅ Loaded ${violations.length} violations from cache`);
                        return violations;
                    }
                }

                const response = await fetch(API_BASE + `violations.php?is_archived=${isArchived}&t=` + new Date().getTime());
                if (!response.ok) {
                    const errorText = await response.text().catch(() => 'Unknown error');
                    console.error('HTTP Error Response:', errorText);
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
        
                const responseText = await response.text();
                console.log('Raw API Response Text:', responseText.substring(0, 500));
                
                let data;
                try {
                    data = JSON.parse(responseText);
                } catch (parseError) {
                    console.error('❌ Failed to parse JSON:', parseError);
                    console.error('Response was:', responseText);
                    throw new Error('Invalid JSON response from API. Response: ' + responseText.substring(0, 200));
                }
                
                console.log('Parsed API Response:', data);
                console.log('Response keys:', Object.keys(data));
                console.log('Has violations key:', 'violations' in data);
                console.log('Has data key:', 'data' in data);
                console.log('Violations value:', data.violations);
                console.log('Data value:', data.data);
                
                if (data.status === 'error') {
                    throw new Error(data.message || 'API returned error status');
                }
                
                // FIXED: Make sure we're accessing the correct property
                violations = data.violations || data.data || [];
                
                // Cache for offline use
                if (window.offlineDB && violations.length > 0) {
                    window.offlineDB.saveViolations(violations).catch(err => console.error('Cache failed:', err));
                }
                
                console.log(`✅ Loaded ${violations.length} violations`);
                console.log('Violations array:', violations);
                
                if (violations.length === 0) {
                    console.warn('⚠️ API returned success but no violations in array');
                    console.warn('Response structure:', Object.keys(data));
                    console.warn('Full response:', JSON.stringify(data, null, 2));
                    
                    // Check if it's actually an empty array or undefined
                    if (data.violations === undefined && data.data === undefined) {
                        console.error('❌ CRITICAL: Both violations and data keys are undefined!');
                        console.error('This means the API response format is wrong.');
                    }
                }
        
                // Process violations to fix image paths
                violations = violations.map(v => {
                    return {
                        ...v,
                        studentImage: getImageUrl(v.studentImage, v.studentName || 'Student')
                    };
                });

                // Debug: Check first violation structure
                if (violations.length > 0) {
                    console.log('First violation sample:', violations[0]);
                    console.log('Violation properties:', Object.keys(violations[0]));
                    console.log('Student image URL:', violations[0].studentImage);
                }
        
                return violations;
            } catch (error) {
                console.error('❌ Error loading violations:', error);
                console.error('Error details:', error.stack);
        
                // Check if it's a network error
                if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                    showNotification('Violations API not available. Please check if the violations.php file exists in the api directory.', 'warning', 8000);
                } else {
                    showNotification('Failed to load violations: ' + error.message, 'error');
                }
        
                violations = [];
                return [];
            } finally {
                if (showLoading) hideLoadingOverlay();
            }
        }
        async function loadStudents(showLoading = false) {
            try {
                if (showLoading) showLoadingOverlay('Loading students...');
                console.log('🔄 Loading students data...');

                // Add timestamp to prevent caching
                const response = await fetch(API_BASE + 'students.php?action=get&filter=active&page=1&limit=1000&t=' + new Date().getTime());
                if (!response.ok) {
                    const errorText = await response.text().catch(() => 'Unknown error');
                    console.error('Students API Error Response:', errorText);
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const data = await response.json();
                console.log('Students API Response:', data);

                if (data.status === 'error') {
                    throw new Error(data.message || 'API returned error');
                }

                // Handle different response formats (supports paginated and legacy)
                let list = [];
                if (Array.isArray(data)) {
                    list = data;
                } else if (Array.isArray(data.students)) {
                    list = data.students;
                } else if (data && data.data) {
                    const payload = data.data;
                    if (Array.isArray(payload)) {
                        list = payload;
                    } else if (payload && Array.isArray(payload.students)) {
                        list = payload.students;
                    }
                }

                students = Array.isArray(list) ? list : [];
                console.log(`✅ Loaded ${students.length} students`);

                // Process student data to fix image paths
                students = students.map(student => {
                    const fullName = `${student.firstName || ''} ${student.lastName || ''}`.trim();
                    return {
                        ...student,
                        avatar: getImageUrl(student.avatar, fullName)
                    };
                });

                // Validate student data structure
                if (students.length > 0) {
                    const firstStudent = students[0];
                    console.log('Student data structure:', {
                        hasId: 'studentId' in firstStudent,
                        hasName: 'firstName' in firstStudent && 'lastName' in firstStudent,
                        sampleId: firstStudent.studentId,
                        sampleName: `${firstStudent.firstName} ${firstStudent.lastName}`,
                        avatar: firstStudent.avatar
                    });
                }

                return students;
            } catch (error) {
                console.error('❌ Error loading students:', error);
                console.error('Error details:', error.stack);

                // Check if it's a network error
                if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                    showNotification('Students API not available. Student search may not work properly.', 'warning', 8000);
                } else {
                    showNotification('Failed to load students data: ' + error.message, 'error');
                }

                // Fallback to empty array
                students = [];
                return [];
            } finally {
                if (showLoading) hideLoadingOverlay();
            }
        }

        // Refresh data function
        async function refreshData() {
            try {
                showLoadingOverlay('Refreshing data...');

                // Load data in parallel
                await Promise.all([
                    loadViolations(false),
                    loadStudents(false),
                    loadViolationTypes()
                ]);

                // Re-render everything
                renderViolations();
                updateStats();

                showNotification('Data refreshed successfully', 'success');
            } catch (error) {
                console.error('❌ Error refreshing data:', error);
                showNotification('Failed to refresh data', 'error');
            } finally {
                hideLoadingOverlay();
            }
        }

        async function loadViolationTypes() {
            try {
                console.log('🔄 Loading violation types...');
                const response = await fetch(API_BASE + 'violations.php?action=types');
                if (!response.ok) throw new Error('Failed to load types');
                
                const data = await response.json();
                if (data.status === 'success') {
                    violationTypes = data.data;
                    console.log('✅ Loaded violation types:', violationTypes);
                    renderViolationTypes();
                }
            } catch (error) {
                console.error('❌ Error loading violation types:', error);
                showNotification('Failed to load violation types', 'error');
            }
        }

        function renderViolationTypes() {
            const container = document.getElementById('violationTypesContainer');
            if (!container) return;
            
            container.innerHTML = '';
            
            violationTypes.forEach(type => {
                const nameLower = type.name.toLowerCase();
                
                // Filter: Only show Uniform, Footwear, and ID
                const isAllowed = nameLower.includes('uniform') || 
                                  nameLower.includes('footwear') || 
                                  nameLower.includes('shoe') || 
                                  nameLower.includes('id');
                
                if (!isAllowed) return;

                const card = document.createElement('div');
                card.className = 'violation-type-card';
                card.dataset.violation = type.id;
                
                // Choose icon based on name (simple logic)
                let icon = 'bx-error-circle';
                if (nameLower.includes('uniform')) icon = 'bx-t-shirt';
                else if (nameLower.includes('footwear')) icon = 'bx-walk';
                else if (nameLower.includes('id')) icon = 'bx-id-card';
                
                card.innerHTML = `
                    <input type="radio" id="type_${type.id}" name="violationType" value="${type.id}">
                    <label for="type_${type.id}">
                        <i class='bx ${icon}'></i>
                        <span>${type.name}</span>
                    </label>
                `;
                
                container.appendChild(card);
            });

            // Add "Add" button as requested
            const addCard = document.createElement('div');
            addCard.className = 'violation-type-card';
            addCard.style.border = '2px dashed #ccc';
            addCard.innerHTML = `
                <button type="button" class="add-violation-type-btn" style="width:100%; height:100%; background:none; border:none; cursor:pointer; display:flex; flex-direction:column; align-items:center; justify-content:center; color: #666;">
                    <i class='bx bx-plus' style="font-size: 24px; margin-bottom: 8px;"></i>
                    <span>Add</span>
                </button>
            `;
            addCard.addEventListener('click', (e) => {
                e.preventDefault();
                // Placeholder for now
                if (typeof showNotification === 'function') {
                    showNotification('Add Violation Type feature coming soon!', 'info');
                } else {
                    alert('Add Violation Type feature coming soon!');
                }
            });
            container.appendChild(addCard);

            // Event delegation for type selection
            container.addEventListener('change', (e) => {
                if (e.target.name === 'violationType') {
                    // Update visual selection state of cards
                    document.querySelectorAll('.violation-type-card').forEach(c => c.classList.remove('active'));
                    e.target.closest('.violation-type-card').classList.add('active');
                    
                    renderViolationLevels(e.target.value);
                }
            });
        }

        function renderViolationLevels(typeId) {
            const container = document.getElementById('violationLevelsContainer');
            if (!container) return;
            
            const type = violationTypes.find(t => t.id == typeId);
            if (!type || !type.levels) {
                container.innerHTML = '<p class="no-levels">No levels defined for this violation type</p>';
                return;
            }
            
            container.innerHTML = '';
            
            type.levels.forEach(level => {
                const div = document.createElement('div');
                
                // Determine style class based on name/level
                let styleClass = 'level-warning';
                const nameLower = level.name.toLowerCase();
                if (nameLower.includes('permitted')) styleClass = 'level-permitted';
                else if (nameLower.includes('disciplinary')) styleClass = 'level-disciplinary';

                div.className = `violation-level-option ${styleClass}`;
                
                div.innerHTML = `
                    <input type="radio" id="level_${level.id}" name="violationLevel" value="${level.id}">
                    <label for="level_${level.id}" class="${styleClass}">
                        <span class="level-title">${level.name}</span>
                        <span class="level-desc">${level.description || ''}</span>
                    </label>
                `;
                
                container.appendChild(div);
            });

            // Event delegation for level selection (use onchange to prevent duplicate listeners)
            container.onchange = (e) => {
                if (e.target.name === 'violationLevel') {
                    // Update visual selection state of options
                    document.querySelectorAll('.violation-level-option').forEach(c => c.classList.remove('active'));
                    const option = e.target.closest('.violation-level-option');
                    if (option) option.classList.add('active');
                }
            };

            // Default to first level (Warning 1)
            const firstRadio = container.querySelector('input[type="radio"]');
            if (firstRadio) {
                firstRadio.checked = true;
                const optionDiv = firstRadio.closest('.violation-level-option');
                if (optionDiv) optionDiv.classList.add('active');
            }

            // Check history if student is already selected
            checkStudentViolationHistory();
        }

        // Check and highlight student's violation history
        function checkStudentViolationHistory() {
            // 1. Get selected student ID
            const studentIdElement = document.getElementById('modalStudentId');
            if (!studentIdElement || !studentIdElement.textContent) return;
            
            // Check if we are in "Add New" mode (not editing)
            const recordModal = document.getElementById('ViolationRecordModal');
            if (recordModal && recordModal.dataset.editingId) return;

            const studentId = studentIdElement.textContent.trim();
            if (!studentId) return;

            // 2. Get selected violation type
            const violationTypeInput = document.querySelector('input[name="violationType"]:checked');
            if (!violationTypeInput) return;
            
            const violationTypeId = parseInt(violationTypeInput.value);

            // 3. Filter violations for this student and type
            // Note: violations array contains history
            const studentHistory = violations.filter(v => 
                v.studentId === studentId && 
                (v.violationType == violationTypeId)
            );
            
            console.log(`Found ${studentHistory.length} previous violations for student ${studentId} of type ${violationTypeId}`);

            // 4. Update UI
            updateLevelSelectionBasedOnHistory(studentHistory);
        }

        function updateViolationTypeBadges(studentId) {
            console.log('Updating violation type badges for student:', studentId);
            
            // 1. Clear existing badges
            document.querySelectorAll('.violation-type-badge-overlay').forEach(el => el.remove());

            // 2. Iterate cards
            document.querySelectorAll('.violation-type-card').forEach(card => {
                const input = card.querySelector('input[name="violationType"]');
                if (!input) return;
                
                const typeId = parseInt(input.value);
                
                // 3. Find history for this student and type
                // Use the global violations array
                const history = violations.filter(v => 
                    v.studentId === studentId && 
                    (v.violationType == typeId)
                );
                
                if (history.length > 0) {
                    // 4. Find the most relevant level
                    // Sort by date descending
                    history.sort((a, b) => {
                        const dateA = new Date((a.dateReported || a.violationDate) + ' ' + (a.violationTime || '00:00'));
                        const dateB = new Date((b.dateReported || b.violationDate) + ' ' + (b.violationTime || '00:00'));
                        return dateB - dateA;
                    });
                    
                    const latest = history[0];
                    const levelName = latest.violationLevelLabel || 'Recorded';
                    
                    // Create Badge
                    const badge = document.createElement('div');
                    
                    // Determine class based on level name
                    let statusClass = 'warning';
                    const nameLower = levelName.toLowerCase();
                    if (nameLower.includes('permitted')) statusClass = 'permitted';
                    else if (nameLower.includes('disciplinary')) statusClass = 'disciplinary';
                    
                    badge.className = `violation-type-badge-overlay ${statusClass}`;
                    badge.textContent = levelName;
                    
                    card.style.position = 'relative'; // Ensure relative positioning
                    card.appendChild(badge);
                }
            });
        }

        function updateLevelSelectionBasedOnHistory(history) {
            // Reset any previous history highlights
            document.querySelectorAll('.violation-history-badge').forEach(el => el.remove());
            
            // Find the levels container
            const levelInputs = document.querySelectorAll('input[name="violationLevel"]');
            
            let maxLevelIndex = -1;
            let lastViolationDate = null;
            let lastViolationLevelName = '';

            levelInputs.forEach((input, index) => {
                const levelId = parseInt(input.value);
                const optionContainer = input.closest('.violation-level-option');

                // Reset state first (enable all)
                input.disabled = false;
                if (optionContainer) {
                    optionContainer.classList.remove('recorded', 'disabled');
                }
                
                // If no history, skip processing this item
                if (!history || history.length === 0) return;

                // Check if this level is in history
                // Sort history by date desc to get latest for this level
                const matchingHistory = history
                    .filter(h => h.violationLevel == levelId)
                    .sort((a, b) => new Date((b.dateReported || b.violationDate) + ' ' + (b.violationTime || '00:00')) - new Date((a.dateReported || a.violationDate) + ' ' + (a.violationTime || '00:00')));
                
                if (matchingHistory.length > 0) {
                    const latest = matchingHistory[0];
                    const latestDate = latest.dateReported || latest.violationDate;
                    
                    // Mark as recorded and disabled
                    input.disabled = true;
                    if (optionContainer) {
                        optionContainer.classList.add('recorded', 'disabled');
                        optionContainer.classList.remove('active'); // Deselect if active
                    }

                    // Add Badge
                    const label = input.nextElementSibling; // The <label> tag
                    if (label) {
                        const badge = document.createElement('span');
                        badge.className = 'violation-history-badge';
                        badge.innerHTML = `<i class='bx bx-history'></i> Recorded (${matchingHistory.length})`;
                        badge.title = `Last recorded: ${latestDate}`;
                        
                        // Append to the title
                        const titleSpan = label.querySelector('.level-title');
                        if (titleSpan) {
                            // Remove existing badges first to be safe
                            const existing = titleSpan.querySelector('.violation-history-badge');
                            if (existing) existing.remove();
                            titleSpan.appendChild(badge);
                        }
                    }
                    
                    // Track the highest level index found
                    if (index > maxLevelIndex) {
                        maxLevelIndex = index;
                        lastViolationDate = latestDate;
                        lastViolationLevelName = label.querySelector('.level-title').childNodes[0].textContent.trim();
                    }
                }
            });

            // STRICT PROGRESSION ENFORCEMENT
            // Disable any level that is more than 1 step ahead of the max recorded level
            // Special Case: If Warning 3 is reached, stop there (disable Disciplinary Action level).
            
            const isWarning3Reached = lastViolationLevelName.toLowerCase().includes('warning 3') || 
                                     lastViolationLevelName.toLowerCase().includes('3rd');

            levelInputs.forEach((input, index) => {
                let limit = maxLevelIndex + 1;
                
                // If Warning 3 is reached, do not allow proceeding to the next level (Disciplinary Action)
                // effectively disabling it.
                if (isWarning3Reached) {
                    limit = maxLevelIndex; 
                }

                if (index > limit) {
                    input.disabled = true;
                    const optionContainer = input.closest('.violation-level-option');
                    if (optionContainer) {
                        optionContainer.classList.add('disabled', 'locked');
                        optionContainer.title = isWarning3Reached 
                            ? 'Maximum violation level reached (Disciplinary Status Active)' 
                            : 'Complete previous levels first';
                    }
                }
            });

            if (!history || history.length === 0) return;

            // Auto-select the next level
            if (maxLevelIndex > -1) {
                // If Warning 3 is reached, don't select the next level
                if (isWarning3Reached) {
                    showNotification(`
                        <strong>Maximum Violation Level Reached</strong><br>
                        Student has reached Warning 3. Status is now Disciplinary.
                    `, 'warning', 6000);
                    return;
                }

                // If the student has violations, select the NEXT level if available
                if (maxLevelIndex < levelInputs.length - 1) {
                    const nextInput = levelInputs[maxLevelIndex + 1];
                    if (nextInput) {
                        // Check and trigger change
                        nextInput.checked = true;
                        nextInput.dispatchEvent(new Event('change', { bubbles: true }));
                        
                        // Also update the UI class for the newly selected item
                        const nextContainer = nextInput.closest('.violation-level-option');
                        if (nextContainer) nextContainer.classList.add('active');
                        
                        const nextLevelName = nextInput.nextElementSibling.querySelector('.level-title').textContent;
                        
                        showNotification(`
                            <strong>Student History Found</strong><br>
                            Previous: ${lastViolationLevelName} (${lastViolationDate})<br>
                            Suggested: ${nextLevelName}
                        `, 'info', 5000);
                    }
                } else {
                    // Max level reached
                    showNotification(`
                        <strong>Maximum Violation Level Reached</strong><br>
                        Student has already reached the highest level for this violation.
                    `, 'warning', 6000);
                }
            }
        }

        // Notification system
        function showNotification(message, type = 'info', duration = 3000) {
            // Remove existing notifications
            const existingNotifications = document.querySelectorAll('.violations-notification');
            existingNotifications.forEach(notification => notification.remove());

            // Create notification element
            const notification = document.createElement('div');
            notification.className = `violations-notification ${type}`;
            notification.innerHTML = `
                <i class='bx bx-${type === 'success' ? 'check' : type === 'error' ? 'x' : type === 'warning' ? 'error' : 'info'}-circle'></i>
                <span>${message}</span>
                <button class="violations-notification-close" onclick="this.parentElement.remove()">
                    <i class='bx bx-x'></i>
                </button>
            `;

            // Add to page
            document.body.appendChild(notification);

            // Auto remove after duration
            if (duration > 0) {
                setTimeout(() => {
                    if (notification.parentElement) {
                        notification.remove();
                    }
                }, duration);
            }

            return notification;
        }

        async function saveViolation(formData) {
            if (isSubmitting) return;
            isSubmitting = true;
            
            try {
                console.log('💾 Saving violation (FormData)...');

                // OFFLINE HANDLING
                if (!navigator.onLine && window.offlineDB) {
                    console.log('📡 OFFLINE: Queueing violation for sync...');
                    
                    // Convert FormData to simple object for storage
                    const data = {};
                    formData.forEach((value, key) => {
                        // Handle file separately if needed, but for now we skip files offline
                        if (!(value instanceof File)) {
                            data[key] = value;
                        }
                    });

                    await window.offlineDB.queueAction('POST_VIOLATION', data);
                    
                    showNotification('You are offline. Violation saved locally and will sync when online.', 'warning', 6000);
                    
                    // Optimistic UI update
                    const tempId = 'TEMP-' + Date.now();
                    const studentId = formData.get('studentId');
                    const student = students.find(s => s.studentId === studentId);
                    
                    const offlineViolation = {
                        id: tempId,
                        caseId: 'OFFLINE-SYNC',
                        studentId: studentId,
                        studentName: student ? `${student.firstName} ${student.lastName}` : 'Unknown',
                        studentImage: student ? student.avatar : '',
                        violationTypeLabel: 'Sync Pending...',
                        violationLevelLabel: '...',
                        dateReported: formData.get('violationDate'),
                        violationTime: formData.get('violationTime'),
                        status: 'pending',
                        statusLabel: 'Pending Sync'
                    };
                    
                    violations.unshift(offlineViolation);
                    renderViolations();
                    
                    // Close modal
                    if (recordModal) {
                        recordModal.style.display = 'none';
                        if (recordOverlay) recordOverlay.style.display = 'none';
                    }
                    
                    return { status: 'offline', data: offlineViolation };
                }

                showLoadingOverlay('Saving violation...');

                const response = await fetch(API_BASE + 'violations.php', {
                    method: 'POST',
                    body: formData // Send as FormData (multipart/form-data)
                });

                // Try to get response text first to see what the server returned
                const responseText = await response.text();
                console.log('Response status:', response.status);
                console.log('Response text:', responseText);

                if (!response.ok) {
                    // Try to parse as JSON to get error message
                    let errorMessage = `HTTP error! status: ${response.status}`;
                    try {
                        const errorData = JSON.parse(responseText);
                        if (errorData.message) {
                            errorMessage = errorData.message;
                        } else if (errorData.error) {
                            errorMessage = errorData.error;
                        }
                    } catch (e) {
                        // If not JSON, use the raw text (might be HTML error page)
                        if (responseText && responseText.length < 500) {
                            errorMessage = responseText;
                        }
                    }
                    throw new Error(errorMessage);
                }

                // Parse JSON response
                let result;
                try {
                    result = JSON.parse(responseText);
                } catch (e) {
                    throw new Error('Invalid JSON response from server: ' + responseText.substring(0, 200));
                }

                if (result.status === 'error') {
                    throw new Error(result.message || 'Unknown error occurred');
                }

                console.log('✅ Violation saved successfully');

                // Reload violations data in background (Manual Fallback handles immediate UI)
                loadViolations(false).catch(console.error);
                
                // Check if the new violation is in the global list (Manual Fallback Strategy)
                // API returns data in result.data
                const resultId = result.data ? result.data.id : result.id;
                const resultCaseId = result.data ? result.data.case_id : result.case_id;
                
                let savedViolation = violations.find(v => v.id == resultId || v.caseId == resultCaseId);
                
                if (!savedViolation) {
                    console.warn('⚠️ New violation not found in reloaded data. Injecting manual fallback...');
                    
                    // Extract values from FormData for manual injection
                    const studentId = formData.get('studentId');
                    const vType = formData.get('violationType');
                    const vLevel = formData.get('violationLevel');
                    const vDate = formData.get('violationDate');
                    const vTime = formData.get('violationTime');
                    const vLocation = formData.get('location');
                    const vReportedBy = formData.get('reportedBy');
                    const vStatus = formData.get('status');
                    const vNotes = formData.get('notes');
                    const vDept = formData.get('department');

                    // 1. Find Student
                    const student = students.find(s => s.studentId === studentId);
                    
                    // 2. Find Type Label
                    let typeLabel = 'Violation';
                    const typeObj = violationTypes.find(t => t.id == vType);
                    if (typeObj) typeLabel = typeObj.name;
                    
                    // 3. Find Level Label
                    let levelLabel = 'Level';
                    if (typeObj && typeObj.levels) {
                         const levelObj = typeObj.levels.find(l => l.id == vLevel);
                         if (levelObj) levelLabel = levelObj.name;
                    }
                    
                    // 4. Construct Object
                    savedViolation = {
                        id: resultId,
                        caseId: resultCaseId || 'PENDING',
                        studentId: studentId,
                        studentName: student ? `${student.firstName} ${student.lastName}` : 'Unknown',
                        studentImage: student ? student.avatar : '',
                        violationType: vType,
                        violationTypeLabel: typeLabel,
                        violationLevel: vLevel,
                        violationLevelLabel: levelLabel,
                        department: vDept || (student ? student.department : 'N/A'),
                        section: student ? student.section : 'N/A',
                        studentYearlevel: student ? student.yearlevel : 'N/A',
                        dateReported: vDate,
                        violationTime: vTime,
                        dateTime: `${formatDate(vDate)} ${formatTime(vTime)}`,
                        location: vLocation,
                        locationLabel: vLocation,
                        reportedBy: vReportedBy,
                        status: vStatus,
                        statusLabel: vStatus.charAt(0).toUpperCase() + vStatus.slice(1),
                        notes: vNotes,
                        attachments: result.data?.attachments || [] // Use attachments from server response if available
                    };
                    
                    // 5. Inject at the beginning (assuming desc sort)
                    violations.unshift(savedViolation);
                    console.log('✅ Manually injected violation:', savedViolation);
                } else {
                    console.log('✅ Saved violation found in reloaded data');
                }

                renderViolations();
                
                // Explicitly update badges for the student if applicable
                const sId = formData.get('studentId');
                if (sId) {
                    console.log('🔄 Force updating badges for student:', sId);
                    updateViolationTypeBadges(sId);
                }

                showNotification('Violation recorded successfully!', 'success');
                return result;
            } catch (error) {
                console.error('❌ Error saving violation:', error);
                showNotification('Failed to save violation: ' + error.message, 'error');
                throw error;
            } finally {
                isSubmitting = false;
                hideLoadingOverlay();
            }
        }

        async function updateViolation(violationId, violationData) {
            if (isSubmitting) return;
            isSubmitting = true;

            try {
                console.log('📝 Updating violation...', violationId, violationData);

                showLoadingOverlay('Updating violation...');

                const response = await fetch(API_BASE + `violations.php?id=${violationId}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(violationData)
                });

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const result = await response.json();
                if (result.status === 'error') {
                    throw new Error(result.message);
                }

                console.log('✅ Violation updated successfully');

                // Get student ID for badge update (before reload, or find in existing)
                let studentId = violationData.studentId;
                if (!studentId) {
                     const existing = violations.find(v => v.id == violationId);
                     if (existing) studentId = existing.studentId;
                }

                // Reload violations data in background
                loadViolations(false).catch(console.error);
                
                // Manual Fallback: Ensure the updated violation reflects changes immediately
                const updated = violations.find(v => v.id == violationId);
                if (updated) {
                    console.log('🔄 Applying optimistic updates to violation:', violationId);
                    
                    // Update simple fields
                    Object.assign(updated, violationData);
                    
                    // Update complex fields (labels) if necessary
                    if (violationData.violationType) {
                        const typeObj = violationTypes.find(t => t.id == violationData.violationType);
                        if (typeObj) updated.violationTypeLabel = typeObj.name;
                    }
                    
                    if (violationData.violationLevel) {
                         const typeId = violationData.violationType || updated.violationType;
                         const typeObj = violationTypes.find(t => t.id == typeId);
                         if (typeObj && typeObj.levels) {
                             const levelObj = typeObj.levels.find(l => l.id == violationData.violationLevel);
                             if (levelObj) updated.violationLevelLabel = levelObj.name;
                         }
                    }
                    
                    if (violationData.status) {
                        updated.statusLabel = violationData.status.charAt(0).toUpperCase() + violationData.status.slice(1);
                    }
                }
                
                renderViolations();

                if (studentId) {
                    console.log('🔄 Force updating badges for student:', studentId);
                    updateViolationTypeBadges(studentId);
                }

                showNotification('Violation updated successfully!', 'success');
                return result;
            } catch (error) {
                console.error('❌ Error updating violation:', error);
                showNotification('Failed to update violation: ' + error.message, 'error');
                throw error;
            } finally {
                isSubmitting = false;
                hideLoadingOverlay();
            }
        }

        async function deleteViolation(violationId) {
            if (isSubmitting) return;
            isSubmitting = true;

            try {
                console.log('🗑️ Deleting violation...', violationId);

                showLoadingOverlay('Deleting violation...');

                const response = await fetch(API_BASE + `violations.php?id=${violationId}`, {
                    method: 'DELETE'
                });

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const result = await response.json();
                if (result.status === 'error') {
                    throw new Error(result.message);
                }

                // Get student ID before deletion/reload
                let studentId = null;
                const existing = violations.find(v => v.id == violationId);
                if (existing) studentId = existing.studentId;

                console.log('✅ Violation deleted successfully');

                // Reload violations data with delay
                await new Promise(resolve => setTimeout(resolve, 200));
                await loadViolations(false);
                renderViolations();

                if (studentId) {
                     console.log('🔄 Force updating badges for student:', studentId);
                     updateViolationTypeBadges(studentId);
                }

                showNotification('Violation deleted successfully!', 'success');
                return true;
            } catch (error) {
                console.error('❌ Error deleting violation:', error);
                showNotification('Failed to delete violation: ' + error.message, 'error');
                throw error;
            } finally {
                isSubmitting = false;
                hideLoadingOverlay();
            }
        }

        // ========== HELPER FUNCTIONS ==========
        
        function formatDate(dateStr) {
            const date = new Date(dateStr);
            return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        }

        function formatTime(timeStr) {
            if (!timeStr) return '';
            const [hours, minutes] = timeStr.split(':');
            const date = new Date();
            date.setHours(hours);
            date.setMinutes(minutes);
            return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        }

        function getViolationTypeClass(typeLabel) {
            if (!typeLabel || typeof typeLabel !== 'string') return 'default';
            const lower = typeLabel.toLowerCase();
            if (lower.includes('uniform')) return 'uniform';
            if (lower.includes('footwear') || lower.includes('shoe')) return 'footwear';
            if (lower.includes('id')) return 'id';
            if (lower.includes('misconduct') || lower.includes('behavior')) return 'behavior';
            return 'default';
        }

        function getViolationLevelClass(level) {
            // Ensure level is a string and not empty
            if (level === null || level === undefined) return 'default';
            
            // Convert to string if it's not (e.g. number)
            const levelStr = String(level);
            
            const lowerLevel = levelStr.toLowerCase();
            if (lowerLevel.startsWith('permitted')) return 'permitted';
            if (lowerLevel.startsWith('warning')) return 'warning';
            if (lowerLevel === 'disciplinary' || lowerLevel.includes('disciplinary')) return 'disciplinary';
            return 'default';
        }

        function getDepartmentClass(dept) {
            const classes = {
                'BSIS': 'bsis',
                'WFT': 'wft',
                'BTVTED': 'btvted',
                'CHS': 'chs'
            };
            return classes[dept] || 'default';
        }

        function getStatusClass(status) {
            const classes = {
                'permitted': 'permitted',
                'warning': 'warning',
                'disciplinary': 'disciplinary',
                'resolved': 'resolved'
            };
            return classes[status] || 'default';
        }

        function generateCaseId() {
            const year = new Date().getFullYear();
            const lastId = violations.length > 0 ? Math.max(...violations.map(v => {
                const parts = v.caseId.split('-');
                return parts.length > 1 ? parseInt(parts.pop()) : 0;
            })) : 0;
            return `VIOL-${year}-${String(lastId + 1).padStart(3, '0')}`;
        }

        // Helper to load image for exports
        async function loadImage(url) {
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
                img.onerror = () => {
                    console.warn('Could not load image:', url);
                    resolve(null);
                }
                img.src = url;
            });
        }

        // Helper function to get all violations for export based on current filters
        async function getFilteredViolationsForExport() {
            try {
                const search = searchInput ? searchInput.value : '';
                const dept = deptFilter ? deptFilter.value : 'all';
                const status = statusFilter ? statusFilter.value : 'all';
                const dateFrom = dateFromFilter ? dateFromFilter.value : '';
                const dateTo = dateToFilter ? dateToFilter.value : '';
                const isArchived = currentView === 'archive' ? 1 : 0;
                
                let url = API_BASE + `violations.php?is_archived=${isArchived}&filter=${status}&department=${encodeURIComponent(dept)}&date_from=${dateFrom}&date_to=${dateTo}&limit=all&t=${new Date().getTime()}`;
                if (search) {
                    url += `&search=${encodeURIComponent(search)}`;
                }
                
                const response = await fetch(url);
                if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
                
                const result = await response.json();
                if (result.status === 'success') {
                    return result.violations || result.data || [];
                }
                return [];
            } catch (error) {
                console.error('Error fetching violations for export:', error);
                return [];
            }
        }

        async function downloadViolationsPDF() {
            if (!window.jspdf) {
                showNotification('PDF library not loaded. Please refresh.', 'warning');
                return;
            }

            const exportPDFBtn = document.getElementById('exportPDF');
            const originalText = exportPDFBtn.innerHTML;
            exportPDFBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing PDF...</span>";
            exportPDFBtn.disabled = true;

            try {
                const exportViolations = await getFilteredViolationsForExport();
                
                if (exportViolations.length === 0) {
                    showNotification('No violation records found to export.', 'warning');
                    return;
                }

                const { jsPDF } = window.jspdf;
                const doc = new jsPDF('l', 'mm', 'a4'); // Landscape for more columns
                const now = new Date();
                
                // --- Header Design ---
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);

                if (headerData) {
                    // Center header (A4 Landscape width is 297mm)
                    // Image is 140x25mm, so (297-140)/2 = 78.5mm
                    // Visual adjustment: Shift slightly right like student export (e.g. +3mm = 81.5mm)
                    doc.addImage(headerData, 'PNG', 81.5, 5, 140, 25);
                } else {
                    doc.setFontSize(20);
                    doc.setTextColor(44, 62, 80);
                    doc.setFont("helvetica", "bold");
                    doc.text("E-OSAS SYSTEM", 148.5, 15, { align: 'center' });
                    
                    doc.setFontSize(10);
                    doc.setFont("helvetica", "normal");
                    doc.setTextColor(127, 140, 141);
                    doc.text("Office of Student Affairs and Services", 148.5, 22, { align: 'center' });
                }

                // Report Title & Date
                doc.setFontSize(12);
                doc.setTextColor(41, 128, 185); 
                doc.setFont("helvetica", "bold");
                doc.text("VIOLATION LIST REPORT", 148.5, 38, { align: 'center' });

                doc.setFontSize(8);
                doc.setTextColor(100, 100, 100);
                doc.setFont("helvetica", "normal");
                doc.text(`Generated on: ${now.toLocaleDateString()} ${now.toLocaleTimeString()}`, 148.5, 43, { align: 'center' });
                doc.text(`Exported by: ${getCurrentAdminName()}`, 148.5, 47, { align: 'center' });

                // Divider Line
                doc.setDrawColor(220, 220, 220);
                doc.setLineWidth(0.5);
                doc.line(14, 52, 283, 52);
                
                // Summary Stats
                doc.setFontSize(10);
                doc.setTextColor(60, 60, 60);
                doc.text(`Total Records: ${exportViolations.length}`, 14, 62);
                
                let startY = 67;

                // Table
                const tableColumn = ["Case ID", "Student ID", "Name", "Type", "Level", "Date", "Location", "Status"];
                const tableRows = exportViolations.map(v => [
                    v.caseId,
                    v.studentId,
                    v.studentName,
                    v.violationTypeLabel,
                    v.violationLevelLabel,
                    v.dateReported,
                    v.locationLabel,
                    v.statusLabel
                ]);

                doc.autoTable({
                    head: [tableColumn],
                    body: tableRows,
                    startY: startY,
                    theme: 'grid',
                    styles: { fontSize: 8, cellPadding: 2, valign: 'middle' },
                    headStyles: { 
                        fillColor: [245, 245, 245], 
                        textColor: [44, 62, 80], 
                        fontStyle: 'bold'
                    },
                    margin: { top: 60 }
                });

                doc.save(`Violation_List_${now.toISOString().slice(0, 10)}.pdf`);
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            } catch (error) {
                console.error('PDF export error:', error);
                showNotification('Failed to generate PDF document.', 'error');
            } finally {
                exportPDFBtn.innerHTML = originalText;
                exportPDFBtn.disabled = false;
            }
        }

        async function downloadViolationsExcel() {
            const exportExcelBtn = document.getElementById('exportExcel');
            const originalText = exportExcelBtn.innerHTML;
            exportExcelBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing Excel...</span>";
            exportExcelBtn.disabled = true;

            try {
                const exportViolations = await getFilteredViolationsForExport();
                
                if (exportViolations.length === 0) {
                    showNotification('No violation records found to export.', 'warning');
                    return;
                }

                const now = new Date();
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);

                let html = `
                    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
                    <head>
                        <meta charset="UTF-8">
                        <style>
                            .title { font-size: 14pt; font-weight: bold; color: #2980b9; text-align: center; }
                            .subtitle { font-size: 10pt; color: #7f8c8d; text-align: center; }
                            .stats { font-size: 9pt; color: #333; text-align: center; }
                            .data-table th { background-color: #f2f2f2; font-weight: bold; border: 0.5pt solid #000; text-align: center; }
                            .data-table td { border: 0.5pt solid #000; padding: 5px; }
                        </style>
                    </head>
                    <body>
                        <table width="1200" style="width: 1200px; border-collapse: collapse;">
                            ${headerData ? `
                            <tr height="100" style="height: 100px;">
                                <td colspan="8" width="1200" align="center" valign="middle" style="width: 1200px; text-align: center; vertical-align: middle;">
                                    <center>
                                        <div align="center" style="text-align: center;">
                                            <p align="center" style="text-align: center; margin: 0; padding: 0;">
                                                <img src="${headerData}" width="400" height="80" border="0" style="display: inline-block;">
                                            </p>
                                        </div>
                                    </center>
                                </td>
                            </tr>` : ''}
                            <tr><td colspan="8" class="title" align="center" style="text-align: center;">VIOLATION LIST REPORT</td></tr>
                            <tr><td colspan="8" class="subtitle" align="center" style="text-align: center;">Office of Student Affairs and Services</td></tr>
                            <tr><td colspan="8" class="stats" align="center" style="text-align: center;">Generated on: ${now.toLocaleString()}</td></tr>
                            <tr><td colspan="8" class="stats" align="center" style="text-align: center;">Exported by: ${getCurrentAdminName()}</td></tr>
                            <tr><td colspan="8" class="stats" align="center" style="text-align: center;">Total Records: ${exportViolations.length}</td></tr>
                            <tr><td colspan="8" style="height: 20px;"></td></tr>
                            <tr class="data-table">
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Case ID</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Student ID</th>
                                <th width="200" style="width: 200px; background-color: #e0e0e0; border: 0.5pt solid #000;">Student Name</th>
                                <th width="150" style="width: 150px; background-color: #e0e0e0; border: 0.5pt solid #000;">Violation Type</th>
                                <th width="150" style="width: 150px; background-color: #e0e0e0; border: 0.5pt solid #000;">Violation Level</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Date</th>
                                <th width="150" style="width: 150px; background-color: #e0e0e0; border: 0.5pt solid #000;">Location</th>
                                <th width="100" style="width: 100px; background-color: #e0e0e0; border: 0.5pt solid #000;">Status</th>
                            </tr>
                `;

                exportViolations.forEach(v => {
                    html += `
                        <tr>
                            <td>${v.caseId || ''}</td>
                            <td>${v.studentId || ''}</td>
                            <td>${v.studentName || ''}</td>
                            <td>${v.violationTypeLabel || ''}</td>
                            <td>${v.violationLevelLabel || ''}</td>
                            <td>${v.dateReported || ''}</td>
                            <td>${v.locationLabel || ''}</td>
                            <td>${v.statusLabel || ''}</td>
                        </tr>
                    `;
                });

                html += `
                        </table>
                    </body>
                    </html>
                `;

                const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
                const fileName = 'violations_export_' + now.toISOString().slice(0, 10) + '.xls';
                
                if (typeof saveAs === 'function') {
                    saveAs(blob, fileName);
                } else {
                    const url = URL.createObjectURL(blob);
                    const link = document.createElement('a');
                    link.href = url;
                    link.download = fileName;
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                    URL.revokeObjectURL(url);
                }
                
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            } catch (error) {
                console.error('Excel export error:', error);
                showNotification('Failed to generate Excel document.', 'error');
            } finally {
                exportExcelBtn.innerHTML = originalText;
                exportExcelBtn.disabled = false;
            }
        }

        async function downloadViolationsWord() {
            if (!window.docx) {
                showNotification('DOCX library not loaded. Please refresh.', 'warning');
                return;
            }

            const exportWordBtn = document.getElementById('exportWord');
            const originalText = exportWordBtn.innerHTML;
            exportWordBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing Word...</span>";
            exportWordBtn.disabled = true;

            try {
                const exportViolations = await getFilteredViolationsForExport();
                
                if (exportViolations.length === 0) {
                    showNotification('No violation records found to export.', 'warning');
                    return;
                }

                const { Document, Packer, Paragraph, Table, TableCell, TableRow, WidthType, HeadingLevel, TextRun, AlignmentType, ImageRun } = window.docx;
                const now = new Date();
                
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);
                
                const tableHeader = new TableRow({
                    children: [
                        "Case ID", "Student ID", "Name", "Type", "Level", "Date", "Location", "Status"
                    ].map(text => new TableCell({
                        children: [new Paragraph({ text, bold: true, size: 18 })], 
                        shading: { fill: "E0E0E0" }
                    }))
                });
                
                const tableRows = exportViolations.map(v => new TableRow({
                    children: [
                        v.caseId, v.studentId, v.studentName, v.violationTypeLabel, v.violationLevelLabel, v.dateReported, v.locationLabel, v.statusLabel
                    ].map(text => new TableCell({
                        children: [new Paragraph({ text: text || "", size: 16 })]
                    }))
                }));

                const docChildren = [];
                if (headerData) {
                    docChildren.push(new Paragraph({
                        children: [new ImageRun({ data: headerData, transformation: { width: 400, height: 80 } })],
                        alignment: AlignmentType.CENTER
                    }));
                }

                docChildren.push(
                    new Paragraph({
                        text: "VIOLATION LIST REPORT",
                        heading: HeadingLevel.HEADING_2,
                        alignment: AlignmentType.CENTER,
                        spacing: { before: 200 }
                    }),
                    new Paragraph({
                        children: [new TextRun({ text: `Office of Student Affairs and Services`, italics: true, color: "666666", size: 18 })],
                        alignment: AlignmentType.CENTER
                    }),
                    new Paragraph({
                        children: [new TextRun({ text: `Generated: ${now.toLocaleString()}`, italics: true, color: "999999", size: 16 })],
                        alignment: AlignmentType.CENTER
                    }),
                    new Paragraph({
                        children: [new TextRun({ text: `Exported by: ${getCurrentAdminName()}`, italics: true, color: "999999", size: 16 })],
                        alignment: AlignmentType.CENTER,
                        spacing: { after: 400 }
                    }),
                    new Paragraph({ text: `Total Records: ${exportViolations.length}`, spacing: { after: 200 } }),
                    new Table({
                        rows: [tableHeader, ...tableRows],
                        width: { size: 100, type: WidthType.PERCENTAGE }
                    })
                );

                const doc = new Document({ sections: [{ children: docChildren }] });
                const blob = await Packer.toBlob(doc);
                saveAs(blob, `Violation_List_${now.toISOString().slice(0, 10)}.docx`);
                
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            } catch (error) {
                console.error('Word export error:', error);
                showNotification('Failed to generate Word document.', 'error');
            } finally {
                exportWordBtn.innerHTML = originalText;
                exportWordBtn.disabled = false;
            }
        }

        // SYNC OFFLINE ACTIONS
        window.syncOfflineActions = async function() {
            if (!navigator.onLine || !window.offlineDB) return;
            
            const queue = await window.offlineDB.getSyncQueue();
            if (queue.length === 0) return;
            
            console.log(`🔄 Syncing ${queue.length} offline actions...`);
            showNotification(`Syncing ${queue.length} offline records...`, 'info');
            
            for (const item of queue) {
                try {
                    if (item.action === 'POST_VIOLATION') {
                        const formData = new FormData();
                        for (const key in item.data) {
                            formData.append(key, item.data[key]);
                        }
                        
                        const response = await fetch(API_BASE + 'violations.php', {
                            method: 'POST',
                            body: formData
                        });
                        
                        if (response.ok) {
                            await window.offlineDB.removeFromQueue(item.tempId);
                            console.log('✅ Action synced successfully:', item.tempId);
                        }
                    }
                } catch (error) {
                    console.error('❌ Sync failed for item:', item.tempId, error);
                }
            }
            
            // Reload after sync
            await loadViolations(false);
            renderViolations();
            showNotification('Offline data synced successfully!', 'success');
        };

        // ========== STUDENT DETAILS FUNCTIONS ==========

        // Check if search term looks like a student ID
        function isStudentIdSearch(searchTerm) {
            if (!searchTerm || searchTerm.trim() === '') return false;

            const term = searchTerm.trim().toLowerCase();

            // Check for student ID patterns (contains numbers, specific formats)
            const studentIdPatterns = [
                /^\d{4}-\d{3,4}$/,  // 2024-001 format
                /^\d{7,8}$/,        // 2024001 format
                /^20\d{2}-\d{3,4}$/, // Year-based format
                /^student.*\d/i,    // Contains "student" and numbers
                /\b\d{3,4}\b/       // 3-4 digit numbers (student IDs)
            ];

            return studentIdPatterns.some(pattern => pattern.test(term));
        }

        // Find student by search term
        function findStudentBySearchTerm(searchTerm) {
            if (!searchTerm || !students.length) return null;

            const term = searchTerm.trim().toLowerCase();

            // First try exact student ID match
            let student = students.find(s =>
                s.studentId.toLowerCase() === term ||
                s.studentId.toLowerCase().includes(term)
            );

            if (student) return student;

            // Then try name match
            student = students.find(s =>
                s.firstName.toLowerCase().includes(term) ||
                s.lastName.toLowerCase().includes(term) ||
                `${s.firstName} ${s.lastName}`.toLowerCase().includes(term)
            );

            return student;
        }

        // Get all violations for a specific student
        function getStudentViolations(studentId) {
            return violations.filter(v => v.studentId === studentId);
        }

        // Render student details panel
        function renderStudentDetails(student, studentViolations) {
            const panel = document.getElementById('studentDetailsPanel');
            if (!panel || !student) return;

            // Calculate statistics
            const totalViolations = studentViolations.length;
            const resolvedViolations = studentViolations.filter(v => v.status === 'resolved').length;
            
            // Apply Warning 3 -> Disciplinary logic for counts
            const disciplinaryViolations = studentViolations.filter(v => {
                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                return v.status === 'disciplinary' || levelLabel.includes('warning 3') || levelLabel.includes('3rd');
            }).length;
            
            const pendingViolations = studentViolations.filter(v => {
                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) return false;
                return ['warning', 'permitted'].includes(v.status);
            }).length;

            // Render student profile
            const profileCard = document.getElementById('studentProfileCard');
            const fullName = `${student.firstName} ${student.middleName ? student.middleName + ' ' : ''}${student.lastName}`;
            const studentImageUrl = getImageUrl(student.avatar, fullName);
            
            profileCard.innerHTML = `
                <div class="student-profile-image">
                    <img src="${studentImageUrl}"
                         alt="${fullName}"
                         onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(fullName)}&background=ffd700&color=333&size=80'">
                </div>
                <div class="student-profile-info">
                    <h3>${fullName}</h3>
                    <div class="student-profile-meta">
                        <span class="student-id">ID: ${student.studentId}</span>
                        <span>Department: ${student.department || 'N/A'}</span>
                        <span>Section: ${student.section || 'N/A'}</span>
                        <span>Contact: ${student.contact || 'N/A'}</span>
                    </div>
                </div>
            `;

            // Render statistics
            const statsGrid = document.getElementById('studentStatsGrid');
            statsGrid.innerHTML = `
                <div class="student-stat-card">
                    <div class="student-stat-number">${totalViolations}</div>
                    <div class="student-stat-label">Total Violations</div>
                </div>
                <div class="student-stat-card">
                    <div class="student-stat-number">${resolvedViolations}</div>
                    <div class="student-stat-label">Resolved</div>
                </div>
                <div class="student-stat-card">
                    <div class="student-stat-number">${pendingViolations}</div>
                    <div class="student-stat-label">Pending</div>
                </div>
                <div class="student-stat-card">
                    <div class="student-stat-number">${disciplinaryViolations}</div>
                    <div class="student-stat-label">Disciplinary</div>
                </div>
            `;

            // Render violation timeline
            const timeline = document.getElementById('studentViolationsTimeline');

            if (studentViolations.length === 0) {
                timeline.innerHTML = `
                    <div style="text-align: center; padding: 40px; color: var(--dark-grey);">
                        <i class='bx bx-check-circle' style="font-size: 48px; margin-bottom: 16px;"></i>
                        <div>No violations found for this student</div>
                    </div>
                `;
            } else {
                // Sort violations by date (newest first)
                const sortedViolations = [...studentViolations].sort((a, b) =>
                    new Date(b.dateReported) - new Date(a.dateReported)
                );

                timeline.innerHTML = sortedViolations.map(violation => {
                    let displayStatus = violation.status;
                    const levelLabel = (violation.violationLevelLabel || '').toLowerCase();
                    if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                        displayStatus = 'disciplinary';
                    }
                    
                    const statusClass = getStatusClass(displayStatus);
                    const typeClass = getViolationTypeClass(violation.violationTypeLabel);

                    return `
                        <div class="student-violation-item">
                            <div class="student-violation-icon ${statusClass}">
                                <i class='bx bx-${displayStatus === 'resolved' ? 'check' : displayStatus === 'disciplinary' ? 'x' : 'error'}-circle'></i>
                            </div>
                            <div class="student-violation-content">
                                <div class="student-violation-header">
                                    <span class="student-violation-case">${violation.caseId}</span>
                                    <span class="student-violation-date">${violation.dateTime}</span>
                                </div>
                                <div class="student-violation-type">${violation.violationTypeLabel} - ${violation.violationLevelLabel}</div>
                                <div class="student-violation-location">Location: ${violation.locationLabel}</div>
                                ${violation.notes ? `<div class="student-violation-notes">"${violation.notes}"</div>` : ''}
                            </div>
                        </div>
                    `;
                }).join('');
            }

            // Show the panel
            panel.style.display = 'block';
            panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }

        // Hide student details panel
        function hideStudentDetails() {
            const panel = document.getElementById('studentDetailsPanel');
            if (panel) {
                panel.style.display = 'none';
            }
        }

        // ========== RENDER FUNCTIONS ==========
        
        function renderViolationsPagination() {
            const container = document.querySelector('.Violations-pagination');
            if (!container) return;
            
            if (!totalPages || totalPages <= 1) {
                container.innerHTML = `
                    <button class="Violations-pagination-btn" disabled>
                      <i class='bx bx-chevron-left'></i>
                    </button>
                    <button class="Violations-pagination-btn active">1</button>
                    <button class="Violations-pagination-btn" disabled>
                      <i class='bx bx-chevron-right'></i>
                    </button>
                `;
                return;
            }
            
            let html = '';
            html += `<button class="Violations-pagination-btn ${currentPage === 1 ? 'disabled' : ''}" ${currentPage === 1 ? 'disabled' : ''} onclick="window.changeViolationsPage(${currentPage - 1})"><i class='bx bx-chevron-left'></i></button>`;
            
            for (let i = 1; i <= totalPages; i++) {
                if (i === 1 || i === totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
                    html += `<button class="Violations-pagination-btn ${i === currentPage ? 'active' : ''}" onclick="window.changeViolationsPage(${i})">${i}</button>`;
                } else if (i === currentPage - 2 || i === currentPage + 2) {
                    html += `<span class="Violations-pagination-ellipsis">...</span>`;
                }
            }
            
            html += `<button class="Violations-pagination-btn ${currentPage === totalPages ? 'disabled' : ''}" ${currentPage === totalPages ? 'disabled' : ''} onclick="window.changeViolationsPage(${currentPage + 1})"><i class='bx bx-chevron-right'></i></button>`;
            container.innerHTML = html;
        }
        
        window.changeViolationsPage = function(page) {
            if (page < 1 || page > totalPages || page === currentPage) return;
            currentPage = page;
            renderViolations();
        };
        
        function renderViolations() {
            console.log('🎨 renderViolations called, tableBody exists:', !!tableBody);
            console.log('📊 Current violations data:', violations.length, 'items');

            if (!tableBody) {
                console.error('❌ tableBody element not found!');
                return;
            }

            const searchTerm = searchInput ? searchInput.value.toLowerCase() : '';
            const deptValue = deptFilter ? deptFilter.value : 'all';
            const statusValue = statusFilter ? statusFilter.value : 'all';
            const dateFromValue = dateFromFilter ? dateFromFilter.value : '';
            const dateToValue = dateToFilter ? dateToFilter.value : '';

            // Get archive filters if in archive view
            const archiveDeptFilter = document.getElementById('ArchiveDeptFilter');
            const archiveMonthFilter = document.getElementById('ArchiveMonthFilter');
            const archiveDateFromFilter = document.getElementById('ArchiveDateFrom');
            const archiveDateToFilter = document.getElementById('ArchiveDateTo');
            const archiveSearchInput = document.getElementById('searchViolationArchive');

            const currentDept = currentView === 'current' ? deptValue : (archiveDeptFilter ? archiveDeptFilter.value : 'all');
            const currentMonth = currentView === 'archive' && archiveMonthFilter ? archiveMonthFilter.value : 'all';
            const currentDateFrom = currentView === 'current' ? dateFromValue : (archiveDateFromFilter ? archiveDateFromFilter.value : '');
            const currentDateTo = currentView === 'current' ? dateToValue : (archiveDateToFilter ? archiveDateToFilter.value : '');
            const currentSearchTerm = currentView === 'current' ? searchTerm : (archiveSearchInput ? archiveSearchInput.value.toLowerCase() : searchTerm);

            console.log('🔍 Filter values:', { currentSearchTerm, currentDept, currentMonth, currentDateFrom, currentDateTo, currentView });

            // LOGIC CHANGE: Show only latest violation per student by default (when not searching)
            let sourceViolations = violations;
            
            if (!currentSearchTerm && currentView === 'current') {
                const uniqueStudentMap = new Map();
                violations.forEach(v => {
                    // Violations are sorted by date DESC from backend, so first encounter is latest
                    if (!uniqueStudentMap.has(v.studentId)) {
                        uniqueStudentMap.set(v.studentId, v);
                    }
                });
                sourceViolations = Array.from(uniqueStudentMap.values());
                console.log('📉 Grouped by student (latest only):', sourceViolations.length, 'unique students');
            }

            filteredViolations = sourceViolations.filter(v => {
                if (!v) {
                    console.warn('⚠️ Found null/undefined violation object');
                    return false;
                }

                const matchesSearch = v.studentName.toLowerCase().includes(currentSearchTerm) ||
                                    v.caseId.toLowerCase().includes(currentSearchTerm) ||
                                    v.studentId.toLowerCase().includes(currentSearchTerm) ||
                                    v.violationTypeLabel.toLowerCase().includes(currentSearchTerm);
                const matchesDept = currentDept === 'all' || v.department === currentDept || v.department_code === currentDept;
                const matchesStatus = currentView === 'current' ? (statusValue === 'all' || v.status === statusValue) : true;

                // Month filtering for archive
                let matchesMonth = true;
                if (currentMonth !== 'all') {
                    const violationDateStr = v.dateReported || v.violationDate;
                    if (violationDateStr) {
                        const violationDate = new Date(violationDateStr);
                        if ((violationDate.getMonth() + 1).toString() !== currentMonth) {
                            matchesMonth = false;
                        }
                    } else {
                        matchesMonth = false;
                    }
                }

                // Date filtering logic
                let matchesDate = true;
                if (currentDateFrom || currentDateTo) {
                    const violationDateStr = v.dateReported || v.violationDate;
                    if (violationDateStr) {
                        const violationDate = new Date(violationDateStr);
                        violationDate.setHours(0, 0, 0, 0);
                        
                        if (currentDateFrom) {
                            const fromDate = new Date(currentDateFrom);
                            fromDate.setHours(0, 0, 0, 0);
                            if (violationDate < fromDate) matchesDate = false;
                        }
                        
                        if (currentDateTo && matchesDate) {
                            const toDate = new Date(currentDateTo);
                            toDate.setHours(0, 0, 0, 0);
                            if (violationDate > toDate) matchesDate = false;
                        }
                    } else {
                        matchesDate = false;
                    }
                }

                return matchesSearch && matchesDept && matchesStatus && matchesDate && matchesMonth;
            });

            console.log('📋 Filtered violations:', filteredViolations.length, 'items');
            
            // Pagination calculations
            totalRecords = filteredViolations.length;
            totalPages = Math.ceil(totalRecords / itemsPerPage) || 1;
            if (currentPage > totalPages) {
                currentPage = totalPages;
            }
            const start = (currentPage - 1) * itemsPerPage;
            const end = start + itemsPerPage;
            const pageItems = filteredViolations.slice(start, end);

            // Check for student ID search and show student details
            const trimmedSearchTerm = searchInput ? searchInput.value.trim() : '';
            if (trimmedSearchTerm && isStudentIdSearch(trimmedSearchTerm)) {
                const foundStudent = findStudentBySearchTerm(trimmedSearchTerm);
                if (foundStudent) {
                    const studentViolations = getStudentViolations(foundStudent.studentId);
                    renderStudentDetails(foundStudent, studentViolations);
                } else {
                    hideStudentDetails();
                }
            } else {
                hideStudentDetails();
            }

            // Show/hide empty state
            const emptyState = document.getElementById('ViolationsEmptyState');
            if (emptyState) {
                emptyState.style.display = filteredViolations.length === 0 ? 'flex' : 'none';
                console.log('📭 Empty state display:', filteredViolations.length === 0 ? 'shown' : 'hidden');
            }

            console.log('🛠️ Generating table rows for', pageItems.length, 'violations');

            const tableRows = pageItems.map(v => {
                if (!v.id && v.id !== 0) {
                    console.error('❌ Missing violation ID for item:', v);
                }
                
                // Override Status Display Logic:
                // If the level is Warning 3, it should ALWAYS display as Disciplinary, 
                // regardless of what the database status says (to fix legacy data).
                let displayStatus = v.status;
                let displayStatusLabel = v.statusLabel;

                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                    displayStatus = 'disciplinary';
                    displayStatusLabel = 'Disciplinary';
                }

                const typeClass = getViolationTypeClass(v.violationTypeLabel);
                const levelClass = getViolationLevelClass(v.violationLevelLabel || '');
                const deptClass = getDepartmentClass(v.department);
                const statusClass = getStatusClass(displayStatus);

                return `
                <tr data-id="${v.id}">
                    <td class="violation-case-id" data-label="Case ID">#${v.caseId}</td>
                    <td class="violation-student-cell" data-label="Student">
                        <div class="violation-student-info">
                            <div class="violation-student-image">
                                <img src="${v.studentImage}" 
                                     alt="${v.studentName}" 
                                     class="student-avatar"
                                     onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(v.studentName)}&background=ffd700&color=333&size=32'">
                            </div>
                            <div class="violation-student-name">
                                <strong>${v.studentName}</strong>
                                <small>${v.section || 'N/A'} • ${v.studentYearlevel || 'N/A'}</small>
                            </div>
                        </div>
                    </td>
                    <td class="violation-student-id" data-label="Student ID">${v.studentId}</td>
                    <td class="violation-type" data-label="Violation Type">
                        <span class="violation-type-badge ${typeClass}">${v.violationTypeLabel}</span>
                    </td>
                    <td class="violation-level" data-label="Offense Level">
                        <span class="violation-level-badge ${levelClass}">${v.violationLevelLabel}</span>
                    </td>
                    <td class="violation-dept" data-label="Department">
                        <span class="dept-badge ${deptClass}">${v.department}</span>
                    </td>
                    <td class="violation-section" data-label="Section">${v.section}</td>
                    <td class="violation-yearlevel" data-label="Year Level">
                        <span class="yearlevel-badge">${v.studentYearlevel || 'N/A'}</span>
                    </td>
                    <td class="violation-date" data-label="Date Reported">${formatDate(v.dateReported)}</td>
                    <td data-label="Status">
                        <span class="Violations-status-badge ${statusClass}">${displayStatusLabel}</span>
                    </td>
                    <td data-label="Actions">
                        <div class="Violations-action-buttons">
                            <button class="Violations-action-btn view" data-id="${v.id}" title="View Details">
                                <i class='bx bx-show'></i>
                            </button>
                            <!-- Edit button removed as per request -->
                            <button class="Violations-action-btn entrance" data-id="${v.id}" title="Generate Entrance Slip">
                                <i class='bx bx-receipt'></i>
                            </button>
                            ${displayStatus === 'resolved' ? 
                                `<button class="Violations-action-btn reopen" data-id="${v.id}" title="Reopen">
                                    <i class='bx bx-rotate-left'></i>
                                </button>` : 
                                (displayStatus === 'disciplinary' ? 
                                `<button class="Violations-action-btn resolve" data-id="${v.id}" title="Mark Resolved">
                                    <i class='bx bx-check'></i>
                                </button>` : '')
                            }
                        </div>
                    </td>
                </tr>
            `});

            console.log('📄 Generated HTML rows:', tableRows.length, 'table rows');
            console.log('📄 First row preview:', tableRows[0] ? tableRows[0].substring(0, 100) + '...' : 'No rows');

            tableBody.innerHTML = tableRows.join('');

            console.log('✅ Table HTML set, row count in DOM:', tableBody.querySelectorAll('tr').length);

            updateStats();
            updateCounts(pageItems);
            renderViolationsPagination();

            updateStats();
            updateCounts(pageItems);
            renderViolationsPagination();
        }

        function updateStats() {
            const total = violations.length;
            const resolved = violations.filter(v => v.status === 'resolved').length;
            
            // Apply Warning 3 -> Disciplinary logic for counts
            const disciplinary = violations.filter(v => {
                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                return v.status === 'disciplinary' || levelLabel.includes('warning 3') || levelLabel.includes('3rd');
            }).length;
            
            const pending = violations.filter(v => {
                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) return false;
                return v.status === 'warning' || v.status === 'permitted';
            }).length;
            
            const totalEl = document.getElementById('totalViolations');
            const resolvedEl = document.getElementById('resolvedViolations');
            const pendingEl = document.getElementById('pendingViolations');
            const disciplinaryEl = document.getElementById('disciplinaryViolations');
            const resolvedPctEl = document.getElementById('resolvedViolationsPct');
            const pendingPctEl = document.getElementById('pendingViolationsPct');
            const disciplinaryPctEl = document.getElementById('disciplinaryViolationsPct');
            
            if (totalEl) totalEl.textContent = total;
            if (resolvedEl) resolvedEl.textContent = resolved;
            if (pendingEl) pendingEl.textContent = pending;
            if (disciplinaryEl) disciplinaryEl.textContent = disciplinary;

            const resolvedPct = total > 0 ? Math.round((resolved / total) * 100) : 0;
            const pendingPct = total > 0 ? Math.round((pending / total) * 100) : 0;
            const disciplinaryPct = total > 0 ? Math.round((disciplinary / total) * 100) : 0;
            if (resolvedPctEl) resolvedPctEl.textContent = `${resolvedPct}%`;
            if (pendingPctEl) pendingPctEl.textContent = `${pendingPct}%`;
            if (disciplinaryPctEl) disciplinaryPctEl.textContent = `${disciplinaryPct}%`;
        }

        function updateCounts(filteredViolations) {
            const showingEl = document.getElementById('showingViolationsCount');
            const totalCountEl = document.getElementById('totalViolationsCount');
            
            if (showingEl) showingEl.textContent = filteredViolations.length;
            if (totalCountEl) totalCountEl.textContent = totalRecords;
        }

        // ========== MODAL FUNCTIONS ==========
        
        function openRecordModal(editId = null) {
            console.log('🎯 Opening record modal...');
            recordModal.classList.add('active');
            document.body.style.overflow = 'hidden';
            
            // Clear previous attachments selection
            selectedFiles = [];
            updateAttachmentPreviews();
            
            // Show/hide entrance slip button
            if (modalEntranceBtn) {
                modalEntranceBtn.style.display = editId ? 'flex' : 'none';
            }
            
            // Set today's date as default
            const today = new Date().toISOString().split('T')[0];
            const dateInput = document.getElementById('violationDate');
            if (dateInput) dateInput.value = today;
            
            // Set current time
            const now = new Date();
            const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
            const timeInput = document.getElementById('violationTime');
            if (timeInput) timeInput.value = timeStr;

            const modalTitle = document.getElementById('violationModalTitle');
            const form = document.getElementById('ViolationRecordForm');
            
            // Function to populate admin name
            const populateAdminName = () => {
                const reportedByInput = document.getElementById('reportedBy');
                if (reportedByInput) {
                    const sessionStr = localStorage.getItem('userSession');
                    if (sessionStr) {
                        try {
                            const session = JSON.parse(sessionStr);
                            // Prioritize full_name, then name, then username
                            const adminName = session.full_name || session.name || session.username || '';
                            reportedByInput.value = adminName;
                            console.log('👤 Auto-populated reporter:', adminName);
                        } catch (e) {
                            console.error('Error parsing session for reporter:', e);
                        }
                    }
                }
            };
            
            if (editId) {
                // Edit mode
                recordModal.dataset.editingId = editId;
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Edit Violation';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-shield-x\'></i><span>Edit Violation</span>';
                }
                const violation = violations.find(v => v.id == editId);
                if (violation) {
                    // Populate student info
                    document.getElementById('modalStudentId').textContent = violation.studentId;
                    document.getElementById('modalStudentName').textContent = violation.studentName;
                    const modalStudentImage = document.getElementById('modalStudentImage');
                    if (modalStudentImage) {
                        modalStudentImage.src = violation.studentImage;
                        modalStudentImage.onerror = function() {
                            this.onerror = null;
                            this.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(violation.studentName)}&background=ffd700&color=333&size=80`;
                        };
                    }
                    document.getElementById('modalStudentDept').textContent = violation.studentDept;
                    document.getElementById('modalStudentSection').textContent = violation.studentSection;
                    document.getElementById('modalStudentYearlevel').textContent = violation.studentYearlevel || 'N/A';
                    document.getElementById('modalStudentContact').textContent = violation.studentContact;
                    if (selectedStudentCard) selectedStudentCard.style.display = 'flex';

                    // Set violation type
                    const typeRadio = document.querySelector(`input[name="violationType"][value="${violation.violationType}"]`);
                    if (typeRadio) {
                        typeRadio.checked = true;
                        // Update visual state
                        document.querySelectorAll('.violation-type-card').forEach(c => c.classList.remove('active'));
                        const card = typeRadio.closest('.violation-type-card');
                        if (card) card.classList.add('active');
                        
                        // Render levels for this type
                        console.log('Rendering levels for type:', violation.violationType);
                        renderViolationLevels(violation.violationType);
                    }

                    // Update badges for this student
                    updateViolationTypeBadges(violation.studentId);

                    // Set violation level (must be done AFTER rendering levels)
                    // We use a small helper to retry selection as DOM updates might be async/batched
                    const selectLevel = (attempts = 0) => {
                        const targetLevelId = parseInt(violation.violationLevel);
                        const targetLevelName = violation.violationLevelLabel;
                        
                        console.log(`Attempt ${attempts + 1}: Setting violation level. Target ID: ${targetLevelId}, Name: ${targetLevelName}`);
                        
                        const allRadios = document.querySelectorAll('input[name="violationLevel"]');
                        let found = false;
                        
                        // Strategy 1: Match by ID
                        allRadios.forEach(radio => {
                            if (!isNaN(targetLevelId) && parseInt(radio.value) === targetLevelId) {
                                radio.checked = true;
                                found = true;
                                // Update visual state
                                const option = radio.closest('.violation-level-option');
                                if (option) {
                                    option.classList.add('active');
                                    console.log('✅ Activated option by ID:', targetLevelId);
                                }
                            } else {
                                // Ensure others are not active
                                const option = radio.closest('.violation-level-option');
                                if (option) option.classList.remove('active');
                            }
                        });

                        // Strategy 2: Match by Name (Fallback)
                        if (!found && targetLevelName) {
                            console.log('⚠️ ID match failed, trying name match:', targetLevelName);
                            allRadios.forEach(radio => {
                                const label = radio.nextElementSibling;
                                const title = label ? label.querySelector('.level-title') : null;
                                if (title && title.textContent.trim() === targetLevelName.trim()) {
                                     radio.checked = true;
                                     found = true;
                                     const option = radio.closest('.violation-level-option');
                                     if (option) {
                                         option.classList.add('active');
                                         console.log('✅ Activated option by Name:', targetLevelName);
                                     }
                                }
                            });
                        }

                        if (!found && attempts < 5) {
                            // Retry a few times
                            setTimeout(() => selectLevel(attempts + 1), 100);
                        } else if (!found) {
                            console.error('❌ Failed to select level after retries');
                            
                            // VISUAL DEBUG - Show error in modal for troubleshooting
                            // Only show if we have radios but couldn't match (prevents showing on empty container)
                            if (allRadios.length > 0) {
                                const container = document.getElementById('violationLevelsContainer');
                                if (container && !container.querySelector('.debug-err')) {
                                     const debugMsg = document.createElement('div');
                                     debugMsg.className = 'debug-err';
                                     debugMsg.style.color = 'red';
                                     debugMsg.style.fontSize = '11px';
                                     debugMsg.style.marginTop = '8px';
                                     debugMsg.style.padding = '4px';
                                     debugMsg.style.background = '#fff0f0';
                                     debugMsg.style.border = '1px solid red';
                                     debugMsg.innerHTML = `<strong>Debug Error:</strong> Could not auto-select level.<br>
                                     Target ID: ${targetLevelId} (${typeof targetLevelId})<br>
                                     Target Name: "${targetLevelName}"<br>
                                     Available IDs: ${Array.from(allRadios).map(r => r.value).join(', ')}`;
                                     container.appendChild(debugMsg);
                                }
                            }
                        }
                    };
                    
                    // Call immediately
                    selectLevel();

                    // Set other fields
                    document.getElementById('violationDate').value = violation.dateReported;
                    document.getElementById('violationTime').value = violation.violationTime || '08:15';
                    document.getElementById('violationLocation').value = violation.location;
                    
                    const reportedByInput = document.getElementById('reportedBy');
                    if (reportedByInput) {
                        reportedByInput.value = violation.reportedBy || '';
                        // If empty (legacy data), populate with current admin
                        if (!reportedByInput.value) {
                            populateAdminName();
                        }
                    }
                    
                    document.getElementById('violationNotes').value = violation.notes || '';

                    // Update notes counter
                    updateNotesCounter((violation.notes || '').length);
                }
            } else {
                // Add new mode
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Record New Violation';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-shield-x\'></i><span>Record New Violation</span>';
                }
                if (form) {
                    form.reset();
                    populateAdminName();
                    
                    // Clear any previous levels and type selection
                    const levelsContainer = document.getElementById('violationLevelsContainer');
                    if (levelsContainer) levelsContainer.innerHTML = '';
                    
                    document.querySelectorAll('.violation-type-card').forEach(c => c.classList.remove('active'));
                    document.querySelectorAll('.violation-level-option').forEach(c => c.classList.remove('active'));
                    
                    // Clear violation type badges
                    document.querySelectorAll('.violation-type-badge-overlay').forEach(el => el.remove());
                    
                    // Clear student search and details
                    if (studentSearchInput) studentSearchInput.value = '';
                    
                    // Explicitly clear all student info fields
                    document.getElementById('modalStudentId').textContent = '';
                    document.getElementById('modalStudentName').textContent = '';
                    const modalStudentImage = document.getElementById('modalStudentImage');
                    if (modalStudentImage) modalStudentImage.src = ''; // Clear image or set to default
                    document.getElementById('modalStudentDept').textContent = '';
                    document.getElementById('modalStudentSection').textContent = '';
                    document.getElementById('modalStudentYearlevel').textContent = '';
                    document.getElementById('modalStudentContact').textContent = '';
                    
                    if (selectedStudentCard) selectedStudentCard.style.display = 'none';
                    
                    // Re-set default values after reset
                    setTimeout(() => {
                        const today = new Date().toISOString().split('T')[0];
                        const dateInput = document.getElementById('violationDate');
                        if (dateInput && !dateInput.value) dateInput.value = today;

                        const now = new Date();
                        const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
                        const timeInput = document.getElementById('violationTime');
                        if (timeInput && !timeInput.value) timeInput.value = timeStr;

                        // Also populate admin name after reset
                        populateAdminName();
                    }, 50);
                }
                if (selectedStudentCard) selectedStudentCard.style.display = 'none';
            
            // Clear attachments
            selectedFiles = [];
            updateAttachmentPreviews();
            
            delete recordModal.dataset.editingId;

                // Reset notes counter
                updateNotesCounter(0);
            }

            // Reset form validation state and progress
            formValidationState = {
                isValid: false,
                errors: {},
                touched: {}
            };

            // Clear all field errors
            document.querySelectorAll('.field-error').forEach(el => {
                if (el.tagName === 'DIV') el.remove();
                else el.classList.remove('field-error');
            });

            // Reset progress bar
            updateFormProgress(0, 8);

            // Initial validation after a short delay to ensure all fields are populated
            setTimeout(() => {
                console.log('Running initial form validation...');
                validateEntireForm();
            }, 150);
        }

        function openDetailsModal(violationId) {
            console.log('📖 openDetailsModal called with ID:', violationId);
            if (!detailsModal) {
                console.error('❌ Details modal element (#ViolationDetailsModal) not found!');
                return;
            }
            
            const violation = violations.find(v => v.id == violationId);
            if (!violation) {
                console.error('❌ Violation not found for ID:', violationId);
                console.log('Available violations:', violations.map(v => v.id));
                alert('Error: Violation details not found. Please refresh the page.');
                return;
            }
            
            console.log('Opening details modal for violation:', violation);
            
            // Helper functions for safe element access
            const setElementText = (id, text) => {
                const el = document.getElementById(id);
                if (el) el.textContent = text || 'N/A';
            };
            
            const setElementSrc = (id, src) => {
                const el = document.getElementById(id);
                if (el) el.src = src;
            };
            
            const setElementClass = (id, className) => {
                const el = document.getElementById(id);
                if (el) el.className = className;
            };
            
            // Case header
            // Override Status Display Logic for Modal:
            let displayStatus = violation.status;
            let displayStatusLabel = violation.statusLabel;

            const levelLabel = (violation.violationLevelLabel || '').toLowerCase();
            if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                displayStatus = 'disciplinary';
                displayStatusLabel = 'Disciplinary';
            }

            setElementText('detailCaseId', '#' + violation.caseId);
            setElementText('detailStatusBadge', displayStatusLabel);
            setElementClass('detailStatusBadge', `case-status-badge ${getStatusClass(displayStatus)}`);
            
            // Student info with fixed image URL
            const studentImageUrl = getImageUrl(violation.studentImage, violation.studentName);
            console.log('📷 Detail modal student image URL:', studentImageUrl);
            setElementSrc('detailStudentImage', studentImageUrl);
            setElementText('detailStudentName', violation.studentName);
            setElementText('detailStudentId', violation.studentId);
            setElementText('detailStudentDept', violation.department);
            setElementClass('detailStudentDept', `student-dept badge ${getDepartmentClass(violation.department)}`);
            setElementText('detailStudentSection', violation.section);
            setElementText('detailStudentContact', violation.studentContact);
            
            // Violation details
            // Aggregate all violation types and levels for this student
            let studentViolations = violations.filter(v => v.studentId === violation.studentId);
            
            // Sort violations by date descending (newest first)
            studentViolations.sort((a, b) => {
                 const dateA = new Date((a.dateReported || a.date || a.violationDate) + ' ' + (a.violationTime || '00:00'));
                 const dateB = new Date((b.dateReported || b.date || b.violationDate) + ' ' + (b.violationTime || '00:00'));
                 return dateB - dateA;
            });

            // Keep only the latest record per violation type
            const latestByType = new Map();
            studentViolations.forEach(v => {
                const type = v.violationTypeLabel || 'Unknown';
                if (!latestByType.has(type)) {
                    latestByType.set(type, v);
                }
            });
            
            // Convert back to array
            studentViolations = Array.from(latestByType.values());
            
            // No need to sort again as the Map insertion order (or the source array order) was already sorted,
            // but for safety let's sort again to ensure display order is correct
             studentViolations.sort((a, b) => {
                 const dateA = new Date((a.dateReported || a.date || a.violationDate) + ' ' + (a.violationTime || '00:00'));
                 const dateB = new Date((b.dateReported || b.date || b.violationDate) + ' ' + (b.violationTime || '00:00'));
                 return dateB - dateA;
            });

            // Helper to render list preserving order
            const renderList = (containerId, items, renderer) => {
                const container = document.getElementById(containerId);
                if (container) {
                     container.className = 'detail-value-container';
                     container.innerHTML = items.map(item => {
                         // Ensure we render SOMETHING to maintain vertical slot, even if empty
                         // Use min-height to ensure alignment
                         const content = renderer(item);
                         return `<div style="margin-bottom: 4px; min-height: 24px; line-height: 24px;">${content}</div>`;
                     }).join('');
                }
            };

            // Types
            renderList('detailViolationType', studentViolations, v => {
                const type = v.violationTypeLabel || 'Unknown';
                return `<span class="badge ${getViolationTypeClass(type)}">${type}</span>`;
            });

            // Levels
            renderList('detailViolationLevel', studentViolations, v => {
                const level = v.violationLevelLabel || '-';
                const badgeClass = level !== '-' ? `badge ${getViolationLevelClass(level)}` : '';
                return `<span class="${badgeClass}">${level}</span>`;
            });

            // Dates
            renderList('detailDateTime', studentViolations, v => v.dateTime || v.dateReported || '-');

            // Locations
            renderList('detailLocation', studentViolations, v => v.locationLabel || v.location || '-');

            // Reported By
            renderList('detailReportedBy', studentViolations, v => v.reportedBy || '-');
            
            // Statuses
            renderList('detailStatus', studentViolations, v => {
                let itemStatus = v.status;
                let itemStatusLabel = v.statusLabel || (itemStatus ? itemStatus.charAt(0).toUpperCase() + itemStatus.slice(1) : 'Unknown');
                
                const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                    itemStatus = 'disciplinary';
                    itemStatusLabel = 'Disciplinary';
                }
                
                return `<span class="badge ${getStatusClass(itemStatus)}">${itemStatusLabel}</span>`;
            });
            
            setElementText('detailNotes', violation.notes || 'No notes available.');
            
            // Attachments display
             const attachmentsContainer = document.getElementById('detailAttachments');
             if (attachmentsContainer) {
                 if (violation.attachments && violation.attachments.length > 0) {
                     attachmentsContainer.innerHTML = violation.attachments.map(filePath => {
                         // Resolve full URL for the attachment
                         const fullUrl = getImageUrl(filePath);
                         const fileName = filePath.split('/').pop();
                         const isImage = /\.(jpg|jpeg|png|gif|webp)$/i.test(fileName);
                         
                         return `<a href="${fullUrl}" target="_blank" class="attachment-item">
                             <i class='bx ${isImage ? 'bx-image' : 'bx-file'}'></i>
                             <span>${fileName}</span>
                         </a>`;
                     }).join('');
                     attachmentsContainer.style.display = 'flex';
                 } else {
                    attachmentsContainer.innerHTML = '<p class="no-attachments">No attachments available.</p>';
                    attachmentsContainer.style.display = 'block';
                }
            }
            
            // Populate timeline
            const timelineEl = document.getElementById('detailTimeline');
            if (timelineEl) {
                // Filter violations for this student
                let studentHistory = violations.filter(v => v.studentId === violation.studentId);
                
                // Deduplicate history for timeline
                const seenHistory = new Set();
                studentHistory = studentHistory.filter(v => {
                    // Create a unique key based on visible content (same as above)
                    const key = `${v.violationTypeLabel}|${v.violationLevelLabel}|${v.violationDate}|${v.violationTime}|${v.location}|${v.reportedBy}`;
                    if (seenHistory.has(key)) {
                        return false;
                    }
                    seenHistory.add(key);
                    return true;
                });
                
                // Sort by date (newest first)
                studentHistory.sort((a, b) => {
                     const dateA = new Date((a.dateReported || a.date) + ' ' + (a.violationTime || '00:00'));
                     const dateB = new Date((b.dateReported || b.date) + ' ' + (b.violationTime || '00:00'));
                     return dateB - dateA;
                });

                if (studentHistory.length > 0) {
                    timelineEl.innerHTML = studentHistory.map(v => {
                        // Highlight the current violation being viewed
                        // Since we deduplicated, we need to check if the current violation MATCHES one of the history items content-wise
                        // instead of just ID check, because the specific ID we are viewing might have been filtered out as a duplicate
                        // but its "content equivalent" is still there.
                        
                        const viewingKey = `${violation.violationTypeLabel}|${violation.violationLevelLabel}|${violation.violationDate}|${violation.violationTime}|${violation.location}|${violation.reportedBy}`;
                        const currentKey = `${v.violationTypeLabel}|${v.violationLevelLabel}|${v.violationDate}|${v.violationTime}|${v.location}|${v.reportedBy}`;
                        
                        const isCurrent = viewingKey === currentKey;
                        const activeClass = isCurrent ? 'current-viewing' : '';
                        const dateStr = formatDate(v.dateReported || v.date);
                        const timeStr = formatTime(v.violationTime);
                        
                        return `
                        <div class="timeline-item ${activeClass}">
                            <div class="timeline-marker"></div>
                            <div class="timeline-content">
                                <span class="timeline-date">${dateStr} ${timeStr ? '• ' + timeStr : ''}</span>
                                <span class="timeline-title">
                                    ${v.violationLevelLabel || v.level || 'Level'} - ${v.violationTypeLabel || v.type || 'Type'}
                                    ${isCurrent ? '<span style="font-size: 10px; background: #eee; padding: 2px 6px; border-radius: 4px; margin-left: 5px;">Current</span>' : ''}
                                </span>
                                <span class="timeline-desc">
                                    Reported at ${v.locationLabel || v.location} 
                                    ${(() => {
                                        let itemStatus = v.status;
                                        const levelLabel = (v.violationLevelLabel || '').toLowerCase();
                                        if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                                            itemStatus = 'disciplinary';
                                        }
                                        
                                        if (itemStatus === 'resolved') {
                                            return '<span style="color: green; font-weight: bold;">(Resolved)</span>';
                                        } else if (itemStatus === 'disciplinary') {
                                            return '<span style="color: #e74c3c; font-weight: bold;">(Disciplinary)</span>';
                                        }
                                        return '';
                                    })()}
                                </span>
                            </div>
                        </div>
                    `}).join('');
                } else {
                    timelineEl.innerHTML = '<p style="color: #6c757d; font-size: 14px; text-align: center; padding: 10px;">No history available.</p>';
                }
            }
            
            detailsModal.dataset.viewingId = violationId;
            detailsModal.classList.add('active');
            document.body.style.overflow = 'hidden';

            // Update action buttons visibility based on status
            const detailResolveBtn = document.getElementById('detailResolveBtn');
            const detailEscalateBtn = document.getElementById('detailEscalateBtn');
            
            if (detailResolveBtn) {
                let currentStatus = violation.status;
                const levelLabel = (violation.violationLevelLabel || '').toLowerCase();
                
                // Treat Warning 3 as disciplinary for button visibility
                if (violation.status !== 'resolved' && (levelLabel.includes('warning 3') || levelLabel.includes('3rd'))) {
                    currentStatus = 'disciplinary';
                }

                if (currentStatus === 'disciplinary') {
                    detailResolveBtn.style.display = 'inline-flex';
                } else {
                    detailResolveBtn.style.display = 'none';
                }
            }

            if (detailEscalateBtn) {
                if (violation.status === 'disciplinary' || violation.status === 'resolved') {
                    detailEscalateBtn.style.display = 'none';
                } else {
                    detailEscalateBtn.style.display = 'inline-flex';
                }
            }
        }

        function closeRecordModal() {
            console.log('Closing record modal');
            recordModal.classList.remove('active');
            document.body.style.overflow = 'auto';
            
            // Reset form if exists
            const form = document.getElementById('ViolationRecordForm');
            if (form) form.reset();
            
            // Hide student card
            const studentCard = document.getElementById('selectedStudentCard');
            if (studentCard) studentCard.style.display = 'none';

            // Explicitly clear student info on close as well
            if (document.getElementById('modalStudentName')) {
                document.getElementById('modalStudentId').textContent = '';
                document.getElementById('modalStudentName').textContent = '';
                const img = document.getElementById('modalStudentImage');
                if (img) img.src = '';
                document.getElementById('modalStudentDept').textContent = '';
                document.getElementById('modalStudentSection').textContent = '';
                document.getElementById('modalStudentYearlevel').textContent = '';
                document.getElementById('modalStudentContact').textContent = '';
            }
            
            delete recordModal.dataset.editingId;
        }

        function closeDetailsModal() {
            if (!detailsModal) return;
            detailsModal.classList.remove('active');
            document.body.style.overflow = 'auto';
            delete detailsModal.dataset.viewingId;
        }

        // ========== EVENT HANDLERS ==========
        
        function handleTableClick(e) {
            const viewBtn = e.target.closest('.Violations-action-btn.view');
            const editBtn = e.target.closest('.Violations-action-btn.edit');
            const resolveBtn = e.target.closest('.Violations-action-btn.resolve');
            const reopenBtn = e.target.closest('.Violations-action-btn.reopen');
            const entranceBtn = e.target.closest('.Violations-action-btn.entrance');

            if (viewBtn) {
                const id = viewBtn.dataset.id;
                console.log('👁 View button clicked. ID:', id);
                if (!id || id === 'undefined' || id === 'null') {
                    console.error('❌ Invalid violation ID:', id);
                    return;
                }
                openDetailsModal(id);
            }

            if (editBtn) {
                const id = editBtn.dataset.id;
                openRecordModal(id);
            }

            if (entranceBtn) {
                const id = entranceBtn.dataset.id;
                const violation = violations.find(v => v.id == id);
                if (violation) {
                    printEntranceSlip(violation);
                }
            }

            if (resolveBtn) {
                const id = resolveBtn.dataset.id;
                const violation = violations.find(v => v.id == id);
                
                if (violation) {
                    // Check status - logic must match renderViolations
                    let currentStatus = violation.status;
                    const levelLabel = (violation.violationLevelLabel || '').toLowerCase();
                    if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                        currentStatus = 'disciplinary';
                    }

                    if (currentStatus !== 'disciplinary') {
                        alert('Only disciplinary violations can be marked as resolved.');
                        return;
                    }

                    if (confirm(`Mark violation ${violation.caseId} as resolved?`)) {
                        updateViolation(id, { status: 'resolved' })
                            .then(() => {
                                alert('Violation marked as resolved!');
                            })
                            .catch(error => {
                                console.error('Error resolving violation:', error);
                                alert('Failed to resolve violation. Please try again.');
                            });
                    }
                }
            }

            if (reopenBtn) {
                const id = reopenBtn.dataset.id;
                const violation = violations.find(v => v.id == id);
                if (violation && confirm(`Reopen violation ${violation.caseId}?`)) {
                    updateViolation(id, { status: 'warning' })
                        .then(() => {
                            alert('Violation reopened!');
                        })
                        .catch(error => {
                            console.error('Error reopening violation:', error);
                            alert('Failed to reopen violation. Please try again.');
                        });
                }
            }
        }

        async function handleStudentSearch() {
            const searchTerm = studentSearchInput.value.toLowerCase().trim();
            if (!searchTerm) {
                showNotification('Please enter a student ID or name to search.', 'warning');
                return;
            }

            // Sync latest data before searching to ensure badges and history are accurate
            // This ensures that if a violation was just recorded (even from another device),
            // the history check will be up to date.
            showLoadingOverlay('Syncing records...');
            try {
                await loadViolations(false);
            } catch (error) {
                console.error('Error syncing data during search:', error);
            } finally {
                hideLoadingOverlay();
            }
            
            console.log('🔍 Searching for student:', searchTerm);
            console.log('📊 Current students array length:', students.length);
            console.log('📋 Students API available?', typeof fetch !== 'undefined');

            // Ensure students data is loaded
            if (students.length === 0) {
                console.log('Students array is empty, loading students...');
                await loadStudents(true);
                console.log('Students loaded, new length:', students.length);
            }

            // Debug: Log first few students to check data structure
            if (students.length > 0) {
                console.log('Sample student data:', students.slice(0, 3));
            }

            // More robust search logic
            const student = students.find(s => {
                if (!s || !s.studentId) return false;

                const studentId = s.studentId.toLowerCase();
                const searchLower = searchTerm.toLowerCase();
                const fullName = `${s.firstName || ''} ${s.lastName || ''}`.toLowerCase().trim();

                // Exact match first
                if (studentId === searchLower) return true;

                // Student ID contains search term
                if (studentId.includes(searchLower)) return true;

                // Name contains search term
                if (fullName.includes(searchLower)) return true;

                // Search term contains student ID
                if (searchLower.includes(studentId)) return true;

                return false;
            });

            console.log('Search result:', student);
            
            if (student) {
                console.log('✅ Found student:', student);
                const fullName = `${student.firstName} ${student.middleName ? student.middleName + ' ' : ''}${student.lastName}`;
                const imageUrl = getImageUrl(student.avatar, fullName);
                console.log('📷 Student image URL:', imageUrl);
                
                document.getElementById('modalStudentId').textContent = student.studentId;
                document.getElementById('modalStudentName').textContent = fullName;
                const img = document.getElementById('modalStudentImage');
                img.src = imageUrl;
                img.onerror = function() {
                    this.onerror = null; // prevent infinite loop
                    this.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(fullName)}&background=ffd700&color=333&size=80`;
                };
                document.getElementById('modalStudentDept').textContent = student.department || 'N/A';
                document.getElementById('modalStudentSection').textContent = student.section || 'N/A';
                document.getElementById('modalStudentYearlevel').textContent = student.yearlevel || 'N/A';
                document.getElementById('modalStudentContact').textContent = student.contact || student.email || 'N/A';

                if (selectedStudentCard) {
                    selectedStudentCard.style.display = 'flex';
                }

                // Show entrance slip button when student is found
                if (modalEntranceBtn) {
                    modalEntranceBtn.style.display = 'flex';
                }

                showNotification(`Student found: ${student.firstName} ${student.lastName} (${student.studentId})`, 'success');

                // Check for existing violations
                checkStudentViolationHistory();
                updateViolationTypeBadges(student.studentId);
            } else {
                console.log('❌ No student found for search term:', searchTerm);
                console.log('Available students:', students.length);

                if (students.length === 0) {
                    showNotification('No student data loaded. Click the refresh button (🔄) to reload student data.', 'warning', 6000);
                } else {
                    showNotification(`Student "${searchTerm}" not found. Available students: ${students.slice(0, 5).map(s => s.studentId).join(', ')}...`, 'warning', 8000);
                }

                // Clear any previous selection
                if (selectedStudentCard) {
                    selectedStudentCard.style.display = 'none';
                }

                // Hide entrance slip button when student is not found
                if (modalEntranceBtn) {
                    modalEntranceBtn.style.display = 'none';
                }
            }
        }

        // ========== EVENT LISTENERS ==========
        
        // 1. OPEN MODAL WHEN "RECORD VIOLATION" BUTTON IS CLICKED
        if (btnAddViolation) {
            btnAddViolation.addEventListener('click', () => openRecordModal());
            console.log('✅ Added click event to btnAddViolations');
        }

        // 1.1 OPEN EXPORT MODAL
        if (exportBtn) {
            exportBtn.addEventListener('click', () => {
                if (exportModal) {
                    exportModal.classList.add('active');
                    document.body.style.overflow = 'hidden';
                }
            });
        }

        if (closeExportBtn) {
            closeExportBtn.addEventListener('click', () => {
                if (exportModal) {
                    exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                }
            });
        }

        if (exportModalOverlay) {
            exportModalOverlay.addEventListener('click', () => {
                if (exportModal) {
                    exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                }
            });
        }

        // Export format buttons
        if (exportPDFBtn) {
            exportPDFBtn.addEventListener('click', async () => {
                await downloadViolationsPDF();
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            });
        }

        if (exportExcelBtn) {
            exportExcelBtn.addEventListener('click', () => {
                downloadViolationsExcel();
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            });
        }

        if (exportWordBtn) {
            exportWordBtn.addEventListener('click', async () => {
                await downloadViolationsWord();
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            });
        }

        // 2. OPEN MODAL WHEN "RECORD FIRST VIOLATION" BUTTON IS CLICKED
        if (btnRecordFirst) {
            btnRecordFirst.addEventListener('click', () => openRecordModal());
            console.log('✅ Added click event to btnRecordFirstViolation');
        }

        // 3. CLOSE MODAL BUTTONS
        if (closeRecordBtn) {
            closeRecordBtn.addEventListener('click', closeRecordModal);
            console.log('✅ Added click event to closeRecordBtn');
        }

        if (cancelRecordBtn) {
            cancelRecordBtn.addEventListener('click', closeRecordModal);
            console.log('✅ Added click event to cancelRecordBtn');
        }

        if (recordOverlay) {
            recordOverlay.addEventListener('click', closeRecordModal);
            console.log('✅ Added click event to recordOverlay');
        }

        if (closeDetailsBtn) closeDetailsBtn.addEventListener('click', closeDetailsModal);
        if (detailsOverlay) detailsOverlay.addEventListener('click', closeDetailsModal);

        // Detail modal action buttons
        const detailEditBtn = document.getElementById('detailEditBtn');
        const detailResolveBtn = document.getElementById('detailResolveBtn');
        const detailEscalateBtn = document.getElementById('detailEscalateBtn');
        const detailPrintBtn = document.getElementById('detailPrintBtn');
        const detailEntranceBtn = document.getElementById('detailEntranceBtn');

        if (detailEditBtn) {
            detailEditBtn.addEventListener('click', function() {
                const violationId = detailsModal.dataset.viewingId;
                if (violationId) {
                    closeDetailsModal();
                    openRecordModal(parseInt(violationId));
                }
            });
        }

        if (detailResolveBtn) {
            detailResolveBtn.addEventListener('click', async function() {
                const violationId = detailsModal.dataset.viewingId;
                if (!violationId) {
                    showNotification('No violation selected', 'error');
                    return;
                }

                const violation = violations.find(v => v.id == violationId);
                if (!violation) {
                    showNotification('Violation not found', 'error');
                    return;
                }

                if (violation.status === 'resolved') {
                    showNotification('This violation is already resolved', 'warning');
                    return;
                }

                // Check if disciplinary
                let currentStatus = violation.status;
                const levelLabel = (violation.violationLevelLabel || '').toLowerCase();
                if (levelLabel.includes('warning 3') || levelLabel.includes('3rd')) {
                    currentStatus = 'disciplinary';
                }

                if (currentStatus !== 'disciplinary') {
                    showNotification('Only disciplinary violations can be marked as resolved.', 'warning');
                    return;
                }

                if (confirm(`Mark violation ${violation.caseId} as resolved?`)) {
                    try {
                        await updateViolation(violationId, { status: 'resolved' });
                        showNotification('Violation marked as resolved!', 'success');
                        closeDetailsModal();
                    } catch (error) {
                        console.error('Error resolving violation:', error);
                        showNotification('Failed to resolve violation. Please try again.', 'error');
                    }
                }
            });
        }

        if (detailEscalateBtn) {
            detailEscalateBtn.addEventListener('click', async function() {
                const violationId = detailsModal.dataset.viewingId;
                if (!violationId) {
                    showNotification('No violation selected', 'error');
                    return;
                }

                const violation = violations.find(v => v.id == violationId);
                if (!violation) {
                    showNotification('Violation not found', 'error');
                    return;
                }

                if (confirm(`Escalate violation ${violation.caseId} to disciplinary action?`)) {
                    try {
                        await updateViolation(violationId, { status: 'disciplinary' });
                        showNotification('Violation escalated to disciplinary!', 'success');
                        closeDetailsModal();
                    } catch (error) {
                        console.error('Error escalating violation:', error);
                        showNotification('Failed to escalate violation. Please try again.', 'error');
                    }
                }
            });
        }

        if (detailPrintBtn) {
            detailPrintBtn.addEventListener('click', function() {
                const violationId = detailsModal.dataset.viewingId;
                if (!violationId) {
                    showNotification('No violation selected', 'error');
                    return;
                }

                const violation = violations.find(v => v.id == violationId);
                if (violation) {
                    // Print violation details
                    const printContent = `
                        <html>
                            <head>
                                <title>Violation Report - ${violation.caseId}</title>
                                <style>
                                    body { font-family: 'Segoe UI', sans-serif; margin: 40px; }
                                    h1 { color: #333; margin-bottom: 20px; }
                                    .report-section { margin-bottom: 30px; }
                                    .report-label { font-weight: 600; color: #666; }
                                    .report-value { margin-left: 10px; }
                                    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                                    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
                                    th { background-color: #f8f9fa; font-weight: 600; }
                                </style>
                            </head>
                            <body>
                                <h1>Violation Report</h1>
                                <div class="report-section">
                                    <div><span class="report-label">Case ID:</span> <span class="report-value">${violation.caseId}</span></div>
                                    <div><span class="report-label">Student ID:</span> <span class="report-value">${violation.studentId}</span></div>
                                    <div><span class="report-label">Student Name:</span> <span class="report-value">${violation.studentName}</span></div>
                                    <div><span class="report-label">Section:</span> <span class="report-value">${violation.section}</span></div>
                                    <div><span class="report-label">Year Level:</span> <span class="report-value">${violation.studentYearlevel || 'N/A'}</span></div>
                                    <div><span class="report-label">Violation Type:</span> <span class="report-value">${violation.violationTypeLabel}</span></div>
                                    <div><span class="report-label">Level:</span> <span class="report-value">${violation.violationLevelLabel}</span></div>
                                    <div><span class="report-label">Date & Time:</span> <span class="report-value">${violation.dateTime}</span></div>
                                    <div><span class="report-label">Location:</span> <span class="report-value">${violation.locationLabel}</span></div>
                                    <div><span class="report-label">Reported By:</span> <span class="report-value">${violation.reportedBy}</span></div>
                                    <div><span class="report-label">Status:</span> <span class="report-value">${violation.statusLabel}</span></div>
                                    <div><span class="report-label">Notes:</span> <span class="report-value">${violation.notes || 'N/A'}</span></div>
                                </div>
                                <div style="margin-top: 40px; color: #666; font-size: 12px;">
                                    Generated on: ${new Date().toLocaleString()}
                                </div>
                            </body>
                        </html>
                    `;
                    const printWindow = window.open('', '_blank');
                    printWindow.document.write(printContent);
                    printWindow.document.close();
                    printWindow.print();
                }
            });
        }

        if (modalEntranceBtn) {
            modalEntranceBtn.addEventListener('click', function() {
                const editId = recordModal.dataset.editingId;
                
                if (editId) {
                    // Edit mode: Use existing violation data
                    const violation = violations.find(v => v.id === parseInt(editId));
                    if (violation) {
                        printEntranceSlip(violation);
                    }
                } else {
                    // New Record mode: Gather data from form fields
                    const studentId = document.getElementById('modalStudentId').textContent;
                    const studentName = document.getElementById('modalStudentName').textContent;
                    const studentDept = document.getElementById('modalStudentDept').textContent;
                    const studentSection = document.getElementById('modalStudentSection').textContent;
                    
                    const violationTypeRadio = document.querySelector('input[name="violationType"]:checked');
                    const violationLevelRadio = document.querySelector('input[name="violationLevel"]:checked');
                    
                    if (!studentId || !studentName) {
                        showNotification('Please search and select a student first.', 'warning');
                        return;
                    }
                    
                    // Get labels for type and level
                    let violationTypeLabel = 'N/A';
                    if (violationTypeRadio) {
                        const label = document.querySelector(`label[for="${violationTypeRadio.id}"] span`);
                        if (label) violationTypeLabel = label.textContent.trim();
                    }
                    
                    let violationLevelLabel = 'N/A';
                    if (violationLevelRadio) {
                        const label = document.querySelector(`label[for="${violationLevelRadio.id}"] .level-title`);
                        if (label) violationLevelLabel = label.textContent.trim();
                    }
                    
                    // Create temporary violation object for printing
                    const tempViolation = {
                        caseId: generateCaseId() + ' (PENDING)',
                        studentId: studentId,
                        studentName: studentName,
                        department: studentDept,
                        section: studentSection,
                        violationTypeLabel: violationTypeLabel,
                        violationLevelLabel: violationLevelLabel,
                        dateTime: new Date().toLocaleString()
                    };
                    
                    printEntranceSlip(tempViolation);
                }
            });
        }

        function printEntranceSlip(violation) {
            console.log('🖨️ Requesting Entrance Slip for:', violation.studentName);
            
            // Check if violation has ID
            if (!violation.caseId || violation.caseId.includes('PENDING')) {
                showNotification('Cannot print slip for unsaved violation. Please save first.', 'warning');
                return;
            }

            // FORCE SERVER-SIDE GENERATION (To avoid JS cache and use the PHP fixes)
            const studentId = violation.studentId || '';
            const violationId = violation.id || '';
            window.location.href = API_BASE + 'violations.php?action=generate_slip&violation_id=' + violationId;
        }

        async function generateEntranceSlipClientSide(violation) {
            try {
                showLoadingOverlay('Generating Entrance Slip...');
                
                // 1. Fetch Template
                const response = await fetch(API_BASE + 'violations.php?action=get_slip_template');
                if (!response.ok) throw new Error('Failed to fetch template file');
                const blob = await response.blob();
                
                // 1.1 Fetch Violation History for this Student
                let monthlyViolations = {
                    'Improper Uniform': [],
                    'Improper Foot Wear': [],
                    'No ID': []
                };

                try {
                    const histResponse = await fetch(API_BASE + 'violations.php?student_id=' + (violation.studentId || ''));
                    if (histResponse.ok) {
                        const histData = await histResponse.json();
                        const history = histData.data || histData.violations || [];
                        
                        // Filter for current month/year of the VIOLATION DATE
                        // If violation.dateTime is "2/22/2026, 10:00:00 AM", we parse it.
                        // Ideally we use the raw dateReported if available, or current date
                        const vDate = new Date(); // Default to now
                        const currentMonth = vDate.getMonth();
                        const currentYear = vDate.getFullYear();

                        history.forEach(v => {
                            // Parse dateReported: "02/14/2026" or "2026-02-14"
                            const dStr = v.dateReported || v.violation_date;
                            if (!dStr) return;
                            
                            const vTime = new Date(dStr);
                            if (isNaN(vTime.getTime())) return;

                            if (vTime.getMonth() === currentMonth && vTime.getFullYear() === currentYear) {
                                const type = (v.violationTypeLabel || '').toLowerCase();
                                if (type.includes('uniform')) monthlyViolations['Improper Uniform'].push(v);
                                else if (type.includes('foot') || type.includes('shoe')) monthlyViolations['Improper Foot Wear'].push(v);
                                else if (type.includes('id')) monthlyViolations['No ID'].push(v);
                            }
                        });

                        // Sort by date/time
                        const sortFn = (a, b) => {
                            const da = new Date((a.dateReported || '') + ' ' + (a.violationTime || ''));
                            const db = new Date((b.dateReported || '') + ' ' + (b.violationTime || ''));
                            return da - db;
                        };
                        monthlyViolations['Improper Uniform'].sort(sortFn);
                        monthlyViolations['Improper Foot Wear'].sort(sortFn);
                        monthlyViolations['No ID'].sort(sortFn);
                    }
                } catch (e) {
                    console.error('Error fetching history:', e);
                }

                // 2. Load Zip
                const zip = new PizZip(await blob.arrayBuffer());
                
                // 3. Get Document XML
                let xml = zip.file("word/document.xml").asText();
                
                // 4. Prepare Data
                const studentName = violation.studentName || 'N/A';
                const studentId = violation.studentId || 'N/A';
                const section = violation.section || violation.studentSection || '';
                const yearLevel = violation.studentYearlevel || '';
                const courseYear = `${section} - ${yearLevel}`;
                
                const vType = (violation.violationTypeLabel || '').toLowerCase();
                const vLevel = (violation.violationLevelLabel || '').toLowerCase();
                
                const checkUniform = vType.includes('uniform') ? '✔' : ' ';
                const checkFootwear = (vType.includes('foot') || vType.includes('shoe')) ? '✔' : ' ';
                const checkID = (vType.includes('id') || vType.includes('identification')) ? '✔' : ' ';
                
                const check1st = vLevel.includes('1st') ? '✔' : ' ';
                const check2nd = vLevel.includes('2nd') ? '✔' : ' ';
                const check3rd = vLevel.includes('3rd') ? '✔' : ' ';

                // 5. Perform Replacements (XML Injection)
                
                // 5. Replace Headers (Simplified & Fixed)
                // We target ONLY the underscores after the labels to avoid ruining the template
                const headerFields = [
                    { label: 'ID Number', value: studentId },
                    { label: 'Course and Year', value: courseYear },
                    { label: 'Name', value: studentName },
                    { label: 'ID Number', value: studentId },
                    { label: 'Course and Year', value: courseYear },
                    { label: 'Name', value: studentName },
                ];

                // Font size: sz=18 is 9pt (Standard small)
                // Black color, Century Gothic
                const baseProps = '<w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:cs="Century Gothic"/><w:color w:val="000000"/><w:b w:val="0"/><w:bCs w:val="0"/><w:sz w:val="18"/><w:szCs w:val="18"/><w:u w:val="single"/><w:vertAlign w:val="baseline"/></w:rPr>';

                headerFields.forEach(rep => {
                    // This regex finds the label + colon + optional tags, then captures the underscores in a group
                    const labelRegex = rep.label.split('').map(c => escapeRegex(c) + '(?:<[^>]+>)*').join('');
                    const pattern = new RegExp('(' + labelRegex + '(?:\\s|<[^>]+>)*:(?:\\s|<[^>]+>)*)(_+)', 's');
                    
                    // Added multiple spaces to ensure separation between fields
                    const replacementXml = `</w:t></w:r><w:r>${baseProps}<w:t>  ${rep.value}     </w:t></w:r><w:r><w:t>`;
                    
                    // Replace only the captured underscores (group 2), keeping the label (group 1) intact
                    xml = xml.replace(pattern, (match, g1, g2) => g1 + replacementXml);
                });

                // Helper for escaping regex
                function escapeRegex(string) {
                    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                }

                // Checkmarks - ADDED TO LABELS
                xml = xml.replace(/Improper Uniform/g, `Improper Uniform ${checkUniform}`);
                xml = xml.replace(/Improper Foot Wear/g, `Improper Foot Wear ${checkFootwear}`);
                xml = xml.replace(/No ID/g, `No ID ${checkID}`);
                
                // These replace the HEADER text if it matches exactly
                xml = xml.replace(/1st Offense/g, `1st Offense ${check1st}`);
                xml = xml.replace(/2nd Offense/g, `2nd Offense ${check2nd}`);
                xml = xml.replace(/3rd Offense/g, `3rd Offense ${check3rd}`);

                // 5.1 Inject Table Data (History)
                xml = injectViolationsIntoTable(xml, 'Improper Uniform', monthlyViolations['Improper Uniform']);
                xml = injectViolationsIntoTable(xml, 'Improper Foot Wear', monthlyViolations['Improper Foot Wear']);
                xml = injectViolationsIntoTable(xml, 'No ID', monthlyViolations['No ID']);

                // 6. Update Zip
                zip.file("word/document.xml", xml);
                
                // 7. Generate Blob
                const out = zip.generate({
                    type: "blob",
                    mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                });
                
                // 8. Download
                saveAs(out, `Entrance_Slip_${studentId}.docx`);
                
                showNotification('Entrance Slip downloaded successfully!', 'success');
                
            } catch (error) {
                console.error('Client-side generation error:', error);
                showNotification('Failed to generate slip: ' + error.message, 'error');
            } finally {
                hideLoadingOverlay();
            }
        }

        // Helper to inject violation dates into the slip table (Ported from PHP)
        function injectViolationsIntoTable(xml, anchor, violations) {
            const pos = xml.indexOf(anchor);
            if (pos === -1) return xml;

            // Find the end of the cell containing the anchor
            let endAnchorCell = xml.indexOf('</w:tc>', pos);
            if (endAnchorCell === -1) return xml;
            endAnchorCell += 7; // Length of </w:tc>

            let newXml = xml.substring(0, endAnchorCell);
            let offset = endAnchorCell;

            // We expect 5 columns after the violation name: Permitted 1, Permitted 2, 1st, 2nd, 3rd
            for (let i = 0; i < 5; i++) {
                // Find start of next cell
                const startTc = xml.indexOf('<w:tc', offset);
                if (startTc === -1) break;

                // Preserve content between previous cell end and this cell start
                const betweenContent = xml.substring(offset, startTc);
                newXml += betweenContent;

                // Find end of this cell
                let endTc = xml.indexOf('</w:tc>', startTc);
                if (endTc === -1) break;
                endTc += 7;

                // Get cell content
                let cellContent = xml.substring(startTc, endTc);

                // Map violations: index 0 -> Col 1, index 1 -> Col 2, etc.
                if (violations[i]) {
                    const v = violations[i];
                    // Format: 02/14/2026- 8:30 AM
                    const dStrRaw = v.dateReported || v.violation_date;
                    const tStrRaw = v.violationTime || '';
                    
                    const d = new Date(dStrRaw + ' ' + tStrRaw);
                    let dateStr = dStrRaw;
                    if (!isNaN(d.getTime())) {
                        dateStr = d.toLocaleDateString('en-US') + '- ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
                    }
                    
                    // Inject into <w:p>
                    // Use slightly smaller font sz=16 (8pt)
                    const runXml = `<w:r><w:rPr><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr><w:t>${dateStr}</w:t></w:r>`;
                    
                    if (cellContent.includes('</w:p>')) {
                        cellContent = cellContent.replace('</w:p>', runXml + '</w:p>');
                    } else {
                        // Fallback
                        cellContent = cellContent.substring(0, cellContent.length - 7) + '<w:p>' + runXml + '</w:p></w:tc>';
                    }
                }

                newXml += cellContent;
                offset = endTc;
            }

            // Append rest of XML
            newXml += xml.substring(offset);
            
            return newXml;
        }

        // 4. ESCAPE KEY TO CLOSE MODAL
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (recordModal && recordModal.classList.contains('active')) {
                    closeRecordModal();
                }
                if (detailsModal && detailsModal.classList.contains('active')) {
                    closeDetailsModal();
                }
                // Also close student details panel
                const studentPanel = document.getElementById('studentDetailsPanel');
                if (studentPanel && studentPanel.style.display !== 'none') {
                    hideStudentDetails();
                }
            }
        });

        // 5. TABLE EVENT LISTENERS
        if (tableBody) {
            tableBody.addEventListener('click', handleTableClick);
        }

        // ========== PROFESSIONAL FORM VALIDATION & SUBMISSION ==========

        // Form validation state
        let formValidationState = {
            isValid: false,
            errors: {},
            touched: {}
        };

        // Professional form validation - REMOVED ALL VALIDATION
        function validateFormField(fieldName, value) {
            const errors = [];

            // All validations removed as requested
            // Return empty errors array for all fields

            return errors;
        }

        function showFieldError(fieldName, errors) {
            const field = document.getElementById(fieldName) ||
                         document.querySelector(`[name="${fieldName}"]`) ||
                         document.querySelector(`input[name="${fieldName}"]:checked`);

            if (!field) return;

            // Remove existing error
            const existingError = field.parentElement.querySelector('.field-error');
            if (existingError) existingError.remove();

            // Add error styling
            field.classList.add('field-error');

            if (errors.length > 0) {
                const errorDiv = document.createElement('div');
                errorDiv.className = 'field-error';
                errorDiv.textContent = errors[0]; // Show first error
                field.parentElement.appendChild(errorDiv);
            } else {
                field.classList.remove('field-error');
            }
        }

        function clearFieldError(fieldName) {
            const field = document.getElementById(fieldName) ||
                         document.querySelector(`[name="${fieldName}"]`) ||
                         document.querySelector(`input[name="${fieldName}"]:checked`);

            if (field) {
                field.classList.remove('field-error');
                const existingError = field.parentElement.querySelector('.field-error');
                if (existingError) existingError.remove();
            }
        }

        function validateEntireForm() {
            // All validation removed - form is always valid
            const isValid = true;
            const errors = {};
            const totalFields = 8;
            const completedFields = totalFields; // Always 100% complete

            formValidationState.isValid = isValid;
            formValidationState.errors = errors;

            // Update submit button state - always enabled
            const submitBtn = document.querySelector('#ViolationRecordForm .Violations-btn-primary');
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Record Violation';
            }

            // Update progress bar - always 100%
            updateFormProgress(completedFields, totalFields);

            // Debug logging
            console.log('Form validation result: ALL VALIDATION REMOVED - Always valid');

            return isValid;
        }

        function updateFormProgress(completed, total) {
            const progressBar = document.getElementById('violationFormProgress');
            if (progressBar) {
                const percentage = (completed / total) * 100;
                progressBar.style.width = percentage + '%';

                // Change color based on completion
                if (percentage === 100) {
                    progressBar.style.background = 'linear-gradient(90deg, var(--success) 0%, var(--success) 100%)';
                } else if (percentage >= 75) {
                    progressBar.style.background = 'linear-gradient(90deg, var(--primary) 0%, var(--primary) 100%)';
                } else if (percentage >= 50) {
                    progressBar.style.background = 'linear-gradient(90deg, #ffc107 0%, #ffc107 100%)';
                } else {
                    progressBar.style.background = 'linear-gradient(90deg, #dc3545 0%, #dc3545 100%)';
                }
            }
        }

        // Real-time validation
        function setupRealTimeValidation() {
            // Student search validation
            const studentSearch = document.getElementById('studentSearch');
            if (studentSearch) {
                studentSearch.addEventListener('blur', () => {
                    const studentId = document.getElementById('modalStudentId').textContent;
                    const errors = validateFormField('studentSearch', studentId || '');
                    showFieldError('studentSearch', errors);
                    validateEntireForm();
                });
            }

            // Radio button validation
            ['violationType', 'violationLevel'].forEach(fieldName => {
                const radios = document.querySelectorAll(`input[name="${fieldName}"]`);
                radios.forEach(radio => {
                    radio.addEventListener('change', () => {
                        clearFieldError(fieldName);
                        validateEntireForm();

                        // Auto-populate notes based on selection
                        if (fieldName === 'violationType' && radio.checked) {
                            populateSuggestedNotes(radio.value);
                        }
                    });
                });
            });

            // Text input validation
            ['violationDate', 'violationTime', 'reportedBy'].forEach(fieldId => {
                const field = document.getElementById(fieldId);
                if (field) {
                    field.addEventListener('blur', () => {
                        const errors = validateFormField(fieldId, field.value);
                        showFieldError(fieldId, errors);
                        validateEntireForm();
                    });

                    field.addEventListener('input', () => {
                        // Always validate on input for these critical fields
                        const errors = validateFormField(fieldId, field.value);
                        showFieldError(fieldId, errors);
                        validateEntireForm();
                    });

                    field.addEventListener('change', () => {
                        // Also validate on change events (important for date/time pickers)
                        const errors = validateFormField(fieldId, field.value);
                        showFieldError(fieldId, errors);
                        validateEntireForm();
                    });
                }
            });

            // Select validation
            const locationSelect = document.getElementById('violationLocation');
            if (locationSelect) {
                locationSelect.addEventListener('change', () => {
                    clearFieldError('location');
                    validateEntireForm();
                });
            }

            // Notes validation
            const notesField = document.getElementById('violationNotes');
            if (notesField) {
                notesField.addEventListener('input', () => {
                    const errors = validateFormField('violationNotes', notesField.value);
                    showFieldError('violationNotes', errors);
                    validateEntireForm();

                    // Character counter
                    updateNotesCounter(notesField.value.length);
                });
            }
        }

        function updateNotesCounter(length) {
            let counter = document.getElementById('notesCounter');
            if (!counter) {
                const notesField = document.getElementById('violationNotes');
                if (notesField) {
                    counter = document.createElement('div');
                    counter.id = 'notesCounter';
                    counter.className = 'notes-counter';
                    notesField.parentElement.appendChild(counter);
                }
            }

            if (counter) {
                counter.textContent = `${length}/500 characters`;
                counter.className = `notes-counter ${length > 450 ? 'warning' : ''} ${length > 500 ? 'error' : ''}`;
            }
        }

        // --- Attachment Preview Functions ---
        function updateAttachmentPreviews() {
            const container = document.getElementById('attachmentPreviews');
            if (!container) return;

            container.innerHTML = '';
            
            if (selectedFiles.length === 0) {
                // Keep the container visible if needed by layout, or let CSS handle it
                return;
            }

            selectedFiles.forEach((file, index) => {
                const previewItem = document.createElement('div');
                previewItem.className = 'preview-item';
                
                // Format file size
                const fileSize = file.size < 1024 * 1024 
                    ? (file.size / 1024).toFixed(1) + ' KB' 
                    : (file.size / (1024 * 1024)).toFixed(1) + ' MB';

                // If it's an image, show a thumbnail
                if (file.type.startsWith('image/')) {
                    const reader = new FileReader();
                    reader.onload = function(e) {
                        previewItem.innerHTML = `
                            <img src="${e.target.result}" alt="preview">
                            <div class="file-size">${fileSize}</div>
                            <button type="button" class="remove-btn" data-index="${index}" title="Remove file">
                                <i class='bx bx-x'></i>
                            </button>
                        `;
                    };
                    reader.readAsDataURL(file);
                } else {
                    // Show file icon for other types
                    previewItem.innerHTML = `
                        <div class="file-icon-preview">
                            <i class='bx bxs-file-blank' style="font-size: 24px; color: #ffcc00;"></i>
                            <div class="file-size">${fileSize}</div>
                        </div>
                        <button type="button" class="remove-btn" data-index="${index}" title="Remove file">
                            <i class='bx bx-x'></i>
                        </button>
                    `;
                }
                
                container.appendChild(previewItem);
            });

            // Event delegation for removal to handle async FileReader renders
            container.onclick = function(e) {
                const removeBtn = e.target.closest('.remove-btn');
                if (!removeBtn) return;

                e.preventDefault();
                e.stopPropagation();
                
                const idx = parseInt(removeBtn.dataset.index);
                const fileName = selectedFiles[idx]?.name || 'file';
                
                console.log(`🗑️ Removing attachment: ${fileName} at index ${idx}`);
                
                const item = removeBtn.closest('.preview-item');
                if (item) {
                    item.style.transform = 'scale(0.8)';
                    item.style.opacity = '0';
                    item.style.transition = 'all 0.2s ease';
                }
                
                setTimeout(() => {
                    selectedFiles.splice(idx, 1);
                    updateAttachmentPreviews();
                }, 200);
            };
        }

        function setupAttachmentHandler() {
            const fileInput = document.getElementById('violationAttachment');
            if (!fileInput) return;

            fileInput.addEventListener('change', function() {
                if (this.files.length > 0) {
                    // Add new files to the array
                    for (let i = 0; i < this.files.length; i++) {
                        // Check if file already exists in selection to avoid duplicates
                        const alreadyExists = selectedFiles.some(f => 
                            f.name === this.files[i].name && 
                            f.size === this.files[i].size
                        );
                        
                        if (!alreadyExists) {
                            selectedFiles.push(this.files[i]);
                        }
                    }
                    
                    // Clear the input so it can trigger change again for same file
                    this.value = '';
                    
                    updateAttachmentPreviews();
                }
            });
        }

        function populateSuggestedNotes(violationType) {
            const notesField = document.getElementById('violationNotes');
            if (!notesField || notesField.value.trim() !== '') return;

            const suggestions = {
                'improper_uniform': 'Student was observed wearing improper uniform attire in violation of school dress code policy.',
                'no_id': 'Student was found without the required school identification card.',
                'improper_footwear': 'Student was wearing inappropriate footwear that does not meet school standards.',
                'misconduct': 'Student engaged in behavior that violates school conduct policies.'
            };

            if (suggestions[violationType]) {
                notesField.value = suggestions[violationType];
                updateNotesCounter(notesField.value.length);
            }
        }

        // 6. FORM SUBMISSION
        if (violationForm) {
            // Setup real-time validation
            setupRealTimeValidation();
            
            // Setup attachment handling
            setupAttachmentHandler();

            violationForm.addEventListener('submit', async function(e) {
                e.preventDefault();

                // Get form data (no validation needed)
                const studentId = document.getElementById('modalStudentId').textContent;
                const violationType = document.querySelector('input[name="violationType"]:checked');
                const violationLevel = document.querySelector('input[name="violationLevel"]:checked');
                const violationDate = document.getElementById('violationDate').value;
                const violationTime = document.getElementById('violationTime').value;
                const location = document.getElementById('violationLocation').value;
                const reportedBy = document.getElementById('reportedBy').value.trim();
                const notes = document.getElementById('violationNotes').value.trim();
                
                // FORCE: Always use current admin's full name from session
                const sessionStr = localStorage.getItem('userSession');
                let enforcedAdminName = reportedBy;
                if (sessionStr) {
                    try {
                        const session = JSON.parse(sessionStr);
                        enforcedAdminName = session.full_name || session.name || session.username || reportedBy;
                    } catch (e) {
                        console.error('Error parsing session for reporter enforcement:', e);
                    }
                }
                
                // Get attachments
                const attachmentInput = document.getElementById('violationAttachment');
                let attachments = [];
                if (attachmentInput && attachmentInput.files.length > 0) {
                    // In a real app, you'd upload files to a server and get URLs back.
                    // For now, we'll store filenames or a placeholder if actual upload logic isn't here.
                    for (let i = 0; i < attachmentInput.files.length; i++) {
                        attachments.push(attachmentInput.files[i].name);
                    }
                }

                // Show loading state
                const submitBtn = document.querySelector('#ViolationRecordForm .Violations-btn-primary');
                const originalText = submitBtn.textContent;
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<i class="bx bx-loader-alt bx-spin"></i> Saving...';
                
                try {
                    const editingId = recordModal.dataset.editingId;

                    if (editingId) {
                        // Determine status based on level name (not ID)
                        let status = 'warning';
                        if (violationLevel) {
                            // Get the level name from the label
                            const levelLabel = document.querySelector(`label[for="${violationLevel.id}"] .level-title`);
                            let levelName = '';
                            
                            if (levelLabel) {
                                levelName = levelLabel.textContent.trim().toLowerCase();
                            } else if (typeof violationTypes !== 'undefined') {
                                // Fallback: try to find in global data
                                const typeId = document.querySelector('input[name="violationType"]:checked')?.value;
                                const levelId = violationLevel.value;
                                const type = violationTypes.find(t => t.id == typeId);
                                const level = type?.levels?.find(l => l.id == levelId);
                                if (level) levelName = level.name.toLowerCase();
                            }

                            if (levelName.includes('permitted')) {
                                status = 'permitted';
                            } else if (levelName.includes('disciplinary') || levelName.includes('3rd') || levelName.includes('warning 3')) {
                                status = 'disciplinary';
                            }
                        }

                        // Edit existing violation - keep JSON for PUT requests
                        const updateData = {
                            violationType: violationType ? violationType.value : '',
                            violationLevel: violationLevel ? violationLevel.value : '',
                            violationDate: violationDate,
                            violationTime: violationTime,
                            location: location,
                            reportedBy: enforcedAdminName,
                            status: status,
                            notes: notes
                        };

                        await updateViolation(editingId, updateData);
                        showNotification('Violation updated successfully!', 'success');
                    } else {
                        // Add new violation
                        const student = students.find(s => s.studentId === studentId);
                        if (!student) {
                            throw new Error('Selected student not found in database.');
                        }
                    
                        // Determine status based on level name (not ID)
                        let status = 'warning';
                        if (violationLevel) {
                            // Get the level name from the label
                            const levelLabel = document.querySelector(`label[for="${violationLevel.id}"] .level-title`);
                            // Fallback: try to find it in the violationTypes data if label not found
                            let levelName = '';
                            
                            if (levelLabel) {
                                levelName = levelLabel.textContent.trim().toLowerCase();
                            } else if (typeof violationTypes !== 'undefined') {
                                // Try to find in global data
                                const typeId = document.querySelector('input[name="violationType"]:checked')?.value;
                                const levelId = violationLevel.value;
                                const type = violationTypes.find(t => t.id == typeId);
                                const level = type?.levels?.find(l => l.id == levelId);
                                if (level) levelName = level.name.toLowerCase();
                            }

                            console.log('Determining status from level name:', levelName);

                            if (levelName.includes('permitted')) {
                                status = 'permitted';
                            } else if (levelName.includes('disciplinary') || levelName.includes('3rd') || levelName.includes('warning 3')) {
                                status = 'disciplinary';
                            }
                        }

                        // Ensure department is included
                        const studentDepartment = student.department || 'N/A';
                        if (!studentDepartment || studentDepartment === 'N/A') {
                            throw new Error('Student department is required. Please ensure the student has a department assigned.');
                        }

                        // Create FormData object for new record
                        const formData = new FormData();
                        formData.append('studentId', student.studentId);
                        formData.append('violationType', violationType ? violationType.value : '');
                        formData.append('violationLevel', violationLevel ? violationLevel.value : '');
                        formData.append('violationDate', violationDate);
                        formData.append('violationTime', violationTime);
                        formData.append('location', location);
                        formData.append('reportedBy', enforcedAdminName);
                        formData.append('status', status);
                        formData.append('notes', notes);
                        formData.append('department', studentDepartment);

                        // Append files from selectedFiles array
                        if (selectedFiles.length > 0) {
                            selectedFiles.forEach(file => {
                                formData.append('attachments[]', file);
                            });
                        }

                        await saveViolation(formData);
                        showNotification('Violation recorded successfully!', 'success');
                    }

                    closeRecordModal();
                } catch (error) {
                    console.error('Error saving violation:', error);
                    showNotification('Failed to save violation: ' + error.message, 'error');

                    // Re-enable submit button
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalText;
                }
            });
        }

        // 7. STUDENT SEARCH
        if (studentSearchInput) {
            studentSearchInput.addEventListener('keypress', async (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    try {
                        await handleStudentSearch();
                    } catch (error) {
                        console.error('Error searching student:', error);
                        alert('Failed to search student. Please try again.');
                    }
                }
            });
        }

        // 9. VIOLATION TYPE SELECTION
        const violationTypeCards = document.querySelectorAll('.violation-type-card');
        violationTypeCards.forEach(card => {
            card.addEventListener('click', function() {
                const radio = this.querySelector('input[type="radio"]');
                if (radio) radio.checked = true;
                
                violationTypeCards.forEach(c => c.classList.remove('active'));
                this.classList.add('active');
            });
        });

        // 10. VIOLATION LEVEL SELECTION
        const levelOptions = document.querySelectorAll('.violation-level-option');
        levelOptions.forEach(option => {
            option.addEventListener('click', function() {
                const radio = this.querySelector('input[type="radio"]');
                if (radio) radio.checked = true;
                
                levelOptions.forEach(o => o.classList.remove('active'));
                this.classList.add('active');
            });
        });

        // 11. SEARCH FUNCTIONALITY
        if (searchInput) {
            searchInput.addEventListener('input', function() {
                currentPage = 1;
                renderViolations();

                // Show hint for student ID searches
                const searchTerm = this.value.trim();
                const searchHint = document.getElementById('searchHint');
                if (!searchHint) {
                    const hint = document.createElement('div');
                    hint.id = 'searchHint';
                    hint.className = 'search-hint';
                    hint.style.cssText = `
                        position: absolute;
                        top: 100%;
                        left: 0;
                        right: 0;
                        background: var(--light);
                        border: 1px solid var(--border);
                        border-top: none;
                        border-radius: 0 0 8px 8px;
                        padding: 8px 12px;
                        font-size: 12px;
                        color: var(--dark-grey);
                        display: none;
                        z-index: 10;
                    `;
                    this.parentElement.style.position = 'relative';
                    this.parentElement.appendChild(hint);
                }

                const hintElement = document.getElementById('searchHint');
                if (searchTerm && isStudentIdSearch(searchTerm)) {
                    const foundStudent = findStudentBySearchTerm(searchTerm);
                    if (foundStudent) {
                        hintElement.textContent = `💡 Searching for student: ${foundStudent.firstName} ${foundStudent.lastName} (${foundStudent.studentId})`;
                        hintElement.style.display = 'block';
                    } else {
                        hintElement.textContent = '💡 No student found with that ID. Try searching by name instead.';
                        hintElement.style.display = 'block';
                    }
                } else {
                    hintElement.style.display = 'none';
                }
            });
        }

        // 12. FILTER FUNCTIONALITY
        if (deptFilter) {
            deptFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        }

        if (statusFilter) {
            statusFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        }

        if (dateFromFilter) {
            dateFromFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        }

        if (dateToFilter) {
            dateToFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        }

        // Archive filters
        const archiveDeptFilter = document.getElementById('ArchiveDeptFilter');
        const archiveMonthFilter = document.getElementById('ArchiveMonthFilter');
        const archiveDateFromFilter = document.getElementById('ArchiveDateFrom');
        const archiveDateToFilter = document.getElementById('ArchiveDateTo');
        const archiveSearchInput = document.getElementById('searchViolationArchive');

        if (archiveDeptFilter) archiveDeptFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        if (archiveMonthFilter) archiveMonthFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        if (archiveDateFromFilter) archiveDateFromFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        if (archiveDateToFilter) archiveDateToFilter.addEventListener('change', () => { currentPage = 1; renderViolations(); });
        if (archiveSearchInput) archiveSearchInput.addEventListener('input', () => { currentPage = 1; renderViolations(); });

        // 13. TAB NAVIGATION
        const tabBtns = document.querySelectorAll('.Violations-tab-btn');
        const currentFiltersGroup = document.getElementById('currentFilters');
        const archiveFiltersGroup = document.getElementById('archiveFilters');

        tabBtns.forEach(btn => {
            btn.addEventListener('click', function() {
                const view = this.dataset.view;
                if (currentView === view) return;

                // Update state
                currentView = view;

                // Update UI
                tabBtns.forEach(b => b.classList.remove('active'));
                this.classList.add('active');

                // Show/Hide filter groups
                if (view === 'current') {
                    if (currentFiltersGroup) currentFiltersGroup.style.display = 'flex';
                    if (archiveFiltersGroup) archiveFiltersGroup.style.display = 'none';
                    if (btnAddViolation) btnAddViolation.style.display = 'flex';
                } else {
                    if (currentFiltersGroup) currentFiltersGroup.style.display = 'none';
                    if (archiveFiltersGroup) archiveFiltersGroup.style.display = 'flex';
                    if (btnAddViolation) btnAddViolation.style.display = 'none';
                }

                // Reset page and reload data for the selected view
                currentPage = 1;
                loadViolations(true).then(() => {
                    renderViolations();
                    updateStats();
                });
            });
        });

        // 14. MONTHLY RESET FUNCTIONALITY
        const btnMonthlyReset = document.getElementById('btnMonthlyReset');
        if (btnMonthlyReset) {
            btnMonthlyReset.addEventListener('click', async function() {
                const confirmMessage = "Are you sure you want to perform a monthly reset?\n\n" +
                                     "This will:\n" +
                                     "1. Archive all violations from previous months\n" +
                                     "2. Reset all student violation levels and counts\n\n" +
                                     "This action cannot be undone.";

                if (confirm(confirmMessage)) {
                    try {
                        showLoadingOverlay('Performing monthly reset...');
                        const response = await fetch(API_BASE + 'violations.php?action=archive', {
                            method: 'POST'
                        });

                        const result = await response.json();
                        if (result.status === 'success') {
                            showNotification(result.message, 'success', 5000);
                            // Refresh current view
                            loadViolations(true).then(() => {
                                renderViolations();
                                updateStats();
                            });
                        } else {
                            throw new Error(result.message || 'Failed to perform reset');
                        }
                    } catch (error) {
                        console.error('Error during monthly reset:', error);
                        showNotification('Reset failed: ' + error.message, 'error');
                    } finally {
                        hideLoadingOverlay();
                    }
                }
            });
        }

        // 14. SORT FUNCTIONALITY
        const sortHeaders = document.querySelectorAll('.Violations-sortable');
        sortHeaders.forEach(header => {
            header.addEventListener('click', function() {
                const sortBy = this.dataset.sort;
                sortViolations(sortBy);
            });
        });

        // 15. STUDENT DETAILS CLOSE BUTTON
        const closeStudentDetailsBtn = document.getElementById('closeStudentDetails');
        if (closeStudentDetailsBtn) {
            closeStudentDetailsBtn.addEventListener('click', hideStudentDetails);
        }

        function sortViolations(sortBy) {
            violations.sort((a, b) => {
                switch(sortBy) {
                    case 'name':
                        return a.studentName.localeCompare(b.studentName);
                    case 'studentId':
                        return a.studentId.localeCompare(b.studentId);
                    case 'department':
                        return a.department.localeCompare(b.department);
                    case 'date':
                        return new Date(b.dateReported) - new Date(a.dateReported);
                    case 'id':
                    default:
                        return b.id - a.id;
                }
            });
            renderViolations();
        }

        // ========== INITIAL DATA LOAD ==========
        async function initializeData() {
            try {
                console.log('🚀 Initializing violations data...');

                // Check API connectivity first
                const apiStatus = await checkAPIConnectivity();
                console.log('API Status:', apiStatus);

                if (!apiStatus.violations && !apiStatus.students) {
                    console.error('Both APIs failed. API_BASE:', API_BASE);
                    console.error('Full violations URL:', window.location.origin + window.location.pathname.replace(/[^\/]*$/, '') + API_BASE + 'violations.php');
                    throw new Error('API endpoints not accessible. Please check if the PHP files exist in the api directory. API path: ' + API_BASE);
                }
                
                // Log warnings but continue if at least one API works
                if (!apiStatus.violations) {
                    console.warn('⚠️ Violations API not accessible, but continuing...');
                }
                if (!apiStatus.students) {
                    console.warn('⚠️ Students API not accessible, but continuing...');
                }

                // Show loading overlay
                showLoadingOverlay('Initializing violations system...');

                // Check if elements exist
                console.log('Checking DOM elements...');
                console.log('tableBody:', tableBody);
                console.log('btnAddViolation:', document.getElementById('btnAddViolations'));

                if (!tableBody) {
                    throw new Error('Required DOM elements not found. Please check the HTML structure.');
                }

                // Load data in parallel
                console.log('Loading data...');
                const [violationsData, studentsData] = await Promise.all([
                    loadViolations(false),
                    loadStudents(false),
                    loadViolationTypes(false),
                    loadDepartments(false)
                ]);

                console.log('Data loaded, violations:', violationsData.length, 'students:', studentsData.length);

                // Debug: Log available student IDs
                if (studentsData.length > 0) {
                    console.log('Available student IDs:', studentsData.map(s => s.studentId).slice(0, 10));
                } else {
                    console.warn('No students data loaded!');
                }

                console.log('Data loaded, rendering violations...');
                // Render violations
                renderViolations();

                console.log('Adding refresh button...');
                // Add refresh button to header
                addRefreshButton();

                // Update stats after data is loaded
                updateStats();

            } catch (error) {
                console.error('❌ Error initializing data:', error);
                console.error('Error details:', error.stack);

                // Provide specific error messages based on error type
                let errorMessage = error.message;
                let helpText = '';

                if (error.message.includes('Violations table does not exist')) {
                    errorMessage = 'Violations table not found in database';
                    helpText = 'Please run the SQL setup file: database/setup_complete.sql or database/violations_table.sql';
                } else if (error.message.includes('API endpoints not accessible')) {
                    errorMessage = 'API files not found';
                    helpText = 'Please ensure api/violations.php and api/students.php exist';
                } else if (error.message.includes('Required DOM elements not found')) {
                    errorMessage = 'Page structure error';
                    helpText = 'Please check the HTML structure of the violations page';
                }

                // Show error state in table
                if (tableBody) {
                    tableBody.innerHTML = `
                        <tr>
                            <td colspan="11" style="text-align: center; padding: 40px; color: #dc3545;">
                                <i class='bx bx-error' style="font-size: 24px; margin-bottom: 10px;"></i>
                                <div>Failed to load violations data</div>
                                <div style="font-size: 14px; margin: 10px 0; color: #666;">${errorMessage}</div>
                                ${helpText ? `<div style="font-size: 12px; margin: 10px 0; color: #888;">${helpText}</div>` : ''}
                                <div style="margin-top: 20px;">
                                    <button onclick="window.location.reload()" style="margin-right: 10px; padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">
                                        <i class='bx bx-refresh'></i> Reload Page
                                    </button>
                                    <button onclick="checkDatabaseSetup()" style="padding: 8px 16px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer;">
                                        <i class='bx bx-check'></i> Check Setup
                                    </button>
                                </div>
                            </td>
                        </tr>
                    `;
                }

                showNotification('Failed to initialize violations system: ' + errorMessage, 'error', 8000);
            } finally {
                hideLoadingOverlay();
            }
        }

        // Function to check database setup
        window.checkDatabaseSetup = async function() {
            try {
                showLoadingOverlay('Checking database setup...');
                
                console.log('API_BASE:', API_BASE);
                const fullUrl = window.location.href.replace(/[^\/]*$/, '') + API_BASE + 'violations.php';
                console.log('Full URL being called:', fullUrl);
        
                // Test API connectivity
                console.log('Testing violations API...');
                const violationsResponse = await fetch(API_BASE + 'violations.php');
                console.log('Violations response status:', violationsResponse.status);
                
                // Get text first to see what's returned
                const violationsText = await violationsResponse.text();
                console.log('Raw violations response:', violationsText.substring(0, 500));
                
                // Check if it's HTML (error page)
                if (violationsText.trim().startsWith('<!DOCTYPE') || violationsText.trim().startsWith('<html')) {
                    alert('❌ API returned HTML instead of JSON!\n\nThis means the API path is wrong or there\'s a server error.\n\nURL tried: ' + API_BASE + 'violations.php\n\nFull URL: ' + fullUrl + '\n\nResponse preview:\n' + violationsText.substring(0, 200));
                    return;
                }
                
                let violationsData;
                try {
                    violationsData = JSON.parse(violationsText);
                } catch (e) {
                    alert('❌ Invalid JSON from violations API:\n' + violationsText.substring(0, 300));
                    return;
                }
                console.log('Violations API Response:', violationsData);
        
                if (!violationsResponse.ok) {
                    alert('❌ Violations API not accessible\nStatus: ' + violationsResponse.status);
                    return;
                }
        
                if (violationsData.status === 'error') {
                    alert('❌ Violations API Error:\n' + violationsData.message + (violationsData.help ? '\n\nHelp: ' + violationsData.help : ''));
                    return;
                }
        
                // Test students API
                console.log('Testing students API...');
                const studentsResponse = await fetch(API_BASE + 'students.php');
                const studentsText = await studentsResponse.text();
                console.log('Raw students response:', studentsText.substring(0, 500));
                
                if (studentsText.trim().startsWith('<!DOCTYPE') || studentsText.trim().startsWith('<html')) {
                    alert('❌ Students API returned HTML instead of JSON!\n\nResponse preview:\n' + studentsText.substring(0, 200));
                    return;
                }
                
                let studentsData;
                try {
                    studentsData = JSON.parse(studentsText);
                } catch (e) {
                    alert('❌ Invalid JSON from students API:\n' + studentsText.substring(0, 300));
                    return;
                }
                console.log('Students API Response:', studentsData);
        
                if (!studentsResponse.ok) {
                    alert('❌ Students API not accessible\nStatus: ' + studentsResponse.status);
                    return;
                }
        
                if (studentsData.status === 'error') {
                    alert('❌ Students API Error:\n' + studentsData.message);
                    return;
                }
        
                alert('✅ Database setup looks good!\n\nFound:\n- ' + 
                      (violationsData.violations ? violationsData.violations.length : 0) + 
                      ' violations\n- ' + 
                      (studentsData.students || studentsData.data ? (studentsData.students || studentsData.data).length : 0) + 
                      ' students\n\nTry refreshing the page.');
        
            } catch (error) {
                alert('❌ Error checking database setup: ' + error.message + '\n\nCheck browser console for details.');
                console.error('Setup check error:', error);
            } finally {
                hideLoadingOverlay();
            }
        };
        // Add refresh button to header
        function addRefreshButton() {
            try {
                const firstButtonGroup = document.querySelector('.Violations-button-group');
                console.log('Adding refresh button, firstButtonGroup:', firstButtonGroup);

                if (!firstButtonGroup) {
                    console.warn('First button group not found, skipping refresh button');
                    return;
                }

                if (document.getElementById('refreshViolationsBtn')) {
                    console.log('Refresh button already exists');
                    return;
                }

                const refreshBtn = document.createElement('button');
                refreshBtn.id = 'refreshViolationsBtn';
                refreshBtn.className = 'Violations-btn outline small';
                refreshBtn.innerHTML = '<i class="bx bx-refresh"></i><span>Refresh</span>';
                refreshBtn.onclick = function() {
                    console.log('Refresh button clicked');
                    refreshData();
                };
                refreshBtn.title = 'Refresh data';

                // Insert at the beginning of the first button group
                if (firstButtonGroup.firstChild) {
                    firstButtonGroup.insertBefore(refreshBtn, firstButtonGroup.firstChild);
                    console.log('Refresh button inserted before first child');
                } else {
                    firstButtonGroup.appendChild(refreshBtn);
                    console.log('Refresh button appended to button group');
                }
            } catch (error) {
                console.error('Error adding refresh button:', error);
            }
        }

        // Debug functions available globally
        window.debugViolations = function() {
            console.log('=== VIOLATIONS DEBUG ===');
            console.log('Violations array length:', violations.length);
            if (violations.length > 0) {
                console.log('First 5 violations:');
                violations.slice(0, 5).forEach((v, i) => {
                    console.log(`${i+1}. ID: ${v.caseId}, Student: ${v.studentName}, Status: ${v.status}`);
                });
            } else {
                console.log('No violations in array!');
            }
            console.log('=== END DEBUG ===');
        };

        window.forceReloadData = async function() {
            console.log('Forcing data reload...');
            await initializeData();
        };

        // Manual test data for debugging
        window.setTestData = function() {
            console.log('Setting test data...');
            violations = [
                {
                    id: 1,
                    caseId: 'VIOL-2024-001',
                    studentId: '2024-001',
                    studentName: 'John Doe',
                    studentImage: 'https://ui-avatars.com/api/?name=John+Doe&background=ffd700&color=333&size=40',
                    studentDept: 'BSIT',
                    studentSection: 'BSIT-1A',
                    studentContact: '+63 912 345 6789',
                    violationType: 'improper_uniform',
                    violationTypeLabel: 'Improper Uniform',
                    violationLevel: 'warning2',
                    violationLevelLabel: 'Warning 2',
                    department: 'BSIT',
                    section: 'BSIT-1A',
                    dateReported: '2024-02-15',
                    violationTime: '08:15:00',
                    dateTime: 'Feb 15, 2024 • 08:15 AM',
                    location: 'gate_1',
                    locationLabel: 'Main Gate 1',
                    reportedBy: 'Officer Maria Santos',
                    status: 'warning',
                    statusLabel: 'Warning',
                    notes: 'Test violation data',
                    attachments: [],
                    created_at: '2024-02-15 08:15:00',
                    updated_at: '2024-02-15 08:15:00'
                }
            ];
            students = [
                {
                    id: 1,
                    studentId: '2024-001',
                    firstName: 'John',
                    lastName: 'Doe',
                    email: 'john.doe@email.com',
                    contact: '+63 912 345 6789',
                    department: 'BSIT',
                    section: 'BSIT-1A',
                    avatar: 'https://ui-avatars.com/api/?name=John+Doe&background=ffd700&color=333&size=80'
                }
            ];
            renderViolations();
            updateStats();
            console.log('Test data set and rendered!');
        };

        window.testAPI = async function() {
            console.log('Testing API endpoints...');
            try {
                const violationsResponse = await fetch(API_BASE + 'violations.php');
                const violationsData = await violationsResponse.json();
                console.log('Violations API Response:', violationsData);

                const studentsResponse = await fetch(API_BASE + 'students.php');
                const studentsData = await studentsResponse.json();
                console.log('Students API Response:', studentsData);
            } catch (error) {
                console.error('API test failed:', error);
            }
        };

        // Start initialization
        initializeData();
        
    } catch (error) {
        console.error('❌ Error initializing violations module:', error);
    }
}

// Make function globally available
window.initViolationsModule = initViolationsModule;
