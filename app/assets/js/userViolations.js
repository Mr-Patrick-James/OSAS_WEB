/*********************************************************
 * CONFIG
 *********************************************************/
const API_BASE = '/OSAS_WEB/api/';

let studentId = null;
let userViolations = [];
let currentViolationId = null;

/*********************************************************
 * INIT
 *********************************************************/
document.addEventListener('DOMContentLoaded', initUserViolations);

// Also listen for dynamic page loads
if (typeof window.addEventListener !== 'undefined') {
    window.addEventListener('pageContentLoaded', initUserViolations);
}

async function initUserViolations() {
    const tbody = document.getElementById('violationsTableBody');
    
    // Only initialize if the violations table exists on the page
    if (!tbody) {
        console.log('Violations table not found on this page, skipping initialization');
        return;
    }

    // Attach search listener
    const searchInput = document.getElementById('searchViolation');
    if (searchInput) {
        searchInput.addEventListener('input', filterViolations);
    }

    studentId = getStudentId();
    console.log('Student ID:', studentId);

    if (!studentId) {
        tbody.innerHTML = errorRow('Student ID not found. Please login again.');
        return;
    }

    // Attach download listener
    const btnDownload = document.getElementById('btnDownloadReport');
    if (btnDownload) {
        btnDownload.addEventListener('click', function(e) {
            e.preventDefault();
            downloadViolationsReport();
        });
    }

    await loadUserViolations();
}

/*********************************************************
 * HELPERS
 *********************************************************/
function getStudentId() {
    if (window.STUDENT_ID) return window.STUDENT_ID;
    const mainContent = document.getElementById('main-content');
    if (mainContent && mainContent.dataset.studentId) return mainContent.dataset.studentId;
    
    const cookies = Object.fromEntries(
        document.cookie.split(';').map(c => c.trim().split('=')).map(([k,v]) => [k, decodeURIComponent(v)])
    );
    return cookies.student_id_code || cookies.student_id;
}

function errorRow(message) {
    return `
        <tr>
            <td colspan="6" style="text-align:center; padding:40px; color:#ef4444;">
                ${message}
            </td>
        </tr>
    `;
}

/*********************************************************
 * LOAD VIOLATIONS
 *********************************************************/
async function loadUserViolations() {
    const tbody = document.getElementById('violationsTableBody');

    try {
        const apiUrl = `${API_BASE}violations.php`;
        console.log('📡 Fetching violations from:', apiUrl);
        
        const res = await fetch(apiUrl);
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        
        const json = await res.json();
        if (json.status !== 'success') throw new Error(json.message || 'Failed to load violations');

        userViolations = json.data || [];
        console.log('✅ Loaded', userViolations.length, 'violations');

        updateViolationStats();
        renderViolationTable();

    } catch (err) {
        console.error('❌ Error loading violations:', err);
        tbody.innerHTML = errorRow(err.message);
    }
}

/*********************************************************
 * STATS
 *********************************************************/
function updateViolationStats() {
    const total = userViolations.length;

    const countByType = (type) => {
        return userViolations.filter(v => {
            const rawType = v.violation_type_name || v.violation_type || v.violationType || '';
            const violationType = String(rawType).toLowerCase();
            const violationTypeLabel = String(v.violationTypeLabel || '').toLowerCase();
            
            if (type === 'uniform') {
                return violationType.includes('uniform') || violationTypeLabel.includes('uniform');
            } else if (type === 'footwear') {
                return violationType.includes('footwear') || violationType.includes('shoe') || 
                       violationTypeLabel.includes('footwear') || violationTypeLabel.includes('shoe');
            } else if (type === 'id') {
                return violationType.includes('id') || violationType.includes('no_id') ||
                       violationTypeLabel.includes('id') || violationTypeLabel.includes('no id');
            }
            return false;
        }).length;
    };

    const setStat = (id, value) => {
        const el = document.getElementById(id);
        if (el) el.textContent = value;
    };

    setStat('statUniform', countByType('uniform'));
    setStat('statFootwear', countByType('footwear'));
    setStat('statId', countByType('id'));
    setStat('statTotal', total);
}

/*********************************************************
 * TABLE & FILTER
 *********************************************************/
