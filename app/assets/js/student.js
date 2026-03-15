// student.js - Complete working version with API integration
function initStudentsModule() {
    console.log('🛠 Students module initializing...');
    
    try {
        // Elements
        const tableBody = document.getElementById('StudentsTableBody');
        const btnAddStudent = document.getElementById('btnAddStudents');
        const btnArchivedStudents = document.getElementById('btnArchivedStudents');
        const btnAddFirstStudent = document.getElementById('btnAddFirstStudent');
        const modal = document.getElementById('StudentsModal');
        const modalOverlay = document.getElementById('StudentsModalOverlay');
        const closeBtn = document.getElementById('closeStudentsModal');
        const cancelBtn = document.getElementById('cancelStudentsModal');
        const studentsForm = document.getElementById('StudentsForm');
        const searchInput = document.getElementById('searchStudent');
        const filterSelect = document.getElementById('StudentsFilterSelect');
        const deptFilterSelect = document.getElementById('StudentsDepartmentFilter');
        const sectionFilterSelect = document.getElementById('StudentsSectionFilter');
        const exportBtn = document.getElementById('btnExportStudents');
        const importBtn = document.getElementById('btnImportStudents');
        const exportModal = document.getElementById('ExportStudentsModal');
        const closeExportBtn = document.getElementById('closeExportModal');
        const exportModalOverlay = document.getElementById('ExportModalOverlay');
        const exportPDFBtn = document.getElementById('exportPDF');
        const exportExcelBtn = document.getElementById('exportExcel');
        const exportWordBtn = document.getElementById('exportWord');
        const studentDeptSelect = document.getElementById('studentDept');
        const studentSectionSelect = document.getElementById('studentSection');
        const btnDeleteAllStudents = document.getElementById('btnDeleteAllStudents');

        // Modern Alert Elements
        const modernAlertModal = document.getElementById('ModernAlertModal');
        const modernAlertIcon = document.getElementById('ModernAlertIcon');
        const modernAlertTitle = document.getElementById('ModernAlertTitle');
        const modernAlertMessage = document.getElementById('ModernAlertMessage');
        const modernAlertStats = document.getElementById('ModernAlertStats');
        const modernAlertActions = document.getElementById('ModernAlertActions');
        const modernAlertCancel = document.getElementById('ModernAlertCancel');
        const modernAlertConfirm = document.getElementById('ModernAlertConfirm');

        // Check for essential elements
        if (!tableBody) {
            console.error('❗ #StudentsTableBody not found');
            return;
        }

        if (!modal) {
            console.warn('⚠️ #StudentsModal not found');
        }

        // Students data (will be loaded from database)
        let students = [];
        let allStudents = []; // Store all students for stats
        let currentView = 'active'; // 'active' or 'archived'
        let editingStudentId = null;
        let currentPage = 1;
        let itemsPerPage = 10;
        let totalRecords = 0;
        let totalPages = 0;

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
            if (currentPath.includes('/app/views/')) {
                return '../../api/';
            } else if (currentPath.includes('/includes/')) {
                return '../api/';
            } else {
                return 'api/';
            }
        }
        
        const API_BASE = getAPIBasePath();
        console.log('🔗 API Base Path:', API_BASE);
        
        const apiBase = API_BASE+'students.php';
        const departmentsApiBase = API_BASE + 'departments.php';
        const sectionsApiBase = API_BASE + 'sections.php';
        
        console.log('📡 Students API:', apiBase);
        console.log('📡 Departments API:', departmentsApiBase);
        console.log('📡 Sections API:', sectionsApiBase);

        // --- Validation Functions ---
        function validateStudentForm() {
            const requiredFields = [
                { id: 'studentId', name: 'Student ID' },
                { id: 'firstName', name: 'First Name' },
                { id: 'lastName', name: 'Last Name' },
                { id: 'studentEmail', name: 'Email' },
                { id: 'studentDept', name: 'Department' },
                { id: 'studentSection', name: 'Section' },
                { id: 'studentYearlevel', name: 'Year Level' }
            ];

            let isValid = true;
            let firstInvalidField = null;

            requiredFields.forEach(field => {
                const element = document.getElementById(field.id);
                if (element) {
                    if (!element.value.trim()) {
                        element.classList.add('is-invalid');
                        isValid = false;
                        if (!firstInvalidField) firstInvalidField = element;
                        
                        // Add listener to remove invalid class on input
                        element.addEventListener('input', function removeInvalid() {
                            element.classList.remove('is-invalid');
                            element.removeEventListener('input', removeInvalid);
                        });
                    } else {
                        element.classList.remove('is-invalid');
                    }
                }
            });

            if (!isValid) {
                showError('Please fill out all required fields.');
                if (firstInvalidField) firstInvalidField.focus();
            }

            return isValid;
        }

        // --- Modern Alert Function ---
        function showModernAlert(options) {
            // Prefer global function from dashboard.js if available
            if (window.showModernAlert && typeof window.showModernAlert === 'function') {
                return window.showModernAlert(options);
            }

            // Fallback to local implementation
            return new Promise((resolve) => {
                if (!modernAlertModal) return resolve(false);

                // Reset
                modernAlertTitle.textContent = options.title;
                modernAlertMessage.textContent = options.message;
                modernAlertIcon.className = `Modern-modal-icon ${options.icon || 'warning'}`;
                
                // Set Icon
                let iconHtml = "<i class='bx bx-help-circle'></i>";
                if (options.icon === 'success') iconHtml = "<i class='bx bx-check-circle'></i>";
                if (options.icon === 'error') iconHtml = "<i class='bx bx-x-circle'></i>";
                if (options.icon === 'loading') iconHtml = "<i class='bx bx-loader-alt bx-spin'></i>";
                modernAlertIcon.innerHTML = iconHtml;

                // Stats
                if (options.stats) {
                    modernAlertStats.style.display = 'grid';
                    document.getElementById('statNew').textContent = options.stats.created || 0;
                    document.getElementById('statUpdated').textContent = options.stats.updated || 0;
                    document.getElementById('statSkipped').textContent = options.stats.skipped || 0;
                } else {
                    modernAlertStats.style.display = 'none';
                }

                // Buttons
                modernAlertCancel.style.display = options.showCancel !== false ? 'block' : 'none';
                modernAlertCancel.textContent = options.cancelText || 'Cancel';
                modernAlertConfirm.textContent = options.confirmText || 'Confirm';
                modernAlertConfirm.style.display = 'block';

                // Show
                modernAlertModal.classList.add('active');
                document.body.style.overflow = 'hidden';

                // Handlers
                const onConfirm = () => {
                    cleanup();
                    resolve(true);
                };
                const onCancel = () => {
                    cleanup();
                    resolve(false);
                };
                const cleanup = () => {
                    modernAlertConfirm.removeEventListener('click', onConfirm);
                    modernAlertCancel.removeEventListener('click', onCancel);
                    modernAlertModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                };

                modernAlertConfirm.addEventListener('click', onConfirm);
                modernAlertCancel.addEventListener('click', onCancel);
            });
        }

        // Pagination renderer
        function renderPagination() {
            const paginationContainer = document.querySelector('.Students-pagination');
            if (!paginationContainer) return;

            let html = '';
            html += `<button class="Students-pagination-btn ${currentPage === 1 ? 'disabled' : ''}" ${currentPage === 1 ? 'disabled' : ''} onclick="window.changeStudentsPage(${currentPage - 1})"><i class='bx bx-chevron-left'></i></button>`;

            for (let i = 1; i <= totalPages; i++) {
                if (i === 1 || i === totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
                    html += `<button class="Students-pagination-btn ${i === currentPage ? 'active' : ''}" onclick="window.changeStudentsPage(${i})">${i}</button>`;
                } else if (i === currentPage - 2 || i === currentPage + 2) {
                    html += `<span class="Students-pagination-ellipsis">...</span>`;
                }
            }

            html += `<button class="Students-pagination-btn ${currentPage === totalPages || totalPages === 0 ? 'disabled' : ''}" ${currentPage === totalPages || totalPages === 0 ? 'disabled' : ''} onclick="window.changeStudentsPage(${currentPage + 1})"><i class='bx bx-chevron-right'></i></button>`;
            paginationContainer.innerHTML = html;
        }

        window.changeStudentsPage = function(page) {
            if (page < 1 || page > totalPages || page === currentPage) return;
            currentPage = page;
            fetchStudents();
        };

        // --- API Functions ---
        async function fetchStudents() {
            try {
                const filter = filterSelect ? filterSelect.value : 'all';
                const search = searchInput ? searchInput.value : '';
                const department = deptFilterSelect ? deptFilterSelect.value : 'all';
                const section = sectionFilterSelect ? sectionFilterSelect.value : 'all';
                
                let url = `${apiBase}?action=get&filter=${filter}&page=${currentPage}&limit=${itemsPerPage}&department=${encodeURIComponent(department)}&section=${encodeURIComponent(section)}`;
                if (search) {
                    url += `&search=${encodeURIComponent(search)}`;
                }
                
                console.log('Fetching students from:', url); // Debug log
                
                const response = await fetch(url);
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const text = await response.text();
                console.log('Raw API Response:', text); // Debug log
                
                let result;
                try {
                    result = JSON.parse(text);
                } catch (parseError) {
                    console.error('JSON Parse Error:', parseError);
                    console.error('Response was:', text);
                    throw new Error('Invalid JSON response from server. The students table may not exist. Please run the database setup SQL files.');
                }
                
                console.log('Parsed API Response:', result); // Debug log
                
                if (result.status === 'success') {
                    const payload = result.data;
                    if (Array.isArray(payload)) {
                        // Legacy array response - client-side pagination
                        allStudents = payload;
                        const viewFiltered = currentView === 'archived' 
                            ? allStudents.filter(s => s.status && s.status.toLowerCase() === 'archived') 
                            : allStudents.filter(s => s.status && s.status.toLowerCase() !== 'archived');
                        totalRecords = viewFiltered.length;
                        totalPages = Math.ceil(totalRecords / itemsPerPage);
                        const start = (currentPage - 1) * itemsPerPage;
                        const end = start + itemsPerPage;
                        students = viewFiltered.slice(start, end);
                    } else if (payload && Array.isArray(payload.students)) {
                        // New paginated response
                        allStudents = payload.students;
                        totalRecords = typeof payload.total === 'number' ? payload.total : allStudents.length;
                        totalPages = typeof payload.total_pages === 'number' ? payload.total_pages : Math.ceil(totalRecords / itemsPerPage);
                        currentPage = typeof payload.page === 'number' ? payload.page : currentPage;
                        
                        // Backend already filters by status when we pass the filter param, 
                        // but we keep this for consistency and fallback
                        const viewFiltered = currentView === 'archived' 
                            ? allStudents.filter(s => s.status && s.status.toLowerCase() === 'archived') 
                            : allStudents.filter(s => s.status && s.status.toLowerCase() !== 'archived');
                        
                        // If backend already filtered, viewFiltered should equal allStudents
                        students = viewFiltered;
                    } else {
                        console.error('Unexpected API data shape:', payload);
                        showError('Unexpected response from server while loading students.');
                        return;
                    }

                    renderStudents();
                    renderPagination();
                    await loadStats();
                } else {
                    console.error('Error fetching students:', result.message);
                    showError(result.message || 'Failed to load students');
                }
            } catch (error) {
                console.error('Error fetching students:', error);
                console.error('Full error details:', error.message, error.stack);
                showError('Error loading students: ' + error.message + '. Please check if the students table exists in the database.');
            }
        }

        async function loadStats() {
            try {
                const response = await fetch(`${apiBase}?action=stats`);
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const text = await response.text();
                let result;
                try {
                    result = JSON.parse(text);
                } catch (parseError) {
                    console.error('JSON Parse Error in stats:', parseError);
                    return; // Silently fail for stats
                }
                
                if (result.status === 'success') {
                    const stats = result.data;
                    const totalEl = document.getElementById('totalStudents');
                    const activeEl = document.getElementById('activeStudents');
                    const inactiveEl = document.getElementById('inactiveStudents');
                    const graduatingEl = document.getElementById('graduatingStudents');
                    const activePctEl = document.getElementById('activeStudentsPct');
                    const inactivePctEl = document.getElementById('inactiveStudentsPct');
                    const graduatingPctEl = document.getElementById('graduatingStudentsPct');
                    
                    if (totalEl) totalEl.textContent = stats.total || 0;
                    if (activeEl) activeEl.textContent = stats.active || 0;
                    if (inactiveEl) inactiveEl.textContent = stats.inactive || 0;
                    if (graduatingEl) graduatingEl.textContent = stats.graduating || 0;

                    const total = Number(stats.total) || 0;
                    const active = Number(stats.active) || 0;
                    const inactive = Number(stats.inactive) || 0;
                    const graduating = Number(stats.graduating) || 0;
                    const activePct = total > 0 ? Math.round((active / total) * 100) : 0;
                    const inactivePct = total > 0 ? Math.round((inactive / total) * 100) : 0;
                    const graduatingPct = total > 0 ? Math.round((graduating / total) * 100) : 0;
                    if (activePctEl) activePctEl.textContent = `${activePct}%`;
                    if (inactivePctEl) inactivePctEl.textContent = `${inactivePct}%`;
                    if (graduatingPctEl) graduatingPctEl.textContent = `${graduatingPct}%`;
                }
            } catch (error) {
                console.error('Error loading stats:', error);
                // Don't show error for stats, just log it
            }
        }

        async function addStudent(formData) {
            try {
                const response = await fetch(`${apiBase}?action=add`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess(result.message || 'Student added successfully!');
                    await fetchStudents();
                    closeModal();
                } else {
                    showError(result.message || 'Failed to add student');
                }
            } catch (error) {
                console.error('Error adding student:', error);
                showError('Error adding student. Please try again.');
            }
        }

        async function updateStudent(studentId, formData) {
            try {
                const response = await fetch(`${apiBase}?action=update`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess(result.message || 'Student updated successfully!');
                    await fetchStudents();
                    closeModal();
                } else {
                    showError(result.message || 'Failed to update student');
                }
            } catch (error) {
                console.error('Error updating student:', error);
                showError('Error updating student. Please try again.');
            }
        }

        async function deleteStudent(studentId) {
            try {
                const response = await fetch(`${apiBase}?action=delete&id=${studentId}`, {
                    method: 'GET'
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess(result.message || 'Student archived successfully!');
                    await fetchStudents();
                } else {
                    showError(result.message || 'Failed to archive student');
                }
            } catch (error) {
                console.error('Error deleting student:', error);
                showError('Error archiving student. Please try again.');
            }
        }

        async function restoreStudent(studentId) {
            try {
                const response = await fetch(`${apiBase}?action=restore&id=${studentId}`, {
                    method: 'GET'
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess(result.message || 'Student restored successfully!');
                    await fetchStudents();
                } else {
                    showError(result.message || 'Failed to restore student');
                }
            } catch (error) {
                console.error('Error restoring student:', error);
                showError('Error restoring student. Please try again.');
            }
        }

        async function activateStudent(studentId) {
            try {
                const formData = new FormData();
                formData.append('action', 'update');
                formData.append('studentId', studentId);
                formData.append('studentStatus', 'active');
                
                // Get current student data first
                const student = allStudents.find(s => s.id === studentId);
                if (student) {
                    formData.append('studentIdCode', student.studentId);
                    formData.append('firstName', student.firstName);
                    formData.append('lastName', student.lastName);
                    formData.append('studentEmail', student.email);
                    formData.append('studentContact', student.contact || '');
                    formData.append('studentDept', student.department || '');
                    formData.append('studentSection', student.section_id || '');
                    formData.append('studentStatus', 'active');
                }
                
                const response = await fetch(`${apiBase}?action=update`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess('Student activated successfully!');
                    await fetchStudents();
                } else {
                    showError(result.message || 'Failed to activate student');
                }
            } catch (error) {
                console.error('Error activating student:', error);
                showError('Error activating student. Please try again.');
            }
        }

        async function deactivateStudent(studentId) {
            try {
                const formData = new FormData();
                formData.append('action', 'update');
                formData.append('studentId', studentId);
                formData.append('studentStatus', 'inactive');
                
                // Get current student data first
                const student = allStudents.find(s => s.id === studentId);
                if (student) {
                    formData.append('studentIdCode', student.studentId);
                    formData.append('firstName', student.firstName);
                    formData.append('lastName', student.lastName);
                    formData.append('studentEmail', student.email);
                    formData.append('studentContact', student.contact || '');
                    formData.append('studentDept', student.department || '');
                    formData.append('studentSection', student.section_id || '');
                    formData.append('studentStatus', 'inactive');
                }
                
                const response = await fetch(`${apiBase}?action=update`, {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showSuccess('Student deactivated successfully!');
                    await fetchStudents();
                } else {
                    showError(result.message || 'Failed to deactivate student');
                }
            } catch (error) {
                console.error('Error deactivating student:', error);
                showError('Error deactivating student. Please try again.');
            }
        }

        async function loadDepartments() {
            if (!studentDeptSelect) {
                console.warn('studentDeptSelect element not found');
                return;
            }
            
            try {
                const response = await fetch(departmentsApiBase);
                const result = await response.json();
                console.log('Departments API response:', result);
                
                // Clear existing options except the first one
                studentDeptSelect.innerHTML = '<option value="">Select Department</option>';
                
                if (result.status === 'success' && result.data && result.data.length > 0) {
                    result.data.forEach(dept => {
                        const option = document.createElement('option');
                        option.value = dept.code; // Use department_code as value
                        option.textContent = dept.name; // Use department_name as display text
                        studentDeptSelect.appendChild(option);
                    });
                    console.log(`Loaded ${result.data.length} departments`);
                } else {
                    const option = document.createElement('option');
                    option.value = '';
                    option.textContent = 'No departments available';
                    studentDeptSelect.appendChild(option);
                    console.warn('No departments found or API error:', result);
                }
            } catch (error) {
                console.error('Error loading departments:', error);
                studentDeptSelect.innerHTML = '<option value="">Error loading departments</option>';
            }
        }

        async function loadFilterDepartments() {
            if (!deptFilterSelect) return;
            
            try {
                const response = await fetch(departmentsApiBase);
                const result = await response.json();
                
                deptFilterSelect.innerHTML = '<option value="all">All Departments</option>';
                
                if (result.status === 'success' && result.data && result.data.length > 0) {
                    result.data.forEach(dept => {
                        const option = document.createElement('option');
                        option.value = dept.code;
                        option.textContent = dept.name;
                        deptFilterSelect.appendChild(option);
                    });
                }
            } catch (error) {
                console.error('Error loading filter departments:', error);
            }
        }

        async function loadSectionsByDepartment(departmentCode) {
            if (!departmentCode || !studentSectionSelect) {
                console.warn('Missing departmentCode or studentSectionSelect');
                return;
            }
            
            try {
                const url = `${sectionsApiBase}?action=getByDepartment&department_code=${encodeURIComponent(departmentCode)}`;
                console.log('Loading sections from:', url);
                const response = await fetch(url);
                const result = await response.json();
                console.log('Sections API response:', result);
                
                // Clear existing options
                studentSectionSelect.innerHTML = '<option value="">Select Section</option>';
                
                if (result.status === 'success' && result.data && result.data.length > 0) {
                    result.data.forEach(section => {
                        const option = document.createElement('option');
                        option.value = section.id;
                        option.textContent = `${section.section_code} - ${section.section_name}`;
                        studentSectionSelect.appendChild(option);
                    });
                    console.log(`Loaded ${result.data.length} sections for department ${departmentCode}`);
                } else {
                    const option = document.createElement('option');
                    option.value = '';
                    option.textContent = 'No sections available';
                    studentSectionSelect.appendChild(option);
                    console.warn('No sections found for department:', departmentCode, result);
                }
            } catch (error) {
                console.error('Error loading sections:', error);
                studentSectionSelect.innerHTML = '<option value="">Error loading sections</option>';
            }
        }

        async function loadFilterSections(departmentCode) {
            if (!sectionFilterSelect) return;
            
            try {
                const url = `${sectionsApiBase}?action=getByDepartment&department_code=${encodeURIComponent(departmentCode)}`;
                const response = await fetch(url);
                const result = await response.json();
                
                sectionFilterSelect.innerHTML = '<option value="all">All Sections</option>';
                
                if (result.status === 'success' && result.data && result.data.length > 0) {
                    result.data.forEach(section => {
                        const option = document.createElement('option');
                        option.value = section.id;
                        option.textContent = `${section.section_code} - ${section.section_name}`;
                        sectionFilterSelect.appendChild(option);
                    });
                }
            } catch (error) {
                console.error('Error loading filter sections:', error);
            }
        }

        // --- Render function ---
        function renderStudents() {
            const searchTerm = searchInput ? searchInput.value.toLowerCase() : '';
            const filterValue = filterSelect ? filterSelect.value : 'all';
            const deptFilter = deptFilterSelect ? deptFilterSelect.value : 'all';
            const sectionFilter = sectionFilterSelect ? sectionFilterSelect.value : 'all';
            
            const list = Array.isArray(students) ? students : [];
            const filteredStudents = list.filter(s => {
                const fullName = `${s.firstName || ''} ${s.middleName || ''} ${s.lastName || ''}`.toLowerCase();
                const matchesSearch = fullName.includes(searchTerm) || 
                                    (s.studentId || '').toLowerCase().includes(searchTerm) ||
                                    (s.email || '').toLowerCase().includes(searchTerm) ||
                                    (s.department || '').toLowerCase().includes(searchTerm) ||
                                    (s.section || '').toLowerCase().includes(searchTerm);
                
                // Filter by status, but exclude archived from normal view
                let matchesFilter = true;
                if (currentView === 'archived') {
                    matchesFilter = s.status === 'archived';
                } else {
                    matchesFilter = s.status !== 'archived' && (filterValue === 'all' || s.status === filterValue);
                }

                // Filter by department
                if (deptFilter !== 'all' && s.department_code !== deptFilter) {
                    matchesFilter = false;
                }

                // Filter by section
                if (sectionFilter !== 'all' && String(s.section_id) !== String(sectionFilter)) {
                    matchesFilter = false;
                }
                
                return matchesSearch && matchesFilter;
            });

            // Show/hide empty state
            const emptyState = document.getElementById('StudentsEmptyState');
            if (emptyState) {
                emptyState.style.display = filteredStudents.length === 0 ? 'flex' : 'none';
            }

            if (filteredStudents.length === 0) {
                tableBody.innerHTML = `
                    <tr>
                        <td colspan="9" style="text-align: center; padding: 40px; color: #999;">
                            <i class='bx bx-inbox' style="font-size: 48px; display: block; margin-bottom: 10px;"></i>
                            <p>No students found</p>
                        </td>
                    </tr>
                `;
                renderPagination();
            } else {
                tableBody.innerHTML = filteredStudents.map(s => {
                    const fullName = `${s.firstName || ''} ${s.middleName ? s.middleName + ' ' : ''}${s.lastName || ''}`;
                    const deptClass = getDepartmentClass(s.department);
                    
                    // Build avatar URL - handle relative paths
                    let avatarUrl = '';
                    if (s.avatar && s.avatar !== '') {
                        // If it's already a full URL (http/https) or data URL, use it as is
                        if (s.avatar.startsWith('http') || s.avatar.startsWith('data:')) {
                            avatarUrl = s.avatar;
                        } else {
                            // It's a relative path like 'assets/img/students/filename.jpg' or 'app/assets/img/students/filename.jpg'
                            // Normalize to app/assets/ if it starts with assets/
                            let normalizedAvatar = s.avatar;
                            if (normalizedAvatar.startsWith('assets/') && !normalizedAvatar.startsWith('app/assets/')) {
                                normalizedAvatar = normalizedAvatar.replace('assets/', 'app/assets/');
                            }
                            // Convert to absolute path from project root
                            const pathMatch = window.location.pathname.match(/^(\/[^\/]+)\//);
                            const projectBase = pathMatch ? pathMatch[1] : '';
                            avatarUrl = projectBase + '/' + normalizedAvatar;
                        }
                    } else {
                        // Use default avatar generator
                        avatarUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(fullName)}&background=ffd700&color=333&size=40`;
                    }
                    
                    return `
                    <tr data-id="${s.id}">
                        <td class="student-row-id" data-label="ID">${s.id}</td>
                        <td class="student-image-cell" data-label="Image">
                            <div class="student-image-wrapper">
                                <img src="${avatarUrl}" alt="${escapeHtml(fullName)}" class="student-avatar" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(fullName)}&background=ffd700&color=333&size=40'">
                            </div>
                        </td>
                        <td class="student-id" data-label="Student ID">${escapeHtml(s.studentId || '')}</td>
                        <td class="student-name" data-label="Name">
                            <div class="student-name-wrapper">
                                <strong>${escapeHtml(fullName)}</strong>
                                <small>${escapeHtml(s.email || '')}</small>
                            </div>
                        </td>
                        <td class="student-dept" data-label="Department">
                            <span class="dept-badge ${deptClass}">${escapeHtml(s.department || 'N/A')}</span>
                        </td>
                        <td class="student-section" data-label="Section">${escapeHtml(s.section || 'N/A')}</td>
                        <td class="student-yearlevel" data-label="Year Level">
                            <span class="yearlevel-badge">${escapeHtml(s.yearlevel || 'N/A')}</span>
                        </td>
                        <td class="student-contact" data-label="Contact No">${escapeHtml(s.contact || 'N/A')}</td>
                        <td data-label="Status">
                            <span class="Students-status-badge ${s.status || 'active'}">${formatStatus(s.status || 'active')}</span>
                        </td>
                        <td data-label="Actions">
                            <div class="Students-action-buttons">
                                <button class="Students-action-btn view" data-id="${s.id}" title="View Profile">
                                    <i class='bx bx-user'></i>
                                </button>
                                <button class="Students-action-btn edit" data-id="${s.id}" title="Edit">
                                    <i class='bx bx-edit'></i>
                                </button>
                                ${ (s.status && s.status.toLowerCase() === 'archived') ? `
                                    <button class="Students-action-btn restore" data-id="${s.id}" title="Restore">
                                        <i class='bx bx-undo'></i>
                                    </button>
                                    <button class="Students-action-btn delete permanent" data-id="${s.id}" title="Delete Permanently">
                                        <i class='bx bx-trash'></i>
                                    </button>
                                ` : `
                                    <button class="Students-action-btn delete" data-id="${s.id}" title="Archive">
                                        <i class='bx bx-trash'></i>
                                    </button>
                                `}
                            </div>
                        </td>
                    </tr>
                `;
                }).join('');
            }

            updateCounts(filteredStudents);
            renderPagination();
        }

        function escapeHtml(text) {
            if (!text) return '';
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function getDepartmentClass(dept) {
            const classes = {
                'BSIT': 'bsit',
                'BSCS': 'bscs',
                'BSBA': 'business',
                'BSN': 'nursing',
                'BEED': 'education',
                'BSED': 'education',
                'CS': 'bsit',
                'BA': 'business',
                'NUR': 'nursing',
                'BSIS': 'bsit',
                'WFT': 'default',
                'BTVTEd': 'education'
            };
            return classes[dept] || 'default';
        }

        function formatStatus(status) {
            const statusMap = {
                'active': 'Active',
                'inactive': 'Inactive',
                'graduating': 'Graduating',
                'archived': 'Archived'
            };
            return statusMap[status] || status;
        }

        // --- Export Functions ---
        function csvEscape(value) {
            if (value === null || value === undefined) return '';
            const str = String(value);
            if (/[",\n]/.test(str)) {
                return '"' + str.replace(/"/g, '""') + '"';
            }
            return str;
        }

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

        async function getFilteredStudentsForExport() {
            try {
                const filter = filterSelect ? filterSelect.value : 'all';
                const search = searchInput ? searchInput.value : '';
                const department = deptFilterSelect ? deptFilterSelect.value : 'all';
                const section = sectionFilterSelect ? sectionFilterSelect.value : 'all';
                
                let url = `${apiBase}?action=get&filter=${filter}&limit=all&department=${encodeURIComponent(department)}&section=${encodeURIComponent(section)}`;
                if (search) {
                    url += `&search=${encodeURIComponent(search)}`;
                }
                
                const response = await fetch(url);
                if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
                
                const result = await response.json();
                if (result.status === 'success') {
                    return result.data.students || [];
                }
                return [];
            } catch (error) {
                console.error('Error fetching students for export:', error);
                return [];
            }
        }

        async function downloadStudentsPDF() {
            if (!window.jspdf) {
                if (typeof showNotification === 'function') {
                    showNotification('PDF library not loaded. Please refresh.', 'warning');
                } else {
                    console.warn('PDF library not loaded. Please refresh the page.');
                }
                return;
            }

            // Show loading state
            const exportPDFBtn = document.getElementById('exportPDF');
            const originalText = exportPDFBtn.innerHTML;
            exportPDFBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing PDF...</span>";
            exportPDFBtn.disabled = true;

            try {
                const exportStudents = await getFilteredStudentsForExport();
                
                if (exportStudents.length === 0) {
                    showError('No student records found to export.');
                    return;
                }

                const { jsPDF } = window.jspdf;
                const doc = new jsPDF();
                const now = new Date();
                
                // --- Header Design ---
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);

                if (headerData) {
                    // Reduce width to 140mm (from 180mm) to fix stretching, height to 25mm
                    // Shift slightly right (38mm) to align visually with centered title
                    doc.addImage(headerData, 'PNG', 38, 5, 140, 25);
                } else {
                    // Fallback header if image fails to load
                    doc.setFontSize(22);
                    doc.setTextColor(44, 62, 80);
                    doc.setFont("helvetica", "bold");
                    doc.text("E-OSAS SYSTEM", 14, 20);
                    
                    doc.setFontSize(10);
                    doc.setFont("helvetica", "normal");
                    doc.setTextColor(127, 140, 141);
                    doc.text("Office of Student Affairs and Services", 14, 28);
                }

                // Report Title & Date (Positioned below the header image)
                doc.setFontSize(12); // Reduced from 14
                doc.setTextColor(41, 128, 185); 
                doc.setFont("helvetica", "bold");
                doc.text("STUDENT LIST REPORT", 105, 38, { align: 'center' });

                doc.setFontSize(8); // Reduced from 9
                doc.setTextColor(100, 100, 100);
                doc.setFont("helvetica", "normal");
                doc.text(`Generated on: ${now.toLocaleDateString()} ${now.toLocaleTimeString()}`, 105, 43, { align: 'center' });
                doc.text(`Exported by: ${getCurrentAdminName()}`, 105, 47, { align: 'center' });

                // Divider Line
                doc.setDrawColor(220, 220, 220);
                doc.setLineWidth(0.5);
                doc.line(14, 52, 196, 52);
                
                // Summary Stats
                doc.setFontSize(10);
                doc.setTextColor(60, 60, 60);
                doc.text(`Total Records: ${exportStudents.length}`, 14, 62);
                
                let startY = 67;

                // Table
                const tableColumn = ["ID", "Student ID", "Name", "Dept", "Section", "Year Level", "Contact No", "Status"];
                const tableRows = [];

                exportStudents.forEach(s => {
                    const fullName = `${s.firstName || ''} ${s.middleName ? s.middleName + ' ' : ''}${s.lastName || ''}`;
                    const rowData = [
                        s.id,
                        s.studentId,
                        fullName,
                        s.department || 'N/A',
                        s.section || 'N/A',
                        s.yearlevel || 'N/A',
                        s.contact || 'N/A',
                        formatStatus(s.status || 'active')
                    ];
                    tableRows.push(rowData);
                });

                doc.autoTable({
                    head: [tableColumn],
                    body: tableRows,
                    startY: startY,
                    theme: 'grid',
                    styles: { fontSize: 7, cellPadding: 2, valign: 'middle' },
                    headStyles: { 
                        fillColor: [245, 245, 245], 
                        textColor: [44, 62, 80], 
                        fontStyle: 'bold',
                        lineWidth: 0.1,
                        lineColor: [200, 200, 200]
                    },
                    alternateRowStyles: { fillColor: [255, 255, 255] },
                    margin: { top: 60 }
                });

                doc.save(`Student_List_${now.toISOString().slice(0, 10)}.pdf`);
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            } finally {
                exportPDFBtn.innerHTML = originalText;
                exportPDFBtn.disabled = false;
            }
        }

        async function downloadStudentsExcel() {
            // Show loading state
            const exportExcelBtn = document.getElementById('exportExcel');
            const originalText = exportExcelBtn.innerHTML;
            exportExcelBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing Excel...</span>";
            exportExcelBtn.disabled = true;

            try {
                const exportStudents = await getFilteredStudentsForExport();
                
                if (exportStudents.length === 0) {
                    showError('No student records found to export.');
                    return;
                }

                const now = new Date();
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);

                // Create HTML Table for Excel with Header Image
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
                        <table width="1330" style="width: 1330px; border-collapse: collapse;">
                            ${headerData ? `
                            <tr height="100" style="height: 100px;">
                                <td colspan="11" width="1330" align="center" valign="middle" style="width: 1330px; text-align: center; vertical-align: middle;">
                                    <center>
                                        <div align="center" style="text-align: center;">
                                            <p align="center" style="text-align: center; margin: 0; padding: 0;">
                                                <img src="${headerData}" width="400" height="80" border="0" style="display: inline-block;">
                                            </p>
                                        </div>
                                    </center>
                                </td>
                            </tr>` : ''}
                            <tr><td colspan="11" class="title" align="center" style="text-align: center;">STUDENT LIST REPORT</td></tr>
                            <tr><td colspan="11" class="subtitle" align="center" style="text-align: center;">Office of Student Affairs and Services</td></tr>
                            <tr><td colspan="11" class="stats" align="center" style="text-align: center;">Generated on: ${now.toLocaleString()}</td></tr>
                            <tr><td colspan="11" class="stats" align="center" style="text-align: center;">Exported by: ${getCurrentAdminName()}</td></tr>
                            <tr><td colspan="11" class="stats" align="center" style="text-align: center;">Total Records: ${exportStudents.length}</td></tr>
                            <tr><td colspan="11" style="height: 20px;"></td></tr>
                            <tr class="data-table">
                                <th width="40" style="width: 40px; background-color: #e0e0e0; border: 0.5pt solid #000;">ID</th>
                                <th width="100" style="width: 100px; background-color: #e0e0e0; border: 0.5pt solid #000;">Student ID</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">First Name</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Middle Name</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Last Name</th>
                                <th width="200" style="width: 200px; background-color: #e0e0e0; border: 0.5pt solid #000;">Email</th>
                                <th width="250" style="width: 250px; background-color: #e0e0e0; border: 0.5pt solid #000;">Department</th>
                                <th width="80" style="width: 80px; background-color: #e0e0e0; border: 0.5pt solid #000;">Section</th>
                                <th width="100" style="width: 100px; background-color: #e0e0e0; border: 0.5pt solid #000;">Year Level</th>
                                <th width="120" style="width: 120px; background-color: #e0e0e0; border: 0.5pt solid #000;">Contact No</th>
                                <th width="80" style="width: 80px; background-color: #e0e0e0; border: 0.5pt solid #000;">Status</th>
                            </tr>
                `;

                exportStudents.forEach(s => {
                    html += `
                        <tr>
                            <td>${s.id}</td>
                            <td>${s.studentId || ''}</td>
                            <td>${s.firstName || ''}</td>
                            <td>${s.middleName || ''}</td>
                            <td>${s.lastName || ''}</td>
                            <td>${s.email || ''}</td>
                            <td>${s.department || ''}</td>
                            <td>${s.section || ''}</td>
                            <td>${s.yearlevel || ''}</td>
                            <td>${s.contact || ''}</td>
                            <td>${formatStatus(s.status)}</td>
                        </tr>
                    `;
                });

                html += `
                        </table>
                    </body>
                    </html>
                `;

                const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
                const fileName = 'students_export_' + now.toISOString().slice(0, 10) + '.xls';
                
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
                showError('Failed to generate Excel document.');
            } finally {
                exportExcelBtn.innerHTML = originalText;
                exportExcelBtn.disabled = false;
            }
        }

        async function downloadStudentsWord() {
            if (!window.docx) {
                if (typeof showNotification === 'function') {
                    showNotification('DOCX library not loaded. Please refresh.', 'warning');
                } else {
                    console.warn('DOCX library not loaded. Please refresh the page.');
                }
                return;
            }

            // Show loading state
            const exportWordBtn = document.getElementById('exportWord');
            const originalText = exportWordBtn.innerHTML;
            exportWordBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i><span>Preparing Word...</span>";
            exportWordBtn.disabled = true;

            try {
                const exportStudents = await getFilteredStudentsForExport();
                
                if (exportStudents.length === 0) {
                    showError('No student records found to export.');
                    return;
                }

                const { Document, Packer, Paragraph, Table, TableCell, TableRow, WidthType, HeadingLevel, TextRun, AlignmentType, ImageRun } = window.docx;
                const now = new Date();
                
                const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
                const headerData = await loadImage(headerPath);
                
                // Table Header
                const tableHeader = new TableRow({
                    children: [
                        "ID", "Student ID", "Name", "Dept", "Section", "Year Level", "Contact No", "Status"
                    ].map(text => new TableCell({
                        children: [new Paragraph({ text, bold: true, size: 20 })], 
                        width: { size: 100 / 8, type: WidthType.PERCENTAGE },
                        shading: { fill: "E0E0E0" }
                    }))
                });
                
                // Table Rows
                const tableRows = exportStudents.map(s => {
                    const fullName = `${s.firstName || ''} ${s.middleName ? s.middleName + ' ' : ''}${s.lastName || ''}`;
                    return new TableRow({
                        children: [
                            String(s.id),
                            s.studentId || "",
                            fullName,
                            s.department || "N/A",
                            s.section || "N/A",
                            s.yearlevel || "N/A",
                            s.contact || "N/A",
                            formatStatus(s.status || "active")
                        ].map(text => new TableCell({
                            children: [new Paragraph({ text: text || "", size: 16 })],
                            width: { size: 100 / 8, type: WidthType.PERCENTAGE }
                        }))
                    });
                });

                const docChildren = [];
                
                // Add Header Image if available
                if (headerData) {
                    docChildren.push(new Paragraph({
                        children: [
                            new ImageRun({
                                data: headerData,
                                transformation: {
                                    width: 400, // Reduced from 500
                                    height: 80, // Reduced from 100
                                },
                            }),
                        ],
                        alignment: AlignmentType.CENTER,
                    }));
                }

                docChildren.push(
                     new Paragraph({
                         text: "STUDENT LIST REPORT",
                         heading: HeadingLevel.HEADING_2, // Reduced from HEADING_1
                         alignment: AlignmentType.CENTER,
                         spacing: { before: 200 }
                     }),
                     new Paragraph({
                         children: [
                             new TextRun({
                                 text: `Office of Student Affairs and Services`,
                                 italics: true,
                                 color: "666666",
                                 size: 18, // Added size (9pt)
                             })
                         ],
                         alignment: AlignmentType.CENTER
                     }),
                     new Paragraph({
                         children: [
                             new TextRun({
                                 text: `Generated: ${now.toLocaleString()}`,
                                 italics: true,
                                 color: "999999",
                                 size: 16, // Added size (8pt)
                             })
                         ],
                         alignment: AlignmentType.CENTER,
                     }),
                     new Paragraph({
                         children: [
                             new TextRun({
                                 text: `Exported by: ${getCurrentAdminName()}`,
                                 italics: true,
                                 color: "999999",
                                 size: 16,
                             })
                         ],
                         alignment: AlignmentType.CENTER,
                         spacing: { after: 400 }
                     }),
                    new Paragraph({
                        text: `Total Records: ${exportStudents.length}`,
                        spacing: { after: 200 }
                    }),
                    new Table({
                        rows: [tableHeader, ...tableRows],
                        width: { size: 100, type: WidthType.PERCENTAGE }
                    })
                );

                const doc = new Document({
                    sections: [{
                        properties: {},
                        children: docChildren
                    }]
                });

                const blob = await Packer.toBlob(doc);
                if (typeof saveAs === 'function') {
                    saveAs(blob, `Student_List_${now.toISOString().slice(0, 10)}.docx`);
                } else {
                    console.error('FileSaver.js not loaded');
                    showError('Error: FileSaver.js not loaded');
                }
                
                if (exportModal) exportModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            } catch (error) {
                console.error('Word export error:', error);
                showError('Failed to generate Word document.');
            } finally {
                exportWordBtn.innerHTML = originalText;
                exportWordBtn.disabled = false;
            }
        }

        function updateCounts(filteredStudents) {
            const showingEl = document.getElementById('showingStudentsCount');
            const totalCountEl = document.getElementById('totalStudentsCount');
            
            if (showingEl) showingEl.textContent = filteredStudents.length;
            if (totalCountEl) totalCountEl.textContent = totalRecords;
        }

        // --- Modal functions ---
        async function openModal(editId = null) {
            if (!modal) return;
            
            const modalTitle = document.getElementById('StudentsModalTitle');
            const form = document.getElementById('StudentsForm');
            
            editingStudentId = editId;
            
            // Load departments every time modal opens
            await loadDepartments();
            
            if (editId) {
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Edit Student';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-group\'></i><span>Edit Student</span>';
                }
                const student = allStudents.find(s => s.id === editId);
                if (student) {
                    document.getElementById('studentId').value = student.studentId || '';
                    document.getElementById('studentStatus').value = student.status || 'active';
                    document.getElementById('firstName').value = student.firstName || '';
                    document.getElementById('middleName').value = student.middleName || '';
                    document.getElementById('lastName').value = student.lastName || '';
                    document.getElementById('studentEmail').value = student.email || '';
                    document.getElementById('studentContact').value = student.contact || '';
                    document.getElementById('studentDept').value = student.department || '';
                    document.getElementById('studentAddress').value = student.address || '';
                    document.getElementById('studentYearlevel').value = student.yearlevel || '';
                    
                    // Load sections for the department
                    if (student.department) {
                        await loadSectionsByDepartment(student.department);
                        if (student.section_id) {
                            document.getElementById('studentSection').value = student.section_id;
                        }
                    }
                    
                    // Set image preview if avatar exists
                    if (student.avatar && student.avatar !== '') {
                        const previewImg = document.querySelector('.Students-preview-img');
                        const previewPlaceholder = document.querySelector('.Students-preview-placeholder');
                        if (previewImg && previewPlaceholder) {
                            // Build the correct avatar URL
                            let avatarUrl = student.avatar;
                            // If it's a relative path, make it absolute
                            if (!avatarUrl.startsWith('http') && !avatarUrl.startsWith('data:') && !avatarUrl.startsWith('/')) {
                                // It's a relative path like 'assets/img/students/filename.jpg' or 'app/assets/img/students/filename.jpg'
                                // Normalize to app/assets/ if needed
                                if (avatarUrl.startsWith('assets/') && !avatarUrl.startsWith('app/assets/')) {
                                    avatarUrl = avatarUrl.replace('assets/', 'app/assets/');
                                }
                                // Convert to absolute path from project root
                                const pathMatch = window.location.pathname.match(/^(\/[^\/]+)\//);
                                const projectBase = pathMatch ? pathMatch[1] : '';
                                avatarUrl = projectBase + '/' + avatarUrl;
                            }
                            previewImg.src = avatarUrl;
                            previewImg.setAttribute('data-existing-avatar', student.avatar); // Store original path
                            previewImg.style.display = 'block';
                            previewPlaceholder.style.display = 'none';
                        }
                    }
                }
            } else {
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Add New Student';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-group\'></i><span>Add New Student</span>';
                }
                if (form) form.reset();
                // Reset image preview
                const previewImg = document.querySelector('.Students-preview-img');
                const previewPlaceholder = document.querySelector('.Students-preview-placeholder');
                if (previewImg && previewPlaceholder) {
                    previewImg.style.display = 'none';
                    previewImg.src = '';
                    previewImg.removeAttribute('data-existing-avatar');
                    previewPlaceholder.style.display = 'flex';
                }
                // Reset image input
                const studentImageInput = document.getElementById('studentImage');
                if (studentImageInput) {
                    studentImageInput.value = '';
                }
                // Reset section dropdown
                if (studentSectionSelect) {
                    studentSectionSelect.innerHTML = '<option value="">Select Department First</option>';
                }
            }
            
            modal.classList.add('active');
            document.body.style.overflow = 'hidden';
        }

        function openProfileModal(student) {
            const profileModal = document.getElementById('StudentProfileModal');
            if (!profileModal) return;

            // Fill details
            const fullName = `${student.firstName} ${student.middleName ? student.middleName + ' ' : ''}${student.lastName}`;
            document.getElementById('profileFullName').textContent = fullName;
            document.getElementById('profileId').textContent = student.studentId || 'N/A';
            document.getElementById('profileDept').textContent = student.department || 'N/A';
            document.getElementById('profileSection').textContent = student.section || 'N/A';
            document.getElementById('profileYear').textContent = student.yearlevel || 'N/A';
            document.getElementById('profileEmail').textContent = student.email || 'N/A';
            document.getElementById('profileContact').textContent = student.contact || 'N/A';
            document.getElementById('profileDate').textContent = student.date || 'N/A';
            document.getElementById('profileAddress').textContent = student.address || 'No address provided.';
            
            // Avatar
            const avatarImg = document.getElementById('profileAvatar');
            if (avatarImg) {
                avatarImg.src = student.avatar || '../app/assets/img/default.png';
            }

            // Status Badge
            const statusBadge = document.getElementById('profileStatusBadge');
            if (statusBadge) {
                const status = student.status || 'active';
                statusBadge.className = `status-badge ${status.toLowerCase()}`;
                statusBadge.textContent = status.charAt(0).toUpperCase() + status.slice(1);
            }

            profileModal.classList.add('active');
            document.body.style.overflow = 'hidden';
        }

        function closeProfileModal() {
            const profileModal = document.getElementById('StudentProfileModal');
            if (profileModal) {
                profileModal.classList.remove('active');
                document.body.style.overflow = 'auto';
            }
        }

        function closeModal() {
            if (!modal) return;
            
            modal.classList.remove('active');
            document.body.style.overflow = 'auto';
            const form = document.getElementById('StudentsForm');
            if (form) form.reset();
            // Reset image preview
            const previewImg = document.querySelector('.Students-preview-img');
            const previewPlaceholder = document.querySelector('.Students-preview-placeholder');
            if (previewImg && previewPlaceholder) {
                previewImg.style.display = 'none';
                previewImg.src = '';
                previewImg.removeAttribute('data-existing-avatar');
                previewPlaceholder.style.display = 'flex';
            }
            // Reset image input
            const studentImageInput = document.getElementById('studentImage');
            if (studentImageInput) {
                studentImageInput.value = '';
            }
            editingStudentId = null;
        }

        // --- Event handlers ---
        function handleTableClick(e) {
            const viewBtn = e.target.closest('.Students-action-btn.view');
            const editBtn = e.target.closest('.Students-action-btn.edit');
            const deleteBtn = e.target.closest('.Students-action-btn.delete');
            const restoreBtn = e.target.closest('.Students-action-btn.restore');

            if (viewBtn) {
                const id = parseInt(viewBtn.dataset.id);
                const student = allStudents.find(s => s.id === id);
                if (student) {
                    openProfileModal(student);
                }
            }

            if (editBtn) {
                const id = parseInt(editBtn.dataset.id);
                openModal(id);
            }

            if (deleteBtn) {
                const id = parseInt(deleteBtn.dataset.id);
                const student = allStudents.find(s => s.id === id);
                if (student) {
                    if (student.status && student.status.toLowerCase() === 'archived') {
                        showModernAlert({
                            title: 'Permanent Delete',
                            message: `Permanently delete student "${student.firstName} ${student.lastName}"? This action cannot be undone.`,
                            icon: 'error',
                            confirmText: 'Delete Permanently'
                        }).then(confirmed => {
                            if (confirmed) deleteStudent(id);
                        });
                    } else {
                        showModernAlert({
                            title: 'Archive Student',
                            message: `Archive student "${student.firstName} ${student.lastName}"? This will move them to the archived list.`,
                            icon: 'warning',
                            confirmText: 'Yes, Archive'
                        }).then(confirmed => {
                            if (confirmed) deleteStudent(id);
                        });
                    }
                }
            }

            if (restoreBtn) {
                const id = parseInt(restoreBtn.dataset.id);
                const student = allStudents.find(s => s.id === id);
                if (student) {
                    showModernAlert({
                        title: 'Restore Student',
                        message: `Restore student "${student.firstName} ${student.lastName}" to active status?`,
                        icon: 'info',
                        confirmText: 'Yes, Restore'
                    }).then(confirmed => {
                        if (confirmed) restoreStudent(id);
                    });
                }
            }
        }

        // Utility functions
        function showError(message) {
            if (window.showNotification && typeof window.showNotification === 'function') {
                window.showNotification(message, 'error');
            } else if (typeof showNotification === 'function') {
                showNotification(message, 'error');
            } else {
                console.error(message);
            }
        }

        function showSuccess(message) {
            if (window.showNotification && typeof window.showNotification === 'function') {
                window.showNotification(message, 'success');
            } else if (typeof showNotification === 'function') {
                showNotification(message, 'success');
            } else {
                console.log(message);
            }
        }

        // --- Initialize ---
        async function initialize() {
            // Set default view to active (hide archived by default)
            currentView = 'active';
            if (filterSelect) {
                filterSelect.value = 'active';
            }

            // Load filters
            await loadFilterDepartments();

            // Initial load - only active students
            await fetchStudents();

            // Search functionality with debounce and page reset
            if (searchInput) {
                let searchTimeout;
                searchInput.addEventListener('input', () => {
                    clearTimeout(searchTimeout);
                    searchTimeout = setTimeout(() => {
                        currentPage = 1;
                        fetchStudents();
                    }, 500);
                });
            }

            // Filter change resets page and fetches
            if (filterSelect) {
                filterSelect.addEventListener('change', () => {
                    // Sync currentView with filter selection
                     if (filterSelect.value === 'archived') {
                         currentView = 'archived';
                         if (btnArchivedStudents) {
                             btnArchivedStudents.classList.add('active');
                             btnArchivedStudents.innerHTML = "<i class='bx bx-check-circle'></i><span>Show Active</span>";
                         }
                         if (btnAddStudent) btnAddStudent.style.display = 'none';
                     } else {
                         currentView = 'active';
                         if (btnArchivedStudents) {
                             btnArchivedStudents.classList.remove('active');
                             btnArchivedStudents.innerHTML = "<i class='bx bx-archive'></i><span>Archived</span>";
                         }
                         if (btnAddStudent) btnAddStudent.style.display = 'inline-flex';
                     }
                    currentPage = 1;
                    fetchStudents();
                });
            }

            // Department filter listener
            if (deptFilterSelect) {
                deptFilterSelect.addEventListener('change', async () => {
                    const deptCode = deptFilterSelect.value;
                    
                    // Reset section filter when department changes
                    if (sectionFilterSelect) {
                        sectionFilterSelect.innerHTML = '<option value="all">All Sections</option>';
                        sectionFilterSelect.value = 'all';
                    }
                    
                    if (deptCode !== 'all') {
                        await loadFilterSections(deptCode);
                    }
                    
                    currentPage = 1;
                    fetchStudents();
                });
            }

            // Section filter listener
            if (sectionFilterSelect) {
                sectionFilterSelect.addEventListener('change', () => {
                    currentPage = 1;
                    fetchStudents();
                });
            }

            // Event listeners for table
            tableBody.addEventListener('click', handleTableClick);

            // Add Student button
            if (btnAddStudent) {
                btnAddStudent.addEventListener('click', () => openModal());
            }

            // Archived Students button (Control Bar)
            if (btnArchivedStudents) {
                btnArchivedStudents.addEventListener('click', function() {
                    const isArchived = currentView === 'archived';
                    
                    if (isArchived) {
                        // Switch back to active
                        currentView = 'active';
                        this.classList.remove('active');
                        this.innerHTML = "<i class='bx bx-archive'></i><span>Archived</span>";
                        if (filterSelect) filterSelect.value = 'active';
                        if (btnAddStudent) btnAddStudent.style.display = 'inline-flex';
                    } else {
                        // Switch to archived
                        currentView = 'archived';
                        this.classList.add('active');
                        this.innerHTML = "<i class='bx bx-check-circle'></i><span>Show Active</span>";
                        if (filterSelect) filterSelect.value = 'archived';
                        if (btnAddStudent) btnAddStudent.style.display = 'none';
                    }
                    
                    currentPage = 1;
                    fetchStudents();
                });
            }

            // Export Students button
            if (exportBtn) {
                exportBtn.addEventListener('click', () => {
                    if (exportModal) {
                        exportModal.classList.add('active');
                        document.body.style.overflow = 'hidden';
                    }
                });
            }

            // Delete All Students button
            if (btnDeleteAllStudents) {
                btnDeleteAllStudents.addEventListener('click', async () => {
                    const confirmed = await showModernAlert({
                        title: 'Delete All Students',
                        message: 'Are you sure you want to delete ALL students and their associated user accounts? This action CANNOT be undone.',
                        icon: 'error',
                        confirmText: 'Yes, Delete Everything',
                        cancelText: 'Cancel'
                    });

                    if (confirmed) {
                        try {
                            const response = await fetch(`${apiBase}?action=deleteAll`, {
                                method: 'POST'
                            });
                            const result = await response.json();
                            
                            if (result.status === 'success') {
                                showSuccess('All student records have been cleared.');
                                currentPage = 1;
                                fetchStudents();
                            } else {
                                showError(result.message || 'Failed to delete all students.');
                            }
                        } catch (error) {
                            console.error('Error deleting all students:', error);
                            showError('A connection error occurred. Please try again.');
                        }
                    }
                });
            }

            // --- Import Logic ---
            const importModal = document.getElementById('ImportStudentsModal');
            const importForm = document.getElementById('ImportStudentsForm');
            const fileInput = document.getElementById('enrollmentList');
            const dropZone = document.getElementById('dropZone');
            const selectedFileName = document.getElementById('selectedFileName');
            const submitImportBtn = document.getElementById('submitImportBtn');
            const closeImportBtn = document.getElementById('closeImportModal');
            const cancelImportBtn = document.getElementById('cancelImportBtn');
            const importModalOverlay = document.getElementById('ImportModalOverlay');
            const assetFilesList = document.getElementById('AssetFilesList');
            let droppedFile = null;

            async function fetchAssets() {
                if (!assetFilesList) return;
                
                assetFilesList.innerHTML = '<div style="padding: 15px; text-align: center; color: #999;"><i class="bx bx-loader-alt bx-spin"></i> Loading assets...</div>';
                
                try {
                    const response = await fetch(`${apiBase}?action=listAssets`);
                    const result = await response.json();
                    
                    if (result.status === 'success' && result.data.length > 0) {
                        assetFilesList.innerHTML = result.data.map(file => `
                            <div class="asset-file-item" style="padding: 12px 15px; border-bottom: 1px solid #f5f5f5; display: flex; align-items: center; justify-content: space-between; cursor: pointer; transition: background 0.2s;" onclick="syncFromAsset('${file.name}')">
                                <div style="display: flex; align-items: center;">
                                    <i class='bx bxs-file-${file.name.endsWith('csv') ? 'blank' : 'export'}' style="font-size: 24px; color: ${file.name.endsWith('csv') ? '#3498db' : '#27ae60'}; margin-right: 12px;"></i>
                                    <div>
                                        <div style="font-weight: 600; font-size: 0.9rem; color: #333;">${file.name}</div>
                                        <div style="font-size: 0.75rem; color: #999;">${file.size} • Modified: ${file.modified}</div>
                                    </div>
                                </div>
                                <i class='bx bx-sync' style="font-size: 18px; color: var(--gold);"></i>
                            </div>
                        `).join('');
                        
                        // Hover effect
                        const items = assetFilesList.querySelectorAll('.asset-file-item');
                        items.forEach(item => {
                            item.onmouseover = () => item.style.background = '#fff9e6';
                            item.onmouseout = () => item.style.background = 'transparent';
                        });
                    } else {
                        assetFilesList.innerHTML = '<div style="padding: 20px; text-align: center; color: #999;">No compatible files found in assets.</div>';
                    }
                } catch (error) {
                    console.error('Error fetching assets:', error);
                    assetFilesList.innerHTML = '<div style="padding: 20px; text-align: center; color: #e74c3c;">Failed to load assets.</div>';
                }
            }

            // Global function for asset sync
            window.syncFromAsset = async function(filename) {
                const confirmed = await showModernAlert({
                    title: 'Sync from Asset',
                    message: `Sync student data using "${filename}"?`,
                    confirmText: 'Yes, Sync Now',
                    cancelText: 'Cancel'
                });

                if (!confirmed) return;

                closeImportModal();
                
                showModernAlert({
                    title: 'Synchronizing...',
                    message: `Processing "${filename}"...`,
                    icon: 'loading',
                    showCancel: false,
                    confirmText: 'Processing...'
                });

                try {
                    const response = await fetch(`${apiBase}?action=importFromAsset&filename=${encodeURIComponent(filename)}`);
                    const result = await response.json();

                    if (result.status === 'success') {
                        const { created, updated, skipped } = result.data;
                        await showModernAlert({
                            title: 'Sync Successful',
                            message: 'Student database updated.',
                            icon: 'success',
                            showCancel: false,
                            confirmText: 'Done',
                            stats: { created, updated, skipped }
                        });
                        fetchStudents();
                    } else {
                        await showModernAlert({
                            title: 'Sync Failed',
                            message: result.message || 'Error occurred during sync.',
                            icon: 'error',
                            showCancel: false,
                            confirmText: 'Dismiss'
                        });
                    }
                } catch (error) {
                    console.error('Sync error:', error);
                    showError('Connection error during sync.');
                }
            };

            function openImportModal() {
                if (importModal) {
                    importModal.classList.add('active');
                    document.body.style.overflow = 'hidden';
                    fetchAssets(); // Refresh assets
                }
            }

            function closeImportModal() {
                if (importModal) {
                    importModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                    if (importForm) importForm.reset();
                    droppedFile = null; // Clear dropped file
                    if (selectedFileName) {
                        selectedFileName.textContent = '';
                        selectedFileName.style.display = 'none';
                    }
                    if (submitImportBtn) submitImportBtn.disabled = true;
                    // Reset drop zone
                    if (dropZone) {
                        dropZone.style.borderColor = '#ddd';
                        dropZone.querySelector('i').style.color = '#aaa';
                    }
                }
            }

            if (importBtn) {
                importBtn.addEventListener('click', openImportModal);
            }

            if (closeImportBtn) closeImportBtn.addEventListener('click', closeImportModal);
            if (cancelImportBtn) cancelImportBtn.addEventListener('click', closeImportModal);
            if (importModalOverlay) importModalOverlay.addEventListener('click', closeImportModal);

            if (dropZone) {
                dropZone.addEventListener('click', () => fileInput && fileInput.click());
                
                dropZone.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    dropZone.style.borderColor = 'var(--gold)';
                    dropZone.querySelector('i').style.color = 'var(--gold)';
                });

                dropZone.addEventListener('dragleave', () => {
                    dropZone.style.borderColor = '#ddd';
                    dropZone.querySelector('i').style.color = '#aaa';
                });

                dropZone.addEventListener('drop', (e) => {
                    e.preventDefault();
                    const files = e.dataTransfer.files;
                    if (files.length > 0) {
                        droppedFile = files[0]; // Store in variable
                        handleFileSelection(droppedFile);
                    }
                });
            }

            if (fileInput) {
                fileInput.addEventListener('change', () => {
                    if (fileInput.files.length > 0) {
                        droppedFile = null; // Reset dropped file if manual choice
                        handleFileSelection(fileInput.files[0]);
                    }
                });
            }

            function handleFileSelection(file) {
                const ext = file.name.split('.').pop().toLowerCase();
                if (['csv', 'xlsx', 'xls'].includes(ext)) {
                    selectedFileName.textContent = `Selected: ${file.name}`;
                    selectedFileName.style.display = 'block';
                    submitImportBtn.disabled = false;
                    dropZone.style.borderColor = '#27ae60';
                    dropZone.querySelector('i').style.color = '#27ae60';
                } else {
                    showError('Please select a valid CSV or Excel file.');
                    submitImportBtn.disabled = true;
                    selectedFileName.style.display = 'none';
                }
            }

            if (importForm) {
                importForm.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    
                    // 1. Get the file BEFORE closing the modal
                    const fileToUpload = droppedFile || (fileInput.files.length > 0 ? fileInput.files[0] : null);
                    
                    if (!fileToUpload) {
                        showError('No file selected. Please select a file first.');
                        return;
                    }

                    const confirmed = await showModernAlert({
                        title: 'Confirm Import',
                        message: 'Sync students with the selected file?',
                        confirmText: 'Yes, Start Import',
                        cancelText: 'Cancel'
                    });

                    if (!confirmed) return;

                    // 2. Now we can safely close the modal and reset it
                    closeImportModal();
                    
                    showModernAlert({
                        title: 'Importing...',
                        message: 'Processing file...',
                        icon: 'loading',
                        showCancel: false,
                        confirmText: 'Processing...'
                    });

                    try {
                        const formData = new FormData();
                        formData.append('enrollmentList', fileToUpload);
                        
                        const response = await fetch(`${apiBase}?action=import`, {
                            method: 'POST',
                            body: formData
                        });
                        
                        const result = await response.json();

                        if (result.status === 'success') {
                            const { created, updated, skipped } = result.data;
                            await showModernAlert({
                                title: 'Import Successful',
                                message: 'Synchronization complete.',
                                icon: 'success',
                                showCancel: false,
                                confirmText: 'Great!',
                                stats: { created, updated, skipped }
                            });
                            fetchStudents();
                        } else {
                            await showModernAlert({
                                title: 'Import Failed',
                                message: result.message || 'Error processing file.',
                                icon: 'error',
                                showCancel: false,
                                confirmText: 'Try Again'
                            });
                        }
                    } catch (error) {
                        console.error('Import error:', error);
                        await showModernAlert({
                            title: 'Error',
                            message: error.message || 'Connection error.',
                            icon: 'error',
                            showCancel: false,
                            confirmText: 'Dismiss'
                        });
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
                    await downloadStudentsPDF();
                });
            }

            if (exportExcelBtn) {
                exportExcelBtn.addEventListener('click', async () => {
                    await downloadStudentsExcel();
                });
            }

            if (exportWordBtn) {
                exportWordBtn.addEventListener('click', async () => {
                    await downloadStudentsWord();
                });
            }

            // Add First Student button
            if (btnAddFirstStudent) {
                btnAddFirstStudent.addEventListener('click', () => openModal());
            }

            // Close modal
            if (closeBtn) closeBtn.addEventListener('click', closeModal);
            if (cancelBtn) cancelBtn.addEventListener('click', closeModal);
            if (modalOverlay) modalOverlay.addEventListener('click', closeModal);

            // Profile Modal close listeners
            const closeProfileModalBtn = document.getElementById('closeProfileModal');
            const closeProfileBtn = document.getElementById('closeProfileBtn');
            const profileModalOverlay = document.getElementById('ProfileModalOverlay');

            if (closeProfileModalBtn) closeProfileModalBtn.addEventListener('click', closeProfileModal);
            if (closeProfileBtn) closeProfileBtn.addEventListener('click', closeProfileModal);
            if (profileModalOverlay) profileModalOverlay.addEventListener('click', closeProfileModal);

            // Escape key to close modals
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    if (modal && modal.classList.contains('active')) {
                        closeModal();
                    }
                    const profileModal = document.getElementById('StudentProfileModal');
                    if (profileModal && profileModal.classList.contains('active')) {
                        closeProfileModal();
                    }
                }
            });

            // Image upload preview
            const studentImageInput = document.getElementById('studentImage');
            const uploadImageBtn = document.getElementById('uploadImageBtn');
            const previewImg = document.querySelector('.Students-preview-img');
            const previewPlaceholder = document.querySelector('.Students-preview-placeholder');

            if (uploadImageBtn) {
                uploadImageBtn.addEventListener('click', () => {
                    if (studentImageInput) studentImageInput.click();
                });
            }

            if (studentImageInput && previewImg && previewPlaceholder) {
                studentImageInput.addEventListener('change', function() {
                    const file = this.files[0];
                    if (file) {
                        const reader = new FileReader();
                        reader.onload = function(e) {
                            previewImg.src = e.target.result;
                            previewImg.style.display = 'block';
                            previewPlaceholder.style.display = 'none';
                        };
                        reader.readAsDataURL(file);
                    }
                });
            }

            // Department change - load sections
            if (studentDeptSelect) {
                studentDeptSelect.addEventListener('change', function() {
                    const deptCode = this.value;
                    if (deptCode) {
                        loadSectionsByDepartment(deptCode);
                    } else {
                        if (studentSectionSelect) {
                            studentSectionSelect.innerHTML = '<option value="">Select Department First</option>';
                        }
                    }
                });
            }

            // Form submission
            if (studentsForm) {
                studentsForm.addEventListener('submit', async function(e) {
                    e.preventDefault();

                    // Modern validation with highlighting
                    if (!validateStudentForm()) {
                        return;
                    }

                    const studentIdCode = (document.getElementById('studentId')?.value || '').trim();
                    const formData = new FormData(studentsForm);

                    // Ensure backend gets the expected student ID field
                    formData.set('studentIdCode', studentIdCode);

                    // Preserve existing avatar on update if no new image is selected
                    const studentImageInput = document.getElementById('studentImage');
                    const hasNewImage = !!(studentImageInput && studentImageInput.files && studentImageInput.files.length > 0);
                    if (!hasNewImage) {
                        const previewImg = document.querySelector('.Students-preview-img');
                        const existingAvatar = previewImg ? previewImg.getAttribute('data-existing-avatar') : '';
                        if (existingAvatar) {
                            formData.set('studentAvatar', existingAvatar);
                        }
                    }

                    if (editingStudentId) {
                        // Avoid conflicting with the form's studentId field by using `id` for DB id
                        formData.set('id', editingStudentId);
                        await updateStudent(editingStudentId, formData);
                    } else {
                        await addStudent(formData);
                    }
                });
            }

            // Sort functionality
            const sortHeaders = document.querySelectorAll('.Students-sortable');
            sortHeaders.forEach(header => {
                header.addEventListener('click', function() {
                    const sortBy = this.dataset.sort;
                    sortStudents(sortBy);
                });
            });

            function sortStudents(sortBy) {
                students.sort((a, b) => {
                    switch(sortBy) {
                        case 'name':
                            const nameA = `${a.firstName} ${a.lastName}`.toLowerCase();
                            const nameB = `${b.firstName} ${b.lastName}`.toLowerCase();
                            return nameA.localeCompare(nameB);
                        case 'studentId':
                            return (a.studentId || '').localeCompare(b.studentId || '');
                        case 'department':
                            return (a.department || '').localeCompare(b.department || '');
                        case 'section':
                            return (a.section || '').localeCompare(b.section || '');
                        case 'status':
                            return (a.status || '').localeCompare(b.status || '');
                        case 'id':
                            return (a.id || 0) - (b.id || 0);
                        default:
                            return 0;
                    }
                });
                renderStudents();
            }
        }

        // Start initialization
        initialize(); 
        
    } catch (error) {
        console.error('❌ Error initializing Students module:', error);
    }
}

// Make function globally available
window.initStudentsModule = initStudentsModule;
