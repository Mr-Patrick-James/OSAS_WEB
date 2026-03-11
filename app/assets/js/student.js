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

        async function downloadStudentsPDF() {
            if (!window.jspdf) {
                if (typeof showNotification === 'function') {
                    showNotification('PDF library not loaded. Please refresh.', 'warning');
                } else {
                    console.warn('PDF library not loaded. Please refresh the page.');
                }
                return;
            }
            
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();
            const now = new Date();
            
            // --- Header Design ---
            const logoPath = '/OSAS_WEB/app/assets/img/default.png';
            const logoData = await loadImage(logoPath);

            // Left Side: Logo & Institution Name
            if (logoData) {
                doc.addImage(logoData, 'PNG', 14, 10, 20, 20);
                
                doc.setFontSize(18);
                doc.setTextColor(44, 62, 80); 
                doc.setFont("helvetica", "bold");
                doc.text("E-OSAS SYSTEM", 40, 18);
                
                doc.setFontSize(10);
                doc.setFont("helvetica", "normal");
                doc.setTextColor(127, 140, 141); 
                doc.text("Office of Student Affairs and Services", 40, 24);
            } else {
                doc.setFontSize(22);
                doc.setTextColor(44, 62, 80);
                doc.setFont("helvetica", "bold");
                doc.text("E-OSAS SYSTEM", 14, 20);
                
                doc.setFontSize(10);
                doc.setFont("helvetica", "normal");
                doc.setTextColor(127, 140, 141);
                doc.text("Office of Student Affairs and Services", 14, 28);
            }

            // Right Side: Report Title & Date
            doc.setFontSize(14);
            doc.setTextColor(41, 128, 185); 
            doc.setFont("helvetica", "bold");
            doc.text("STUDENT LIST REPORT", 196, 18, { align: 'right' });

            doc.setFontSize(9);
            doc.setTextColor(100, 100, 100);
            doc.setFont("helvetica", "normal");
            doc.text(`Generated on: ${now.toLocaleDateString()} ${now.toLocaleTimeString()}`, 196, 24, { align: 'right' });

            // Divider Line
            doc.setDrawColor(220, 220, 220);
            doc.setLineWidth(0.5);
            doc.line(14, 35, 196, 35);
            
            // Summary Stats
            doc.setFontSize(10);
            doc.setTextColor(60, 60, 60);
            doc.text(`Total Records: ${allStudents.length}`, 14, 45);
            
            let startY = 50;

            // Table
            const tableColumn = ["ID", "Student ID", "Name", "Dept", "Section", "Year Level", "Contact No", "Status"];
            const tableRows = [];

            // Use allStudents for export, or you could use current filtered list if preferred
            // Let's use current view students
            allStudents.forEach(s => {
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
        }

        function downloadStudentsExcel() {
            const lines = [];
            const now = new Date();
            lines.push('Student List Report');
            lines.push('Generated,' + csvEscape(now.toLocaleString()));
            lines.push('');
            lines.push([
                'ID',
                'Student ID',
                'First Name',
                'Middle Name',
                'Last Name',
                'Email',
                'Department',
                'Section',
                'Year Level',
                'Contact No',
                'Status'
            ].map(csvEscape).join(','));

            allStudents.forEach(s => {
                lines.push([
                    s.id,
                    s.studentId,
                    s.firstName,
                    s.middleName,
                    s.lastName,
                    s.email,
                    s.department,
                    s.section,
                    s.yearlevel,
                    s.contact,
                    formatStatus(s.status)
                ].map(csvEscape).join(','));
            });

            const csvContent = lines.join('\r\n');
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const fileName = 'students_export_' + now.toISOString().slice(0, 10) + '.csv';
            
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
            
            const { Document, Packer, Paragraph, Table, TableCell, TableRow, WidthType, HeadingLevel, TextRun, AlignmentType } = window.docx;
            const now = new Date();
            
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
            const tableRows = allStudents.map(s => {
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

            const doc = new Document({
                sections: [{
                    properties: {},
                    children: [
                        new Paragraph({
                            text: "STUDENT LIST REPORT",
                            heading: HeadingLevel.HEADING_1,
                            alignment: AlignmentType.CENTER
                        }),
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: `Office of Student Affairs and Services`,
                                    italics: true,
                                    color: "666666"
                                })
                            ],
                            alignment: AlignmentType.CENTER
                        }),
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: `Generated: ${now.toLocaleString()}`,
                                    italics: true,
                                    color: "999999"
                                })
                            ],
                            alignment: AlignmentType.CENTER,
                            spacing: { after: 400 }
                        }),
                        new Paragraph({
                            text: `Total Records: ${allStudents.length}`,
                            spacing: { after: 200 }
                        }),
                        new Table({
                            rows: [tableHeader, ...tableRows],
                            width: { size: 100, type: WidthType.PERCENTAGE }
                        })
                    ]
                }]
            });

            Packer.toBlob(doc).then(blob => {
                if (typeof saveAs === 'function') {
                    saveAs(blob, `Student_List_${now.toISOString().slice(0, 10)}.docx`);
                } else {
                    console.error('FileSaver.js not loaded');
                    if (typeof showNotification === 'function') {
                        showNotification('Error: FileSaver.js not loaded', 'error');
                    } else {
                        console.error('Error: FileSaver.js not loaded');
                    }
                }
            });
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

            // Import Students button
            if (importBtn) {
                importBtn.addEventListener('click', async () => {
                    const confirmed = await showModernAlert({
                        title: 'Import Enrollment List',
                        message: 'Sync student records with the latest list? This will update departments and auto-generate student emails/accounts.',
                        confirmText: 'Yes, Sync Data',
                        cancelText: 'Cancel'
                    });

                    if (!confirmed) return;

                    // Show Loading
                    showModernAlert({
                        title: 'Processing Import',
                        message: 'Parsing enrollment list and updating database. Please wait...',
                        icon: 'loading',
                        showCancel: false,
                        confirmText: 'Processing...'
                    });

                    try {
                        const response = await fetch(`${apiBase}?action=import`, {
                            method: 'POST'
                        });
                        const result = await response.json();

                        if (result.success) {
                            const { created, updated, skipped } = result.data;
                            await showModernAlert({
                                title: 'Import Successful',
                                message: 'The student database has been synchronized with the latest enrollment records.',
                                icon: 'success',
                                showCancel: false,
                                confirmText: 'Great!',
                                stats: { created, updated, skipped }
                            });
                            loadStudents(); // Refresh the list
                        } else {
                            await showModernAlert({
                                title: 'Import Failed',
                                message: result.message || 'An error occurred while processing the enrollment list.',
                                icon: 'error',
                                showCancel: false,
                                confirmText: 'Try Again'
                            });
                        }
                    } catch (error) {
                        console.error('Import error:', error);
                        await showModernAlert({
                            title: 'Connection Error',
                            message: 'Could not connect to the server. Please check your network.',
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
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                });
            }

            if (exportExcelBtn) {
                exportExcelBtn.addEventListener('click', () => {
                    downloadStudentsExcel();
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                });
            }

            if (exportWordBtn) {
                exportWordBtn.addEventListener('click', async () => {
                    await downloadStudentsWord();
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
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