function renderViolationTable() {
    const tbody = document.getElementById('violationsTableBody');
    const showingCount = document.getElementById('showingViolationsCount');
    
    // Apply filters
    const searchTerm = (document.getElementById('searchViolation')?.value || '').toLowerCase();
    const typeFilter = document.getElementById('violationFilter')?.value || 'all';
    const statusFilter = document.getElementById('statusFilter')?.value || 'all';

    const filtered = userViolations.filter(v => {
        // Search filter (Case ID, Type, Date)
        const searchStr = `${v.case_id || v.id} ${v.violation_type_name || ''} ${v.violation_type || ''} ${v.violationTypeLabel || ''} ${v.created_at || ''}`.toLowerCase();
        const matchesSearch = !searchTerm || searchStr.includes(searchTerm);

        // Type filter
        const rawType = String(v.violation_type_name || v.violation_type || v.violationType || '').toLowerCase();
        const matchesType = typeFilter === 'all' || rawType.includes(typeFilter.replace('improper_', '')); // simple mapping

        // Status filter
        const status = (v.status || 'pending').toLowerCase();
        const matchesStatus = statusFilter === 'all' || 
                             (statusFilter === 'resolved' && (status === 'resolved' || status === 'permitted')) ||
                             status === statusFilter;

        return matchesSearch && matchesType && matchesStatus;
    });

    if (showingCount) showingCount.textContent = filtered.length;

    if (filtered.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="5" style="text-align:center; padding:40px; color: #666;">
                    No violations found matching your filters
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = filtered.map(v => {
        const status = (v.status || 'pending').toLowerCase();
        
        const level = v.violation_level_name || v.violationLevelLabel || v.level || v.offense_level || '1';
        const levelVal = String(level).toLowerCase();
        const isDisciplinary = levelVal.includes('warning 3') || levelVal.includes('3rd') || levelVal.includes('disciplinary');
       
        let statusClass = 'warning';
        let statusText = 'Pending';

        if (status === 'resolved' || status === 'permitted') {
            statusClass = isDisciplinary ? 'resolved' : 'permitted';
            statusText = isDisciplinary ? 'Resolved' : 'Permitted';
        } else if (isDisciplinary || status === 'disciplinary') {
            statusClass = 'disciplinary';
            statusText = 'Disciplinary';
        } else if (status === 'warning') {
            statusClass = 'warning';
            statusText = 'Warning';
        }

        const violationType = v.violation_type_name || v.violationTypeLabel || v.violation_type || 'Unknown';
        const violationTypeFormatted = formatViolationType(String(violationType));

        return `
            <tr class="violation-row">
                <td data-label="Violation Type">${escapeHtml(violationTypeFormatted)}</td>
                <td data-label="Offense Level"><span class="Violations-badge warning">${level}</span></td>
                <td data-label="Date">${formatDate(v.created_at || v.violation_date || v.date)}</td>
                <td data-label="Status"><span class="Violations-status-badge ${statusClass}">${statusText}</span></td>
                <td data-label="Actions">
                    <button class="Violations-btn small" onclick="viewViolationDetails(${v.id})" title="View Details">
                        <i class='bx bx-show'></i> View
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function filterViolations() {
    renderViolationTable();
}

/*********************************************************
 * MODAL
 *********************************************************/
function getImageUrl(imagePath, fallbackName = 'Student') {
    if (!imagePath || imagePath.trim() === '') {
        return `https://ui-avatars.com/api/?name=${encodeURIComponent(fallbackName)}&background=ffd700&color=333&size=80`;
    }
    if (imagePath.startsWith('http') || imagePath.startsWith('data:')) return imagePath;
    
    // Adjust based on your path structure
    // Assuming relative to project root if not absolute
    // Note: API_BASE is /OSAS_WEB/api/, so we want /OSAS_WEB/
    const projectBase = API_BASE.replace('api/', '');

    if (imagePath.startsWith('assets/')) return projectBase + 'app/' + imagePath;
    if (imagePath.startsWith('app/assets/')) return projectBase + imagePath;
    
    return projectBase + 'app/assets/img/students/' + imagePath;
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
    if (level === null || level === undefined) return 'default';
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
    status = (status || '').toLowerCase();
    if (status === 'resolved') return 'resolved';
    if (status === 'permitted') return 'permitted';
    if (status === 'disciplinary') return 'disciplinary';
    if (status === 'warning') return 'warning';
    return 'warning';
}

function formatTime(timeStr) {
    if (!timeStr) return '';
    try {
        const [hours, minutes] = timeStr.split(':');
        const h = parseInt(hours);
        const ampm = h >= 12 ? 'PM' : 'AM';
        const h12 = h % 12 || 12;
        return `${h12}:${minutes} ${ampm}`;
    } catch (e) {
        return timeStr;
    }
}

function viewViolationDetails(id) {
    const v = userViolations.find(x => x.id == id);
    if (!v) return;
    currentViolationId = id;

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

    // --- Case Header ---
    let displayStatus = (v.status || '').toLowerCase();
    let displayStatusLabel = v.statusLabel || (displayStatus ? displayStatus.charAt(0).toUpperCase() + displayStatus.slice(1) : 'Unknown');

    const levelLabel = (v.violation_level_name || v.violationLevelLabel || v.level || v.offense_level || '').toLowerCase();
    const isDisciplinary = levelLabel.includes('warning 3') || levelLabel.includes('3rd') || levelLabel.includes('disciplinary');

    if (displayStatus === 'resolved' || displayStatus === 'permitted') {
        displayStatusLabel = isDisciplinary ? 'Resolved' : 'Permitted';
        displayStatus = 'resolved'; 
    } else if (isDisciplinary || displayStatus === 'disciplinary') {
        displayStatus = 'disciplinary';
        displayStatusLabel = 'Disciplinary';
    }

    setElementText('detailCaseId', v.case_id || '#' + v.id);
    setElementText('detailStatusBadge', displayStatusLabel);
    setElementClass('detailStatusBadge', `case-status-badge ${getStatusClass(displayStatus)}`);

    // --- Student Info ---
    const studentName = v.student_name || v.studentName || 'Student';
    const studentImg = v.student_image || v.studentImage || '';
    
    const studentImageUrl = getImageUrl(studentImg, studentName);
    setElementSrc('detailStudentImage', studentImageUrl);
    setElementText('detailStudentName', studentName);
    setElementText('detailStudentId', v.student_id || studentId);
    setElementText('detailStudentDept', v.department || v.department_name || 'N/A');
    setElementClass('detailStudentDept', `student-dept badge ${getDepartmentClass(v.department || v.department_name)}`);
    setElementText('detailStudentSection', v.section || 'N/A');
    setElementText('detailStudentContact', v.student_contact || v.studentContact || 'N/A');

    // Update Slip Status UI (Request/Download buttons)
    updateSlipStatusUI(id);

    // --- Violation Details Grid (Match Admin style) ---
    // In user view, "userViolations" is already filtered for this student
    let studentViolations = [...userViolations];
    
    // Sort violations by date descending
    studentViolations.sort((a, b) => {
         const dateA = new Date((a.created_at || a.violation_date || a.date) + ' ' + (a.violation_time || '00:00'));
         const dateB = new Date((b.created_at || b.violation_date || b.date) + ' ' + (b.violation_time || '00:00'));
         return dateB - dateA;
    });

    // Keep only the latest record per violation type
    const latestByType = new Map();
    studentViolations.forEach(sv => {
        const type = sv.violation_type_name || sv.violationTypeLabel || sv.violation_type || 'Unknown';
        if (!latestByType.has(type)) {
            latestByType.set(type, sv);
        }
    });
    
    const displayList = Array.from(latestByType.values());
    displayList.sort((a, b) => {
         const dateA = new Date((a.created_at || a.violation_date || a.date) + ' ' + (a.violation_time || '00:00'));
         const dateB = new Date((b.created_at || b.violation_date || b.date) + ' ' + (b.violation_time || '00:00'));
         return dateB - dateA;
    });

    const renderList = (containerId, items, renderer) => {
        const container = document.getElementById(containerId);
        if (container) {
             container.className = 'detail-value-container';
             container.innerHTML = items.map(item => {
                 const content = renderer(item);
                 return `<div style="margin-bottom: 4px; min-height: 24px; line-height: 24px;">${content}</div>`;
             }).join('');
        }
    };

    // Types
    renderList('detailViolationType', displayList, sv => {
        const type = sv.violation_type_name || sv.violationTypeLabel || sv.violation_type || 'Unknown';
        return `<span class="badge ${getViolationTypeClass(type)}">${formatViolationType(type)}</span>`;
    });

    // Levels
    renderList('detailViolationLevel', displayList, sv => {
        const level = sv.violation_level_name || sv.violationLevelLabel || sv.level || sv.offense_level || '-';
        const badgeClass = level !== '-' ? `badge ${getViolationLevelClass(level)}` : '';
        return `<span class="${badgeClass}">${level}</span>`;
    });

    // Dates
    renderList('detailDateTime', displayList, sv => {
        const dateStr = formatDate(sv.created_at || sv.violation_date || sv.date);
        const timeStr = formatTime(sv.violation_time || '');
        return `${dateStr} ${timeStr ? '• ' + timeStr : ''}`;
    });

    // Locations
    renderList('detailLocation', displayList, sv => sv.locationLabel || sv.location || '-');

    // Reported By
    renderList('detailReportedBy', displayList, sv => sv.reported_by || sv.reportedBy || '-');
    
    // Statuses
    renderList('detailStatus', displayList, sv => {
        let itemStatus = (sv.status || '').toLowerCase();
        let itemStatusLabel = sv.statusLabel || (itemStatus ? itemStatus.charAt(0).toUpperCase() + itemStatus.slice(1) : 'Unknown');
        
        const svLevelLabel = (sv.violation_level_name || sv.violationLevelLabel || sv.level || sv.offense_level || '').toLowerCase();
        const svIsDisciplinary = svLevelLabel.includes('warning 3') || svLevelLabel.includes('3rd') || svLevelLabel.includes('disciplinary');
        
        if (itemStatus === 'resolved' || itemStatus === 'permitted') {
            itemStatusLabel = svIsDisciplinary ? 'Resolved' : 'Permitted';
            itemStatus = 'resolved'; 
        } else if (svIsDisciplinary || itemStatus === 'disciplinary') {
            itemStatus = 'disciplinary';
            itemStatusLabel = 'Disciplinary';
        }
        
        return `<span class="badge ${getStatusClass(itemStatus)}">${itemStatusLabel}</span>`;
    });

    // --- Description / Notes ---
    setElementText('detailNotes', v.notes || v.description || 'No description provided.');

    // --- Evidence / Attachments (Match Admin) ---
    const attachmentsContainer = document.getElementById('detailAttachments');
    const evidenceSection = document.getElementById('evidenceSection');
    if (attachmentsContainer) {
        if (v.attachments && v.attachments.length > 0) {
            attachmentsContainer.innerHTML = v.attachments.map(filePath => {
                const fullUrl = getImageUrl(filePath);
                const fileName = filePath.split('/').pop();
                const isImage = /\.(jpg|jpeg|png|gif|webp)$/i.test(fileName);
                
                return `<a href="${fullUrl}" target="_blank" class="attachment-item">
                    <i class='bx ${isImage ? 'bx-image' : 'bx-file'}'></i>
                    <span>${fileName}</span>
                </a>`;
            }).join('');
            if (evidenceSection) evidenceSection.style.display = 'block';
        } else {
            attachmentsContainer.innerHTML = '<p class="no-attachments">No attachments available.</p>';
            // Hide if no attachments and we want it strictly like admin (admin shows "No attachments available")
            // But usually admin only shows it if it's there. Let's keep it visible with "No attachments" for now.
        }
    }

    // --- Resolution (if exists) ---
    const resSection = document.getElementById('resolutionSection');
    const resText = document.getElementById('detailResolution');
    if (v.resolution || v.resolution_notes) {
        resSection.style.display = 'block';
        resText.textContent = v.resolution || v.resolution_notes;
    } else {
        resSection.style.display = 'none';
    }

    // --- History Timeline (Match Admin Deduplication) ---
    const timelineEl = document.getElementById('detailTimeline');
    if (timelineEl) {
        let studentHistory = [...userViolations];
        
        // Deduplicate history for timeline
        const seenHistory = new Set();
        studentHistory = studentHistory.filter(h => {
            const hType = h.violation_type_name || h.violationTypeLabel || h.violation_type || 'Type';
            const hLevel = h.violation_level_name || h.violationLevelLabel || h.level || h.offense_level || 'Level';
            const hDate = h.created_at || h.violation_date || h.date;
            const hTime = h.violation_time || '00:00';
            const hLoc = h.locationLabel || h.location || 'N/A';
            const hBy = h.reported_by || h.reportedBy || 'N/A';
            
            const key = `${hType}|${hLevel}|${hDate}|${hTime}|${hLoc}|${hBy}`;
            if (seenHistory.has(key)) return false;
            seenHistory.add(key);
            return true;
        });
        
        // Sort by date descending
        studentHistory.sort((a, b) => {
             const dateA = new Date((a.created_at || a.violation_date || a.date) + ' ' + (a.violation_time || '00:00'));
             const dateB = new Date((b.created_at || b.violation_date || b.date) + ' ' + (b.violation_time || '00:00'));
             return dateB - dateA;
        });

        if (studentHistory.length > 0) {
            timelineEl.innerHTML = studentHistory.map(h => {
                const vType = v.violation_type_name || v.violationTypeLabel || v.violation_type || 'Type';
                const vLevel = v.violation_level_name || v.violationLevelLabel || v.level || v.offense_level || 'Level';
                const vDate = v.created_at || v.violation_date || v.date;
                const vTime = v.violation_time || '00:00';
                const vLoc = v.locationLabel || v.location || 'N/A';
                const vBy = v.reported_by || v.reportedBy || 'N/A';
                
                const hType = h.violation_type_name || h.violationTypeLabel || h.violation_type || 'Type';
                const hLevel = h.violation_level_name || h.violationLevelLabel || h.level || h.offense_level || 'Level';
                const hDate = h.created_at || h.violation_date || h.date;
                const hTime = h.violation_time || '00:00';
                const hLoc = h.locationLabel || h.location || 'N/A';
                const hBy = h.reported_by || h.reportedBy || 'N/A';

                const viewingKey = `${vType}|${vLevel}|${vDate}|${vTime}|${vLoc}|${vBy}`;
                const currentKey = `${hType}|${hLevel}|${hDate}|${hTime}|${hLoc}|${hBy}`;
                
                const isCurrent = viewingKey === currentKey;
                const activeClass = isCurrent ? 'current-viewing' : '';
                const hDateStr = formatDate(hDate);
                const hTimeStr = formatTime(hTime);
                
                let itemStatus = (h.status || '').toLowerCase();
                const hlLabel = hLevel.toLowerCase();
                const hIsDisciplinary = hlLabel.includes('warning 3') || hlLabel.includes('3rd') || hlLabel.includes('disciplinary');
                
                let statusHtml = '';
                if (itemStatus === 'resolved' || itemStatus === 'permitted') {
                    const label = hIsDisciplinary ? 'Resolved' : 'Permitted';
                    statusHtml = `<span style="color: green; font-weight: bold;">(${label})</span>`;
                } else if (hIsDisciplinary || itemStatus === 'disciplinary') {
                    statusHtml = '<span style="color: #e74c3c; font-weight: bold;">(Disciplinary)</span>';
                }

                return `
                <div class="timeline-item ${activeClass}">
                    <div class="timeline-marker"></div>
                    <div class="timeline-content">
                        <span class="timeline-date">${hDateStr} ${hTimeStr ? '• ' + hTimeStr : ''}</span>
                        <span class="timeline-title">
                            ${hLevel} - ${formatViolationType(hType)}
                            ${isCurrent ? '<span style="font-size: 10px; background: #eee; padding: 2px 6px; border-radius: 4px; margin-left: 5px;">Current</span>' : ''}
                        </span>
                        <span class="timeline-desc">
                            Reported at ${hLoc} 
                            ${statusHtml}
                        </span>
                    </div>
                </div>
            `}).join('');
        } else {
            timelineEl.innerHTML = '<p style="color: #6c757d; font-size: 14px; text-align: center; padding: 10px;">No history available.</p>';
        }
    }

    // Show Modal
    const modal = document.getElementById('ViolationDetailsModal');
    if (modal) {
        modal.style.display = 'flex';
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
}

function closeViolationModal() {
    const modal = document.getElementById('ViolationDetailsModal');
    if (modal) {
        modal.style.display = 'none';
        modal.classList.remove('active');
    }
}

// Close modal when clicking outside
document.addEventListener('click', function(e) {
    const modal = document.getElementById('ViolationDetailsModal');
    if (modal && modal.style.display === 'flex') {
        if (e.target === modal || e.target.classList.contains('Violations-modal-overlay')) {
            closeViolationModal();
        }
    }
});

// Global state for download context
window.downloadContext = 'violations'; // 'violations' or 'dashboard'

function downloadViolationsReport() {
    if (!userViolations || userViolations.length === 0) {
        alert('No violations to download.');
        return;
    }
    window.downloadContext = 'violations';
    openDownloadModal();
}

function openDownloadModal() {
    const modal = document.getElementById('DownloadFormatModal');
    if (modal) {
        modal.style.display = 'flex';
        setTimeout(() => modal.classList.add('active'), 10);
    }
}

function closeDownloadModal() {
    const modal = document.getElementById('DownloadFormatModal');
    if (modal) {
        modal.classList.remove('active');
        setTimeout(() => modal.style.display = 'none', 300);
    }
}

function confirmDownload(format) {
    closeDownloadModal();
    
    // Give modal time to close
    setTimeout(() => {
        if (window.downloadContext === 'violations') {
            if (format === 'csv') downloadCSV(userViolations, 'my_violations');
            else if (format === 'pdf') downloadPDF(userViolations, 'My Violation Report', 'my_violations');
            else if (format === 'docx') downloadDOCX(userViolations, 'My Violation Report', 'my_violations');
        } else if (window.downloadContext === 'dashboard') {
            if (window.downloadDashboardReport) {
                window.downloadDashboardReport(format);
            }
        }
    }, 300);
}

// Export functions to global scope for the modal
window.openDownloadModal = openDownloadModal;
window.closeDownloadModal = closeDownloadModal;
window.confirmDownload = confirmDownload;

function downloadCSV(data, filenamePrefix) {
    const lines = [];
    const now = new Date();
    
    // Get student name from cookies
    const cookies = Object.fromEntries(
        document.cookie.split(';').map(c => c.trim().split('=')).map(([k,v]) => [k, decodeURIComponent(v)])
    );
    const studentName = cookies.full_name || cookies.username || 'Student';
    const studentIdCode = cookies.student_id_code || cookies.student_id || 'N/A';
    
    // Header Info
    lines.push('My Violation Report');
    lines.push('Generated by,' + csvEscape(studentName));
    lines.push('Student ID,' + csvEscape(studentIdCode));
    lines.push('Generated on,' + csvEscape(now.toLocaleString()));
    lines.push('');
    
    // Column Headers
    lines.push(['Case ID', 'Violation Type', 'Level', 'Status', 'Date Reported'].map(csvEscape).join(','));

    // Data Rows
    data.forEach(v => {
        const type = formatViolationType(v.violationTypeLabel || v.violation_type_name || v.violation_type || v.type || 'Unknown');
        const date = formatDate(v.created_at || v.violation_date || v.date);
        const level = v.violationLevelLabel || v.violation_level_name || v.violation_level || v.level || 'Minor';
        const status = v.status || 'Unknown';
        
        lines.push([
            v.case_id || v.id,
            type,
            level,
            status,
            date
        ].map(csvEscape).join(','));
    });

    const csvContent = lines.join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const fileName = filenamePrefix + '_' + now.toISOString().slice(0, 10) + '.csv';
    
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

async function downloadPDF(data, title, filenamePrefix) {
    if (!window.jspdf) {
        alert('PDF library not loaded. Please refresh the page.');
        return;
    }
    
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();
    const now = new Date();

    // Get student name from cookies
    const cookies = Object.fromEntries(
        document.cookie.split(';').map(c => c.trim().split('=')).map(([k,v]) => [k, decodeURIComponent(v)])
    );
    const studentName = cookies.full_name || cookies.username || 'Student';
    const studentIdCode = cookies.student_id_code || cookies.student_id || 'N/A';

    // Calculate statistics for charts
    const stats = calculateViolationStats(data);

    // Add header image
    try {
        const headerImg = new Image();
        headerImg.src = '../app/assets/headers/header.png';
        await new Promise((resolve, reject) => {
            headerImg.onload = resolve;
            headerImg.onerror = reject;
            setTimeout(reject, 3000);
        });
        
        // Add header image at top (centered)
        const imgWidth = 180;
        const imgHeight = (headerImg.height / headerImg.width) * imgWidth;
        const xPos = (doc.internal.pageSize.width - imgWidth) / 2;
        doc.addImage(headerImg, 'PNG', xPos, 10, imgWidth, imgHeight);
        
        // Title below header
        let currentY = 10 + imgHeight + 10;
        doc.setFontSize(18);
        doc.setTextColor(0);
        doc.text(title, 14, currentY);
        
        doc.setFontSize(10);
        doc.setTextColor(100);
        doc.text(`Generated by: ${studentName} (${studentIdCode})`, 14, currentY + 7);
        doc.text(`Generated on: ${now.toLocaleString()}`, 14, currentY + 12);

        currentY += 22;

        // Add statistics summary boxes
        doc.setFontSize(11);
        doc.setTextColor(0);
        doc.setFillColor(212, 175, 55);
        doc.rect(14, currentY, 60, 20, 'F');
        doc.setTextColor(255);
        doc.text('Total Violations', 44, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(data.length), 44, currentY + 15, { align: 'center' });

        doc.setFillColor(239, 68, 68);
        doc.rect(80, currentY, 60, 20, 'F');
        doc.setFontSize(11);
        doc.text('Active', 110, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(stats.active), 110, currentY + 15, { align: 'center' });

        doc.setFillColor(34, 197, 94);
        doc.rect(146, currentY, 50, 20, 'F');
        doc.setFontSize(11);
        doc.text('Resolved', 171, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(stats.resolved), 171, currentY + 15, { align: 'center' });

        currentY += 28;

        // Generate charts as images
        const chartImages = await generateChartsForPDF(data, stats);
        
        if (chartImages.byType) {
            doc.setFontSize(12);
            doc.setTextColor(0);
            doc.text('Violations by Type', 14, currentY);
            currentY += 5;
            doc.addImage(chartImages.byType, 'PNG', 14, currentY, 90, 60);
        }

        if (chartImages.byStatus) {
            doc.text('Violations by Status', 110, currentY - 5);
            doc.addImage(chartImages.byStatus, 'PNG', 110, currentY, 90, 60);
        }

        currentY += 68;

        // Table Data
        const tableBody = data.map(v => [
            v.case_id || v.id,
            formatViolationType(v.violationTypeLabel || v.violation_type_name || v.violation_type || v.type || 'Unknown'),
            v.violationLevelLabel || v.violation_level_name || v.violation_level || v.level || 'Minor',
            v.status || 'Unknown',
            formatDate(v.created_at || v.violation_date || v.date)
        ]);

        doc.autoTable({
            head: [['Case ID', 'Violation Type', 'Level', 'Status', 'Date Reported']],
            body: tableBody,
            startY: currentY,
            theme: 'grid',
            styles: { fontSize: 9, cellPadding: 2 },
            headStyles: { fillColor: [212, 175, 55], textColor: 255, fontStyle: 'bold' }
        });
    } catch (error) {
        console.warn('Could not load header image, generating PDF without it:', error);
        
        // Fallback without header image
        let currentY = 22;
        doc.setFontSize(18);
        doc.text(title, 14, currentY);
        
        doc.setFontSize(10);
        doc.setTextColor(100);
        doc.text(`Generated by: ${studentName} (${studentIdCode})`, 14, currentY + 8);
        doc.text(`Generated on: ${now.toLocaleString()}`, 14, currentY + 14);

        currentY += 24;

        // Add statistics summary boxes
        doc.setFontSize(11);
        doc.setTextColor(0);
        doc.setFillColor(212, 175, 55);
        doc.rect(14, currentY, 60, 20, 'F');
        doc.setTextColor(255);
        doc.text('Total Violations', 44, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(data.length), 44, currentY + 15, { align: 'center' });

        doc.setFillColor(239, 68, 68);
        doc.rect(80, currentY, 60, 20, 'F');
        doc.setFontSize(11);
        doc.text('Active', 110, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(stats.active), 110, currentY + 15, { align: 'center' });

        doc.setFillColor(34, 197, 94);
        doc.rect(146, currentY, 50, 20, 'F');
        doc.setFontSize(11);
        doc.text('Resolved', 171, currentY + 8, { align: 'center' });
        doc.setFontSize(16);
        doc.text(String(stats.resolved), 171, currentY + 15, { align: 'center' });

        currentY += 28;

        // Generate charts
        const chartImages = await generateChartsForPDF(data, stats);
        
        if (chartImages.byType) {
            doc.setFontSize(12);
            doc.setTextColor(0);
            doc.text('Violations by Type', 14, currentY);
            currentY += 5;
            doc.addImage(chartImages.byType, 'PNG', 14, currentY, 90, 60);
        }

        if (chartImages.byStatus) {
            doc.text('Violations by Status', 110, currentY - 5);
            doc.addImage(chartImages.byStatus, 'PNG', 110, currentY, 90, 60);
        }

        currentY += 68;

        const tableBody = data.map(v => [
            v.case_id || v.id,
            formatViolationType(v.violationTypeLabel || v.violation_type_name || v.violation_type || v.type || 'Unknown'),
            v.violationLevelLabel || v.violation_level_name || v.violation_level || v.level || 'Minor',
            v.status || 'Unknown',
            formatDate(v.created_at || v.violation_date || v.date)
        ]);

        doc.autoTable({
            head: [['Case ID', 'Violation Type', 'Level', 'Status', 'Date Reported']],
            body: tableBody,
            startY: currentY,
            theme: 'grid',
            styles: { fontSize: 9, cellPadding: 2 },
            headStyles: { fillColor: [212, 175, 55], textColor: 255, fontStyle: 'bold' }
        });
    }

    doc.save(`${filenamePrefix}_${now.toISOString().slice(0, 10)}.pdf`);
}

// Helper function to calculate violation statistics
function calculateViolationStats(data) {
    const stats = {
        total: data.length,
        active: 0,
        resolved: 0,
        byType: {},
        byStatus: {}
    };

    data.forEach(v => {
        const status = (v.status || 'pending').toLowerCase();
        const type = formatViolationType(v.violationTypeLabel || v.violation_type_name || v.violation_type || v.type || 'Unknown');
        
        // Count by status
        if (status === 'resolved' || status === 'permitted') {
            stats.resolved++;
        } else {
            stats.active++;
        }

        // Count by type
        stats.byType[type] = (stats.byType[type] || 0) + 1;
        
        // Count by status detail
        stats.byStatus[status] = (stats.byStatus[status] || 0) + 1;
    });

    return stats;
}

// Helper function to generate charts as images for PDF
async function generateChartsForPDF(data, stats) {
    const chartImages = {};

    try {
        // Create temporary canvas for charts
        const canvas = document.createElement('canvas');
        canvas.width = 400;
        canvas.height = 300;
        const ctx = canvas.getContext('2d');

        // Chart 1: Violations by Type (Bar Chart)
        if (window.Chart && Object.keys(stats.byType).length > 0) {
            const typeLabels = Object.keys(stats.byType);
            const typeData = Object.values(stats.byType);
            
            const typeChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: typeLabels,
                    datasets: [{
                        label: 'Count',
                        data: typeData,
                        backgroundColor: ['#D4AF37', '#EF4444', '#3B82F6', '#10B981', '#F59E0B'],
                        borderColor: ['#B8860B', '#DC2626', '#2563EB', '#059669', '#D97706'],
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: false,
                    plugins: {
                        legend: { display: false },
                        title: { display: false }
                    },
                    scales: {
                        y: { beginAtZero: true, ticks: { stepSize: 1 } }
                    }
                }
            });

            await new Promise(resolve => setTimeout(resolve, 500));
            chartImages.byType = canvas.toDataURL('image/png');
            typeChart.destroy();
        }

        // Chart 2: Violations by Status (Pie Chart)
        if (window.Chart && Object.keys(stats.byStatus).length > 0) {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            const statusLabels = Object.keys(stats.byStatus).map(s => s.charAt(0).toUpperCase() + s.slice(1));
            const statusData = Object.values(stats.byStatus);
            
            const statusChart = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: statusLabels,
                    datasets: [{
                        data: statusData,
                        backgroundColor: ['#EF4444', '#F59E0B', '#10B981', '#3B82F6'],
                        borderColor: '#ffffff',
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: false,
                    plugins: {
                        legend: { 
                            display: true,
                            position: 'bottom',
                            labels: { boxWidth: 12, padding: 8, font: { size: 10 } }
                        }
                    }
                }
            });

            await new Promise(resolve => setTimeout(resolve, 500));
            chartImages.byStatus = canvas.toDataURL('image/png');
            statusChart.destroy();
        }

        canvas.remove();
    } catch (error) {
        console.warn('Could not generate charts:', error);
    }

    return chartImages;
}

async function downloadDOCX(data, title, filenamePrefix) {
    if (!window.docx) {
        alert('DOCX library not loaded. Please refresh the page.');
        return;
    }

    const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, HeadingLevel, ImageRun, AlignmentType } = window.docx;
    const now = new Date();

    // Get student name from cookies
    const cookies = Object.fromEntries(
        document.cookie.split(';').map(c => c.trim().split('=')).map(([k,v]) => [k, decodeURIComponent(v)])
    );
    const studentName = cookies.full_name || cookies.username || 'Student';
    const studentIdCode = cookies.student_id_code || cookies.student_id || 'N/A';

    // Load header image
    let headerImage = null;
    try {
        const response = await fetch('../app/assets/headers/header.png');
        const blob = await response.blob();
        const arrayBuffer = await blob.arrayBuffer();
        
        headerImage = new Paragraph({
            children: [
                new ImageRun({
                    data: arrayBuffer,
                    transformation: {
                        width: 600,
                        height: 100,
                    },
                }),
            ],
            alignment: AlignmentType.CENTER,
            spacing: { after: 400 },
        });
    } catch (error) {
        console.warn('Could not load header image for DOCX:', error);
    }

    // Table Header
    const tableHeader = new TableRow({
        children: [
            new TableCell({ children: [new Paragraph({ text: "Case ID", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Violation Type", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Level", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Status", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Date Reported", bold: true })] }),
        ],
    });

    // Table Rows
    const tableRows = data.map(v => {
        return new TableRow({
            children: [
                new TableCell({ children: [new Paragraph(String(v.case_id || v.id))] }),
                new TableCell({ children: [new Paragraph(formatViolationType(v.violationTypeLabel || v.violation_type_name || v.violation_type || v.type || 'Unknown'))] }),
                new TableCell({ children: [new Paragraph(v.violationLevelLabel || v.violation_level_name || v.violation_level || v.level || 'Minor')] }),
                new TableCell({ children: [new Paragraph(v.status || 'Unknown')] }),
                new TableCell({ children: [new Paragraph(formatDate(v.created_at || v.violation_date || v.date))] }),
            ],
        });
    });

    const children = [];
    
    // Add header image if loaded
    if (headerImage) {
        children.push(headerImage);
    }
    
    // Add title and metadata
    children.push(
        new Paragraph({
            text: title,
            heading: HeadingLevel.HEADING_1,
            spacing: { after: 200 },
        }),
        new Paragraph({
            children: [
                new TextRun({
                    text: `Generated by: ${studentName} (${studentIdCode})`,
                    italics: true,
                    color: "666666",
                }),
            ],
            spacing: { after: 100 },
        }),
        new Paragraph({
            children: [
                new TextRun({
                    text: `Generated on: ${now.toLocaleString()}`,
                    italics: true,
                    color: "666666",
                }),
            ],
            spacing: { after: 400 },
        }),
        new Table({
            rows: [tableHeader, ...tableRows],
            width: {
                size: 100,
                type: WidthType.PERCENTAGE,
            },
        })
    );

    const doc = new Document({
        sections: [{
            properties: {},
            children: children,
        }],
    });

    Packer.toBlob(doc).then(blob => {
        saveAs(blob, `${filenamePrefix}_${now.toISOString().slice(0, 10)}.docx`);
    });
}

function csvEscape(value) {
    if (value === null || value === undefined) return '';
    const str = String(value);
    if (/[",\n]/.test(str)) {
        return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
}

function printViolationSlip() {
    if (!currentViolationId) {
        alert('No violation selected');
        return;
    }
    const url = `${API_BASE}violations.php?action=generate_slip&violation_id=${currentViolationId}`;
    window.open(url, '_blank');
}

/*********************************************************
 * UTILS
 *********************************************************/
async function updateSlipStatusUI(violationId) {
    const requestBtn = document.getElementById('requestSlipBtn');
    const downloadBtn = document.getElementById('downloadSlipBtn');
    
    if (!requestBtn || !downloadBtn) return;

    // Default: hide both
    requestBtn.style.display = 'none';
    downloadBtn.style.display = 'none';

    try {
        const response = await fetch(`${API_BASE}violations.php?action=slip_status&violation_id=${violationId}`);
        const result = await response.json();
        
        if (result.status === 'success') {
            const status = result.data.request_status;
            
            if (!status) {
                // No request yet
                requestBtn.style.display = 'inline-flex';
                requestBtn.innerHTML = "<i class='bx bx-paper-plane'></i> Request Receipt";
                requestBtn.disabled = false;
            } else if (status === 'pending') {
                // Request sent, waiting for admin
                requestBtn.style.display = 'inline-flex';
                requestBtn.innerHTML = "<i class='bx bx-time'></i> Pending Approval";
                requestBtn.disabled = true;
            } else if (status === 'approved') {
                // Approved, can download
                downloadBtn.style.display = 'inline-flex';
            } else if (status === 'denied') {
                // Denied, can request again
                requestBtn.style.display = 'inline-flex';
                requestBtn.innerHTML = "<i class='bx bx-redo'></i> Request Again (Denied)";
                requestBtn.disabled = false;
            }
        }
    } catch (error) {
        console.error('Error checking slip status:', error);
    }
}

async function handleStudentSlipRequest() {
    if (!currentViolationId) return;
    
    const requestBtn = document.getElementById('requestSlipBtn');
    if (requestBtn) {
        requestBtn.disabled = true;
        requestBtn.innerHTML = "<i class='bx bx-loader-alt bx-spin'></i> Sending...";
    }

    try {
        const response = await fetch(`${API_BASE}violations.php?action=request_slip&violation_id=${currentViolationId}`, {
            method: 'POST'
        });
        const result = await response.json();
        
        if (result.status === 'success') {
            showNotification(result.message, 'success');
            updateSlipStatusUI(currentViolationId);
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        showNotification('Request failed: ' + error.message, 'error');
        if (requestBtn) {
            requestBtn.disabled = false;
            requestBtn.innerHTML = "<i class='bx bx-paper-plane'></i> Request Receipt";
        }
    }
}

function formatDate(d) {
    if (!d) return '-';
    return new Date(d).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatViolationType(type) {
    if (!type) return 'Unknown';
    type = String(type);
    
    const typeMap = {
        'improper_uniform': 'Improper Uniform',
        'improper_footwear': 'Improper Footwear',
        'no_id': 'No ID Card',
        'misconduct': 'Misconduct'
    };
    
    if (typeMap[type.toLowerCase()]) return typeMap[type.toLowerCase()];
    
    const lowerType = type.toLowerCase();
    for (const [key, value] of Object.entries(typeMap)) {
        if (lowerType.includes(key.replace('_', ' ')) || lowerType === key) {
            return value;
        }
    }
    
    return type.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

/*********************************************************
 * EXPORTS
 *********************************************************/
window.initUserViolations = initUserViolations;
window.filterViolations = filterViolations;
window.viewViolationDetails = viewViolationDetails;
window.closeViolationModal = closeViolationModal;
window.printViolationSlip = printViolationSlip;
window.downloadCSV = downloadCSV;
window.downloadPDF = downloadPDF;
window.downloadDOCX = downloadDOCX;
window.updateViolationStats = updateViolationStats;
