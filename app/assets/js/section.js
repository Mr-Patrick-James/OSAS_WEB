// sections.js - Database-integrated version
function initSectionsModule() {
    console.log('🛠 Sections module initializing...');
    
    try {
        // Elements
        const tableBody = document.getElementById('sectionsTableBody');
        const btnAddSection = document.getElementById('btnAddSection');
        const btnAddFirstSection = document.getElementById('btnAddFirstSection');
        const modal = document.getElementById('sectionsModal');
        const modalOverlay = document.getElementById('sectionsModalOverlay');
        const closeBtn = document.getElementById('closeSectionsModal');
        const cancelBtn = document.getElementById('cancelSectionsModal');
        const sectionsForm = document.getElementById('sectionsForm');
        const searchInput = document.getElementById('searchSection');
        const filterSelect = document.getElementById('sectionFilterSelect');
        const exportBtn = document.getElementById('btnExportSections');
        const exportModal = document.getElementById('ExportSectionsModal');
        const closeExportBtn = document.getElementById('closeExportModal');
        const exportModalOverlay = document.getElementById('ExportModalOverlay');
        const exportPDFBtn = document.getElementById('exportPDF');
        const exportExcelBtn = document.getElementById('exportExcel');
        const exportWordBtn = document.getElementById('exportWord');

        // Check for essential elements
        if (!tableBody) {
            console.error('❗ #sectionsTableBody not found');
            return;
        }

        if (!modal) {
            console.warn('⚠️ #sectionsModal not found');
        }

        let sections = [];
        let allSections = [];

        let apiBase;
        (function resolveApiBase() {
            const path = window.location.pathname;
            if (path.includes('admin_page') || path.includes('/views/admin/')) {
                apiBase = '../../api/sections.php';
            } else {
                apiBase = '../api/sections.php';
            }
        })();

        let currentView = 'active';
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

        function renderPagination() {
            const paginationContainer = document.querySelector('.sections-pagination');
            if (!paginationContainer) return;

            let html = '';
            html += `<button class="sections-pagination-btn ${currentPage === 1 ? 'disabled' : ''}" ${currentPage === 1 ? 'disabled' : ''} onclick="window.changeSectionsPage(${currentPage - 1})"><i class='bx bx-chevron-left'></i></button>`;

            for (let i = 1; i <= totalPages; i++) {
                if (i === 1 || i === totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
                    html += `<button class="sections-pagination-btn ${i === currentPage ? 'active' : ''}" onclick="window.changeSectionsPage(${i})">${i}</button>`;
                } else if (i === currentPage - 2 || i === currentPage + 2) {
                    html += `<span class="sections-pagination-ellipsis">...</span>`;
                }
            }

            html += `<button class="sections-pagination-btn ${currentPage === totalPages || totalPages === 0 ? 'disabled' : ''}" ${currentPage === totalPages || totalPages === 0 ? 'disabled' : ''} onclick="window.changeSectionsPage(${currentPage + 1})"><i class='bx bx-chevron-right'></i></button>`;
            paginationContainer.innerHTML = html;
        }

        window.changeSectionsPage = function(page) {
            if (page < 1 || page > totalPages || page === currentPage) return;
            currentPage = page;
            fetchSections();
        };

        async function fetchSections() {
            try {
                const filter = currentView === 'archived' ? 'archived' : 'active';
                const search = searchInput ? searchInput.value : '';
                
                let url = `${apiBase}?action=get&filter=${filter}&page=${currentPage}&limit=${itemsPerPage}`;
                if (search) {
                    url += `&search=${encodeURIComponent(search)}`;
                }

                console.log('Fetching sections from:', url);

                const response = await fetch(url);
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const text = await response.text();
                console.log('Raw API Response:', text);

                let data;
                try {
                    data = JSON.parse(text);
                } catch (parseError) {
                    console.error('JSON Parse Error:', parseError);
                    console.error('Response was:', text);
                    throw new Error('Invalid JSON response from server');
                }

                console.log('Parsed API Response:', data);

                if (data.status === 'success') {
                    const payload = data.data;
                    if (Array.isArray(payload)) {
                        allSections = payload;
                        totalRecords = payload.length;
                        totalPages = Math.ceil(totalRecords / itemsPerPage);
                        const start = (currentPage - 1) * itemsPerPage;
                        const end = start + itemsPerPage;
                        sections = payload.slice(start, end);
                    } else if (payload && Array.isArray(payload.sections)) {
                        sections = payload.sections;
                        totalRecords = typeof payload.total === 'number' ? payload.total : sections.length;
                        totalPages = typeof payload.total_pages === 'number' ? payload.total_pages : Math.ceil(totalRecords / itemsPerPage);
                        currentPage = typeof payload.page === 'number' ? payload.page : currentPage;
                        allSections = sections;
                    } else {
                        console.error('Unexpected API data shape:', payload);
                        showError('Unexpected response from server while loading sections.');
                        return;
                    }
                    renderSections();
                    updateStats();
                    renderPagination();
                } else {
                    console.error('Error fetching sections:', data.message);
                    showError('Failed to load sections: ' + data.message);
                }
            } catch (error) {
                console.error('Error fetching sections:', error);
                console.error('Full error details:', error.message, error.stack);
                showError('Failed to load sections. Please check your connection and console for details.');
            }
        }

        async function fetchStats() {
            try {
                const response = await fetch(`${apiBase}?action=stats`);
                const data = await response.json();

                if (data.status === 'success') {
                    updateStatsFromData(data.data);
                }
            } catch (error) {
                console.error('Error fetching stats:', error);
            }
        }

        async function addSection(formData) {
            const submitBtn = document.querySelector('#sectionsForm button[type="submit"]');
            if (submitBtn) submitBtn.disabled = true;
            
            try {
                const response = await fetch(`${apiBase}?action=add`, {
                    method: 'POST',
                    body: formData
                });
                const data = await response.json();

                if (data.status === 'success') {
                    showSuccess(data.message || 'Section added successfully!');
                    await fetchSections();
                    await fetchStats();
                    closeModal();
                } else {
                    showError(data.message || 'Failed to add section');
                }
            } catch (error) {
                console.error('Error adding section:', error);
                showError('Failed to add section. Please try again.');
            } finally {
                if (submitBtn) submitBtn.disabled = false;
            }
        }

        async function updateSection(sectionId, formData) {
            try {
                formData.append('sectionId', sectionId);
                const response = await fetch(`${apiBase}?action=update`, {
                    method: 'POST',
                    body: formData
                });
                const data = await response.json();

                if (data.status === 'success') {
                    showSuccess(data.message || 'Section updated successfully!');
                    await fetchSections();
                    await fetchStats();
                    closeModal();
                } else {
                    showError(data.message || 'Failed to update section');
                }
            } catch (error) {
                console.error('Error updating section:', error);
                showError('Failed to update section. Please try again.');
            }
        }

        async function deleteSection(sectionId) {
            try {
                const response = await fetch(`${apiBase}?action=delete&id=${sectionId}`, {
                    method: 'GET'
                });
                const data = await response.json();

                if (data.status === 'success') {
                    showSuccess(data.message || 'Section permanently deleted!');
                    await fetchSections();
                    await fetchStats();
                } else {
                    showError(data.message || 'Failed to delete section');
                }
            } catch (error) {
                console.error('Error deleting section:', error);
                showError('Failed to delete section. Please try again.');
            }
        }

        async function archiveSection(sectionId) {
            try {
                const response = await fetch(`${apiBase}?action=archive&id=${sectionId}`, {
                    method: 'GET'
                });
                const data = await response.json();

                if (data.status === 'success') {
                    showSuccess(data.message || 'Section archived successfully!');
                    await fetchSections();
                    await fetchStats();
                } else {
                    showError(data.message || 'Failed to archive section');
                }
            } catch (error) {
                console.error('Error archiving section:', error);
                showError('Failed to archive section. Please try again.');
            }
        }

        async function restoreSection(sectionId) {
            try {
                const response = await fetch(`${apiBase}?action=restore&id=${sectionId}`, {
                    method: 'GET'
                });
                const data = await response.json();

                if (data.status === 'success') {
                    showSuccess(data.message || 'Section restored successfully!');
                    await fetchSections();
                    await fetchStats();
                } else {
                    showError(data.message || 'Failed to restore section');
                }
            } catch (error) {
                console.error('Error restoring section:', error);
                showError('Failed to restore section. Please try again.');
            }
        }

        async function loadDepartments() {
            try {
                let deptApi;
                const path = window.location.pathname;
                if (path.includes('admin_page') || path.includes('/views/admin/')) {
                    deptApi = '../../api/departments.php';
                } else {
                    deptApi = '../api/departments.php';
                }

                const response = await fetch(deptApi);
                const data = await response.json();

                if (data.status === 'success') {
                    const select = document.getElementById('sectionDepartment');
                    if (select) {
                        // Clear existing options except the first one
                        const firstOption = select.querySelector('option[value=""]');
                        select.innerHTML = '';
                        if (firstOption) {
                            select.appendChild(firstOption);
                        }
                        
                        // Add departments from API
                        // Use correct mapping for department data
                        const depts = data.data.departments || data.data;
                        if (Array.isArray(depts)) {
                            depts.forEach(dept => {
                                const option = document.createElement('option');
                                option.value = dept.id || dept.dbId;
                                option.textContent = dept.name || dept.department_name;
                                select.appendChild(option);
                            });
                        }
                    }
                }
            } catch (error) {
                console.error('Error loading departments:', error);
            }
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

        async function downloadSectionsPDF() {
            if (!window.jspdf) {
                if (typeof showNotification === 'function') {
                    showNotification('PDF library not loaded. Please refresh.', 'warning');
                } else {
                    alert('PDF library not loaded. Please refresh the page.');
                }
                return;
            }
            
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();
            const now = new Date();
            
            // --- Header Section ---
            const headerPath = '/OSAS_WEB/app/assets/headers/header.png';
            const headerData = await loadImage(headerPath);

            if (headerData) {
                // Reduced width to 140mm (from 180mm) to fix stretching, height to 25mm
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
            doc.setFontSize(12);
            doc.setTextColor(41, 128, 185); 
            doc.setFont("helvetica", "bold");
            doc.text("SECTION LIST REPORT", 105, 38, { align: 'center' });

            doc.setFontSize(8);
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
            doc.text(`Total Records: ${sections.length}`, 14, 62);
            
            let startY = 67;

            const tableColumn = ["ID", "Section Name", "Department", "Academic Year", "Students", "Status"];
            const tableRows = sections.map(s => [
                s.section_id || 'SEC-' + String(s.id).padStart(3, '0'),
                s.name,
                s.department,
                s.academic_year,
                s.student_count,
                s.status.charAt(0).toUpperCase() + s.status.slice(1)
            ]);

            doc.autoTable({
                head: [tableColumn],
                body: tableRows,
                startY: startY,
                theme: 'grid',
                styles: { fontSize: 8, cellPadding: 3 },
                headStyles: { fillColor: [245, 245, 245], textColor: [44, 62, 80], fontStyle: 'bold' },
                margin: { top: 60 }
            });

            doc.save(`Sections_${now.toISOString().slice(0, 10)}.pdf`);
        }

        function downloadSectionsExcel() {
            const lines = [];
            const now = new Date();
            lines.push('Section List Report');
            lines.push('Generated,' + csvEscape(now.toLocaleString()));
            lines.push('');
            lines.push(['ID', 'Section Name', 'Department', 'Academic Year', 'Student Count', 'Status'].map(csvEscape).join(','));

            sections.forEach(s => {
                lines.push([
                    s.section_id || 'SEC-' + String(s.id).padStart(3, '0'),
                    s.name,
                    s.department,
                    s.academic_year,
                    s.student_count,
                    s.status
                ].map(csvEscape).join(','));
            });

            const csvContent = lines.join('\r\n');
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const fileName = 'sections_export_' + now.toISOString().slice(0, 10) + '.csv';
            saveAs(blob, fileName);
        }

        async function downloadSectionsWord() {
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
            
            const tableHeader = new TableRow({
                children: ["ID", "Section Name", "Department", "Academic Year", "Students", "Status"].map(text => new TableCell({
                    children: [new Paragraph({ text, bold: true, size: 20 })],
                    shading: { fill: "E0E0E0" }
                }))
            });
            
            const tableRows = sections.map(s => new TableRow({
                children: [
                    String(s.section_id || 'SEC-' + String(s.id).padStart(3, '0')),
                    s.name,
                    s.department,
                    s.academic_year,
                    String(s.student_count),
                    s.status
                ].map(text => new TableCell({
                    children: [new Paragraph({ text: text || "", size: 18 })]
                }))
            }));

            const doc = new Document({
                sections: [{
                    children: [
                        new Paragraph({ text: "SECTION LIST REPORT", heading: HeadingLevel.HEADING_1, alignment: AlignmentType.CENTER }),
                        new Paragraph({ text: `Office of Student Affairs and Services`, alignment: AlignmentType.CENTER }),
                        new Paragraph({ text: `Generated: ${now.toLocaleString()}`, alignment: AlignmentType.CENTER, spacing: { after: 400 } }),
                        new Table({
                            rows: [tableHeader, ...tableRows],
                            width: { size: 100, type: WidthType.PERCENTAGE }
                        })
                    ]
                }]
            });

            Packer.toBlob(doc).then(blob => {
                saveAs(blob, `Sections_${now.toISOString().slice(0, 10)}.docx`);
            });
        }

        // --- Render function ---
        function renderSections() {
            const list = Array.isArray(sections) ? sections : [];
            if (list.length === 0) {
                tableBody.innerHTML = '';
                const emptyState = document.getElementById('sectionsEmptyState');
                if (emptyState) {
                    emptyState.style.display = 'flex';
                }
                updateCounts([]);
                renderPagination();
                return;
            }

            const emptyState = document.getElementById('sectionsEmptyState');
            if (emptyState) {
                emptyState.style.display = 'none';
            }

            tableBody.innerHTML = list.map(s => `
                <tr data-id="${s.id}">
                    <td class="section-id" data-label="ID">${s.section_id || 'SEC-' + String(s.id).padStart(3, '0')}</td>
                    <td class="section-name" data-label="Section Name">
                        <div class="section-name-wrapper">
                            <div class="section-icon">
                                <i class='bx bx-group'></i>
                            </div>
                            <div>
                                <strong>${escapeHtml(s.name)}</strong>
                                <small class="section-year">${escapeHtml(s.academic_year || '')}</small>
                            </div>
                        </div>
                    </td>
                    <td class="department-name" data-label="Department">${escapeHtml(s.department || 'N/A')}</td>
                    <td class="student-count" data-label="Students">${s.student_count || 0}</td>
                    <td class="date-created" data-label="Date Created">${s.date || ''}</td>
                    <td data-label="Status">
                        <span class="sections-status-badge ${s.status}">${s.status === 'active' ? 'Active' : 'Archived'}</span>
                    </td>
                    <td data-label="Actions">
                        <div class="sections-action-buttons">
                            <button class="sections-action-btn edit" data-id="${s.id}" title="Edit">
                                <i class='bx bx-edit'></i>
                            </button>
                            ${s.status === 'archived' ? 
                                `<button class="sections-action-btn restore" data-id="${s.id}" title="Restore">
                                    <i class='bx bx-reset'></i>
                                </button>` : 
                                ''
                            }
                            <button class="sections-action-btn delete" data-id="${s.id}" title="Delete">
                                <i class='bx bx-trash'></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `).join('');

            updateCounts(list);
            renderPagination();
        }

        function updateStats() {
            fetchStats();
        }

        function updateStatsFromData(stats) {
            const totalEl = document.getElementById('totalSections');
            const activeEl = document.getElementById('activeSections');
            const archivedEl = document.getElementById('archivedSections');
            const activePctEl = document.getElementById('activeSectionsPct');
            const archivedPctEl = document.getElementById('archivedSectionsPct');
            
            if (totalEl) totalEl.textContent = stats.total || 0;
            if (activeEl) activeEl.textContent = stats.active || 0;
            if (archivedEl) archivedEl.textContent = stats.archived || 0;

            const total = Number(stats.total) || 0;
            const active = Number(stats.active) || 0;
            const archived = Number(stats.archived) || 0;
            const activePct = total > 0 ? Math.round((active / total) * 100) : 0;
            const archivedPct = total > 0 ? Math.round((archived / total) * 100) : 0;
            if (activePctEl) activePctEl.textContent = `${activePct}%`;
            if (archivedPctEl) archivedPctEl.textContent = `${archivedPct}%`;
        }

        function updateCounts(filteredSections) {
            const showingEl = document.getElementById('showingSectionsCount');
            const totalCountEl = document.getElementById('totalSectionsCount');
            
            if (showingEl) showingEl.textContent = filteredSections.length;
            if (totalCountEl) totalCountEl.textContent = totalRecords;
        }

        // --- Modal functions ---
        function openModal(editId = null) {
            if (!modal) return;
            
            const modalTitle = document.getElementById('sectionsModalTitle');
            const form = document.getElementById('sectionsForm');
            
            if (editId) {
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Edit Section';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-layer\'></i><span>Edit Section</span>';
                }
                
                // Robust matching for ID (compare as strings)
                const section = sections.find(s => String(s.id) === String(editId));
                
                if (section) {
                    console.log('📝 Filling section modal with data:', section);
                    document.getElementById('sectionName').value = section.name || '';
                    document.getElementById('sectionCode').value = section.code || '';
                    document.getElementById('sectionDepartment').value = section.department_id || '';
                    document.getElementById('academicYear').value = section.academic_year || '';
                    document.getElementById('sectionStatus').value = section.status || 'active';
                    
                    modal.dataset.editingId = editId;
                } else {
                    console.error('❌ Could not find section with ID:', editId);
                }
            } else {
                const span = modalTitle.querySelector('span');
                if (span) {
                    span.textContent = 'Add New Section';
                } else {
                    modalTitle.innerHTML = '<i class=\'bx bxs-layer\'></i><span>Add New Section</span>';
                }
                if (form) form.reset();
                delete modal.dataset.editingId;
            }
            
            modal.classList.add('active');
            document.body.style.overflow = 'hidden';
        }

        function closeModal() {
            if (!modal) return;
            
            modal.classList.remove('active');
            document.body.style.overflow = 'auto';
            const form = document.getElementById('sectionsForm');
            if (form) form.reset();
            delete modal.dataset.editingId;
        }

        // --- Event handlers ---
        function handleTableClick(e) {
            const editBtn = e.target.closest('.sections-action-btn.edit');
            const restoreBtn = e.target.closest('.sections-action-btn.restore');
            const deleteBtn = e.target.closest('.sections-action-btn.delete');

            if (editBtn) {
                const id = editBtn.dataset.id;
                openModal(id);
            }

            if (restoreBtn) {
                const id = restoreBtn.dataset.id;
                const section = sections.find(s => String(s.id) === String(id));
                if (section) {
                    showModernAlert({
                        title: 'Restore Section',
                        message: `Restore section "${section.name}"?`,
                        icon: 'info',
                        confirmText: 'Yes, Restore'
                    }).then(confirmed => {
                        if (confirmed) restoreSection(id);
                    });
                }
            }

            if (deleteBtn) {
                const id = deleteBtn.dataset.id;
                const section = sections.find(s => String(s.id) === String(id));
                if (section) {
                    if (section.status === 'archived') {
                        showModernAlert({
                            title: 'Permanent Delete',
                            message: `Permanently delete section "${section.name}"? This action cannot be undone.`,
                            icon: 'danger',
                            confirmText: 'Delete Permanently'
                        }).then(confirmed => {
                            if (confirmed) deleteSection(id);
                        });
                    } else {
                        showModernAlert({
                            title: 'Archive Section',
                            message: `Archive section "${section.name}"? This will move it to archived.`,
                            icon: 'warning',
                            confirmText: 'Yes, Archive'
                        }).then(confirmed => {
                            if (confirmed) archiveSection(id);
                        });
                    }
                }
            }
        }

        // --- Utility functions ---
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function showSuccess(message) {
            if (typeof showNotification === 'function') {
                showNotification(message, 'success');
            } else {
                console.log(message);
            }
        }

        function showError(message) {
            if (typeof showNotification === 'function') {
                showNotification(message, 'error');
            } else {
                console.error(message);
            }
        }

        // --- Initialize ---
        async function initialize() {
            // Load departments for dropdown
            await loadDepartments();

            // Set default view to active (hide archived by default)
            currentView = 'active';
            if (filterSelect) {
                filterSelect.value = 'active';
            }

            // Initial load - only active sections
            await fetchSections();

            // Event listeners for table
            tableBody.addEventListener('click', handleTableClick);

            // Add Section button
            if (btnAddSection) {
                btnAddSection.addEventListener('click', () => openModal());
            }

            // Export button
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

            // Export formats
            if (exportPDFBtn) {
                exportPDFBtn.addEventListener('click', async () => {
                    await downloadSectionsPDF();
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                });
            }

            if (exportExcelBtn) {
                exportExcelBtn.addEventListener('click', () => {
                    downloadSectionsExcel();
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                });
            }

            if (exportWordBtn) {
                exportWordBtn.addEventListener('click', async () => {
                    await downloadSectionsWord();
                    if (exportModal) exportModal.classList.remove('active');
                    document.body.style.overflow = 'auto';
                });
            }

            // Add First Section button
            if (btnAddFirstSection) {
                btnAddFirstSection.addEventListener('click', () => openModal());
            }

            // Close modal
            if (closeBtn) closeBtn.addEventListener('click', closeModal);
            if (cancelBtn) cancelBtn.addEventListener('click', closeModal);
            if (modalOverlay) modalOverlay.addEventListener('click', closeModal);

            // Escape key to close modal
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape' && modal && modal.classList.contains('active')) {
                    closeModal();
                }
            });

            // Form submission
            if (sectionsForm) {
                sectionsForm.addEventListener('submit', async (e) => {
                    e.preventDefault();
                    
                    const sectionName = document.getElementById('sectionName').value.trim();
                    const sectionCode = document.getElementById('sectionCode').value.trim();
                    const sectionDepartment = document.getElementById('sectionDepartment').value;
                    const academicYear = document.getElementById('academicYear').value.trim();
                    const sectionStatus = document.getElementById('sectionStatus').value;
                    
                    if (!sectionName || !sectionCode || !sectionDepartment || !academicYear) {
                        showError('Please fill in all required fields.');
                        return;
                    }

                    const editingId = modal.dataset.editingId;
                    const formData = new FormData();
                    formData.append('sectionName', sectionName);
                    formData.append('sectionCode', sectionCode);
                    formData.append('sectionDepartment', sectionDepartment);
                    formData.append('academicYear', academicYear);
                    formData.append('sectionStatus', sectionStatus);
                    
                    if (editingId) {
                        await updateSection(editingId, formData);
                    } else {
                        await addSection(formData);
                    }
                });
            }

            // Search functionality
            if (searchInput) {
                let searchTimeout;
                searchInput.addEventListener('input', () => {
                    clearTimeout(searchTimeout);
                    searchTimeout = setTimeout(() => {
                        currentPage = 1;
                        fetchSections();
                    }, 500); // Debounce search
                });
            }

            // Filter functionality - hide archived by default
            if (filterSelect) {
                // Set default to active
                filterSelect.value = 'active';
                currentView = 'active';
                
                filterSelect.addEventListener('change', () => {
                    if (filterSelect.value === 'archived') {
                        currentView = 'archived';
                    } else {
                        currentView = 'active';
                    }
                    currentPage = 1;
                    fetchSections();
                    // Update archived button state
                    const btnArchived = document.getElementById('btnArchivedSections');
                    if (btnArchived) {
                        if (currentView === 'archived') {
                            btnArchived.classList.add('active');
                        } else {
                            btnArchived.classList.remove('active');
                        }
                    }
                });
            }

            // Archived button functionality
            const btnArchived = document.getElementById('btnArchivedSections');
            if (btnArchived) {
                btnArchived.addEventListener('click', () => {
                    if (currentView === 'archived') {
                        // Switch back to active view
                        currentView = 'active';
                        if (filterSelect) filterSelect.value = 'active';
                        btnArchived.classList.remove('active');
                    } else {
                        // Switch to archived view
                        currentView = 'archived';
                        if (filterSelect) filterSelect.value = 'archived';
                        btnArchived.classList.add('active');
                    }
                    fetchSections();
                });
            }

            // Sort functionality
            const sortHeaders = document.querySelectorAll('.sections-sortable');
            sortHeaders.forEach(header => {
                header.addEventListener('click', function() {
                    const sortBy = this.dataset.sort;
                    sortSections(sortBy);
                });
            });

            function sortSections(sortBy) {
                sections.sort((a, b) => {
                    switch(sortBy) {
                        case 'name':
                            return a.name.localeCompare(b.name);
                        case 'date':
                            return new Date(b.date) - new Date(a.date);
                        case 'id':
                        default:
                            return (a.section_id || '').localeCompare(b.section_id || '');
                    }
                });
                renderSections();
            }

            console.log('✅ Sections module initialized successfully!');
        }

        // Start initialization
        initialize();

    } catch (error) {
        console.error('❌ Error initializing sections module:', error);
    }
}

// Make function globally available
window.initSectionsModule = initSectionsModule;

