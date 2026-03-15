<?php
require_once __DIR__ . '/../../core/View.php';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Violations | OSAS System</title>
  <link href='https://unpkg.com/boxicons@2.0.9/css/boxicons.min.css' rel='stylesheet'>
  <link rel="stylesheet" href="<?= View::asset('styles/violation.css') ?>">
</head>
<body>
  
<!-- Violations.html -->
<main id="Violations-page">
  <!-- HEADER -->
  <div class="Violations-head-title">
    <div class="Violations-left">
      <h1>Violations</h1>
      <p class="Violations-subtitle">Manage and track student violations in the institution</p>
      <ul class="Violations-breadcrumb">
        <li><a href="#">Dashboard</a></li>
        <li><i class='bx bx-chevron-right'></i></li>
        <li><a class="active" href="#">Violations Data</a></li>
      </ul>
    </div>

    <div class="Violations-header-actions">
      <div class="Violations-button-group">
        <button id="btnMonthlyReset" class="Violations-btn outline small warning" title="Archive old violations and reset student levels">
          <i class='bx bx-reset'></i>
          <span>Monthly Reset</span>
        </button>
        <!-- Import button removed -->
        <button id="btnExportViolations" class="Violations-btn outline small">
          <i class='bx bx-download'></i>
          <span>Export</span>
        </button>
      </div>
      <div class="Violations-button-group">
        <button id="btnAddViolations" class="Violations-btn primary">
          <i class='bx bx-plus'></i> Record Violation
        </button>
      </div>
    </div>
  </div>

  <!-- STATS CARDS -->
  <div class="Violations-stats-overview">
    <div class="Violations-stat-card">
      <div class="Violations-stat-icon">
        <i class='bx bx-error-circle'></i>
      </div>
      <div class="Violations-stat-content">
        <h3 class="Violations-stat-title">Total Violations</h3>
        <div class="Violations-stat-value" id="totalViolations">0</div>
        <div class="Violations-stat-change negative">
          <i class='bx bx-up-arrow-alt'></i>
          <span>+18 this week</span>
        </div>
      </div>
    </div>

    <div class="Violations-stat-card">
      <div class="Violations-stat-icon">
        <i class='bx bx-check-circle'></i>
      </div>
      <div class="Violations-stat-content">
        <h3 class="Violations-stat-title">Resolved</h3>
        <div class="Violations-stat-value" id="resolvedViolations">0</div>
        <div class="Violations-stat-percentage" id="resolvedViolationsPct">0%</div>
      </div>
    </div>

    <div class="Violations-stat-card">
      <div class="Violations-stat-icon">
        <i class='bx bx-time-five'></i>
      </div>
      <div class="Violations-stat-content">
        <h3 class="Violations-stat-title">Pending</h3>
        <div class="Violations-stat-value" id="pendingViolations">0</div>
        <div class="Violations-stat-percentage" id="pendingViolationsPct">0%</div>
      </div>
    </div>

    <div class="Violations-stat-card">
      <div class="Violations-stat-icon">
        <i class='bx bx-user-voice'></i>
      </div>
      <div class="Violations-stat-content">
        <h3 class="Violations-stat-title">Disciplinary</h3>
        <div class="Violations-stat-value" id="disciplinaryViolations">0</div>
        <div class="Violations-stat-percentage" id="disciplinaryViolationsPct">0%</div>
      </div>
    </div>
  </div>

  <!-- MAIN CONTENT CARD -->
  <div class="Violations-content-card">
    <!-- Table Header -->
    <div class="Violations-table-header">
      <div class="Violations-header-left">
        <h2 class="Violations-table-title" id="violationsTableTitle">Violations List</h2>
        <div class="Violations-tabs">
          <button class="Violations-tab-btn active" data-view="current">Current Month</button>
          <button class="Violations-tab-btn" data-view="archive">Archive</button>
        </div>
      </div>

      <div class="Violations-header-right">
        <!-- Current Month Filters -->
        <div id="currentFilters" class="Violations-filter-group">
          <div class="Violations-search-box">
            <i class='bx bx-search'></i>
            <input type="text" id="searchViolation" placeholder="Search violations...">
          </div>

          <div class="Violations-date-filter">
            <input type="date" id="ViolationDateFrom" class="Violations-filter-date" title="From Date">
            <span>to</span>
            <input type="date" id="ViolationDateTo" class="Violations-filter-date" title="To Date">
          </div>

          <select id="ViolationsFilter" class="Violations-filter-select">
            <option value="all">All Departments</option>
            <!-- Departments will be loaded via JS -->
          </select>

          <select id="ViolationsStatusFilter" class="Violations-filter-select">
            <option value="all">All Status</option>
            <option value="permitted">Permitted</option>
            <option value="warning">Warning</option>
            <option value="disciplinary">Disciplinary</option>
            <option value="resolved">Resolved</option>
          </select>
        </div>

        <!-- Archive Filters (Initially Hidden) -->
        <div id="archiveFilters" class="Violations-filter-group" style="display: none;">
          <div class="Violations-search-box">
            <i class='bx bx-search'></i>
            <input type="text" id="searchViolationArchive" placeholder="Search archive...">
          </div>

          <div class="Violations-date-filter">
            <input type="date" id="ArchiveDateFrom" class="Violations-filter-date" title="From Date">
            <span>to</span>
            <input type="date" id="ArchiveDateTo" class="Violations-filter-date" title="To Date">
          </div>

          <select id="ArchiveDeptFilter" class="Violations-filter-select">
            <option value="all">All Departments</option>
            <!-- Departments will be loaded via JS -->
          </select>
          
          <select id="ArchiveMonthFilter" class="Violations-filter-select">
            <option value="all">All Months</option>
            <?php
            for ($i = 1; $i <= 12; $i++) {
                $month = date('F', mktime(0, 0, 0, $i, 1));
                echo "<option value='$i'>$month</option>";
            }
            ?>
          </select>
        </div>

        <button class="Violations-filter-btn" title="More filters">
          <i class='bx bx-filter-alt'></i>
        </button>
      </div>
    </div>

    <!-- Violations Table -->
    <div class="Violations-table-container">
      <table class="Violations-table">
        <thead>
          <tr>
            <th class="Violations-sortable" data-sort="id">
              <div class="Violations-table-header-content">
                <span>Case ID</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Student</th>
            <th class="Violations-sortable" data-sort="studentId">
              <div class="Violations-table-header-content">
                <span>Student ID</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th class="Violations-sortable" data-sort="name">
              <div class="Violations-table-header-content">
                <span>Violation Type</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Level</th>
            <th class="Violations-sortable" data-sort="department">
              <div class="Violations-table-header-content">
                <span>Department</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Section</th>
            <th>Year Level</th>
            <th class="Violations-sortable" data-sort="date">
              <div class="Violations-table-header-content">
                <span>Date Reported</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>

        <tbody id="ViolationsTableBody">
          <!-- Data will be loaded dynamically -->
        </tbody>
      </table>
    </div>

    <!-- Table Footer -->
    <div class="Violations-table-footer">
      <div class="Violations-footer-info">
        Showing <span id="showingViolationsCount">4</span> of <span id="totalViolationsCount">48</span> violations
      </div>
      <div class="Violations-pagination">
        <button class="Violations-pagination-btn" disabled>
          <i class='bx bx-chevron-left'></i>
        </button>
        <button class="Violations-pagination-btn active">1</button>
        <button class="Violations-pagination-btn">2</button>
        <button class="Violations-pagination-btn">3</button>
        <button class="Violations-pagination-btn">4</button>
        <button class="Violations-pagination-btn">5</button>
        <button class="Violations-pagination-btn">
          <i class='bx bx-chevron-right'></i>
        </button>
      </div>
    </div>
  </div>

  <!-- VIOLATION RECORDING MODAL -->
  <div id="ViolationRecordModal" class="Violations-modal">
    <div class="Violations-modal-overlay" id="ViolationModalOverlay"></div>
    <div class="Violations-modal-container">
      <div class="Violations-modal-header">
        <h2 id="violationModalTitle">
          <i class='bx bxs-shield-x'></i>
          <span>Record New Violation</span>
        </h2>
        <button class="Violations-close-btn" id="closeRecordModal">
          <i class='bx bx-x'></i>
        </button>
        <div class="form-progress" id="violationFormProgress"></div>
      </div>

      <form id="ViolationRecordForm" enctype="multipart/form-data">
        <!-- Student Search Section -->
        <div class="Violations-form-group">
            <label for="studentSearch">Search Student</label>
          <div class="student-search-wrapper">
            <input type="text" id="studentSearch" placeholder="Search by Student ID or Name...">
            <button type="button" class="Violations-search-btn">
              <i class='bx bx-search-alt'></i> Search
            </button>
            <button type="button" class="Violations-refresh-btn" id="refreshStudentsBtn" title="Refresh student data">
              <i class='bx bx-refresh'></i>
            </button>
          </div>
        </div>

        <!-- Student Info Card -->
        <div class="violation-student-info-card selected">
          <div class="violation-student-image">
            <img id="modalStudentImage" 
                 src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100'%3E%3Ccircle cx='50' cy='40' r='20' fill='%23ccc'/%3E%3Ccircle cx='50' cy='100' r='40' fill='%23ccc'/%3E%3C/svg%3E" 
                 alt="Student Image"
                 onerror="this.src='https://ui-avatars.com/api/?name=Student&background=ffd700&color=333&size=80'">
          </div>
          <div class="violation-student-details">
            <div class="violation-detail-row">
              <span class="violation-detail-label">Student ID:</span>
              <span id="modalStudentId" class="violation-detail-value">2023-001</span>
            </div>
            <div class="violation-detail-row">
              <span class="violation-detail-label">Name:</span>
              <span id="modalStudentName" class="violation-detail-value">John Michael Doe</span>
            </div>
            <div class="violation-detail-row">
              <span class="violation-detail-label">Department:</span>
              <span id="modalStudentDept" class="violation-detail-value">BS Information Technology</span>
            </div>
            <div class="violation-detail-row">
              <span class="violation-detail-label">Section:</span>
              <span id="modalStudentSection" class="violation-detail-value">BSIT-3A</span>
            </div>
            <div class="violation-detail-row">
              <span class="violation-detail-label">Year Level:</span>
              <span id="modalStudentYearlevel" class="violation-detail-value">3rd Year</span>
            </div>
            <div class="violation-detail-row">
              <span class="violation-detail-label">Contact:</span>
              <span id="modalStudentContact" class="violation-detail-value">+63 912 345 6789</span>
            </div>
          </div>
        </div>

        <!-- Violation Type Selection -->
        <div class="violation-type-section">
          <h3>Violation Type</h3>
          <div class="violation-types" id="violationTypesContainer">
            <!-- Loaded dynamically via JS -->
            <p style="text-align: center; color: #666; width: 100%;">Loading violation types...</p>
          </div>
        </div>

        <!-- Violation Level Selection -->
        <div class="violation-level-section">
          <h3>Violation Level</h3>
          <div class="violation-level-buttons" id="violationLevelsContainer">
            <!-- Loaded dynamically via JS -->
            <p style="text-align: center; color: #666; width: 100%;">Select a violation type first</p>
          </div>
        </div>

        <!-- Additional Details -->
        <div class="violation-details-section">
          <div class="Violations-form-row">
            <div class="Violations-form-group">
              <label for="violationDate">Date of Violation</label>
              <input type="date" id="violationDate" name="violationDate">
            </div>

            <div class="Violations-form-group">
              <label for="violationTime">Time of Violation</label>
              <input type="time" id="violationTime" name="violationTime">
            </div>
          </div>

          <div class="Violations-form-group">
            <label for="violationLocation">Location</label>
            <select id="violationLocation" name="violationLocation">
              <option value="">Select location</option>
              <option value="gate_1">Main Gate 1</option>
              <option value="gate_2">Gate 2</option>
              <option value="classroom">Classroom</option>
              <option value="library">Library</option>
              <option value="cafeteria">Cafeteria</option>
              <option value="gym">Gymnasium</option>
              <option value="others">Others</option>
            </select>
          </div>

          <div class="Violations-form-group">
            <label for="reportedBy">Reported By</label>
            <input type="text" id="reportedBy" name="reportedBy" placeholder="Admin Full Name" maxlength="100" value="<?= htmlspecialchars(($_SESSION['full_name'] ?? $_SESSION['username'] ?? ''), ENT_QUOTES, 'UTF-8') ?>" readonly style="background-color: #f8f9fa; cursor: not-allowed; border: 1px solid #ddd;">
          </div>

          <div class="Violations-form-group" style="position: relative;">
            <label for="violationNotes">Additional Notes</label>
            <textarea id="violationNotes" name="violationNotes" rows="3" placeholder="Enter detailed description of the violation..." maxlength="500"></textarea>
          </div>
        </div>

        <!-- Attachments -->
        <div class="violation-attachments">
          <h4>Attachments (Optional)</h4>
          <div class="attachments-compact-wrapper">
            <div class="attachment-upload">
              <input type="file" id="violationAttachment" name="violationAttachment" accept="image/*,.pdf,.doc,.docx" multiple>
              <label for="violationAttachment" class="attachment-label">
                <i class='bx bx-plus-circle'></i>
                <span>Add Evidence</span>
              </label>
            </div>
            <!-- Attachment Previews -->
            <div id="attachmentPreviews" class="attachment-previews-container"></div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="Violations-form-actions">
          <button type="button" class="Violations-btn-outline" id="cancelRecordModal">Cancel</button>
          <button type="button" class="Violations-btn-outline entrance-btn" id="modalEntranceBtn" style="display: none;">
            <i class='bx bx-receipt'></i> Entrance Slip
          </button>
          <button type="submit" class="Violations-btn-primary">Record Violation</button>
        </div>
      </form>
    </div>
  </div>

  <!-- VIOLATION DETAILS MODAL -->
  <div id="ViolationDetailsModal" class="Violations-modal">
    <div class="Violations-modal-overlay" id="DetailsModalOverlay"></div>
    <div class="Violations-modal-container">
      <div class="Violations-modal-header">
        <h2>
          <i class='bx bxs-info-circle'></i>
          <span>Violation Details</span>
        </h2>
        <button class="Violations-close-btn" id="closeDetailsModal">
          <i class='bx bx-x'></i>
        </button>
      </div>

      <div class="violation-details-content">
        <!-- Case Header -->
        <div class="case-header">
          <span class="case-id">Case: <span id="detailCaseId">VIOL-2024-001</span></span>
          <span class="case-status-badge warning" id="detailStatusBadge">Warning</span>
        </div>

        <!-- Student Info -->
        <div class="violation-student-info-card detailed">
          <div class="violation-student-image">
            <img id="detailStudentImage" 
                 src="https://ui-avatars.com/api/?name=Student&background=ffd700&color=333&size=80" 
                 alt="Student"
                 onerror="this.src='https://ui-avatars.com/api/?name=Student&background=ffd700&color=333&size=80'">
          </div>
          <div class="violation-student-details">
            <h3 id="detailStudentName">Student Name</h3>
            <div class="student-meta">
              <span class="student-id">ID: <span id="detailStudentId">2023-001</span></span>
              <span class="student-dept badge bsis" id="detailStudentDept">BSIS</span>
              <span class="student-section">Section: <span id="detailStudentSection">N/A</span></span>
            </div>
            <div class="student-contact">
              <i class='bx bx-phone'></i> <span id="detailStudentContact">N/A</span>
            </div>
          </div>
        </div>

        <!-- Violation Details -->
        <div class="violation-details-grid">
          <div class="detail-item">
            <span class="detail-label">Violation Type:</span>
            <span class="detail-value badge uniform" id="detailViolationType">Improper Uniform</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">Level:</span>
            <span class="detail-value badge warning" id="detailViolationLevel">Warning 2</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">Date & Time:</span>
            <span class="detail-value" id="detailDateTime">Feb 15, 2024 • 08:15 AM</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">Location:</span>
            <span class="detail-value" id="detailLocation">Main Gate 1</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">Reported By:</span>
            <span class="detail-value" id="detailReportedBy">Officer Maria Santos</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">Status:</span>
            <span class="detail-value badge warning" id="detailStatus">Active Warning</span>
          </div>
        </div>

        <!-- Notes Section -->
        <div class="violation-notes-section">
          <h4>Violation Description</h4>
          <div class="notes-content">
            <p id="detailNotes">No notes available.</p>
          </div>
        </div>

        <!-- Evidence Section -->
        <div class="violation-evidence-section">
          <h4>Evidence / Attachments</h4>
          <div id="detailAttachments" class="attachments-grid">
            <p class="no-attachments">No attachments available.</p>
          </div>
        </div>

        <!-- History Timeline -->
        <div class="violation-history">
          <h4>Violation History</h4>
          <div class="timeline" id="detailTimeline">
            <!-- Populated dynamically -->
            <p style="color: #6c757d; font-size: 14px;">No history available.</p>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="violation-details-actions">
          <button class="Violations-action-btn edit" id="detailEditBtn" title="Edit">
            <i class='bx bx-edit'></i> Edit
          </button>
          <button class="Violations-action-btn resolve" id="detailResolveBtn" title="Mark Resolved">
            <i class='bx bx-check'></i> Mark Resolved
          </button>
          <button class="Violations-action-btn escalate" id="detailEscalateBtn" title="Escalate">
            <i class='bx bx-alarm'></i> Escalate
          </button>
          <button class="Violations-action-btn print" id="detailPrintBtn" title="Print">
            <i class='bx bx-printer'></i> Print Report
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Empty State -->
  <div class="Violations-empty-state" id="ViolationsEmptyState" style="display: none;">
    <div class="Violations-empty-icon">
      <i class='bx bx-error-circle'></i>
    </div>
    <h3>No Violations Found</h3>
    <p>No violation records have been created yet</p>
    <button class="Violations-btn-primary" id="btnRecordFirstViolation">
      <i class='bx bx-plus'></i> Record First Violation
    </button>
  </div>

  <!-- STUDENT DETAILS PANEL (shown when searching by student ID) -->
  <div class="student-details-panel" id="studentDetailsPanel" style="display: none;">
    <div class="student-details-header">
      <h2>Student Violation Details</h2>
      <button class="student-details-close" id="closeStudentDetails">
        <i class='bx bx-x'></i>
      </button>
    </div>

    <div class="student-profile-section">
      <div class="student-profile-card" id="studentProfileCard">
        <!-- Student info will be populated dynamically -->
      </div>

      <div class="student-stats-grid" id="studentStatsGrid">
        <!-- Statistics will be populated dynamically -->
      </div>
    </div>

    <div class="student-violations-section">
      <h3>Violation History</h3>
      <div class="student-violations-timeline" id="studentViolationsTimeline">
        <!-- Violation timeline will be populated dynamically -->
      </div>
    </div>
  </div>

  <!-- Export Modal -->
  <div id="ExportViolationsModal" class="Violations-modal">
    <div class="Violations-modal-overlay" id="ExportModalOverlay"></div>
    <div class="Violations-modal-container" style="max-width: 400px;">
      <div class="Violations-modal-header">
        <h2>
          <i class='bx bx-download'></i>
          <span>Export Violations Data</span>
        </h2>
        <button class="Violations-close-btn" id="closeExportModal">
          <i class='bx bx-x'></i>
        </button>
      </div>
      <div class="Violations-modal-body" style="padding: 20px;">
        <p style="margin-bottom: 20px; color: #666;">Select your preferred format to download the violation records.</p>
        <div class="export-options" style="display: flex; flex-direction: column; gap: 10px;">
          <button id="exportPDF" class="Violations-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-pdf' style="color: #e74c3c; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as PDF</span>
          </button>
          <button id="exportExcel" class="Violations-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-export' style="color: #27ae60; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as Excel (.xls)</span>
          </button>
          <button id="exportWord" class="Violations-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-doc' style="color: #3498db; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as Word (DOCX)</span>
          </button>
        </div>
      </div>
    </div>
  </div>

</main>

<!-- Load Docx Generation Libraries -->
<script src="<?= View::asset('js/lib/docxtemplater.js') ?>"></script>
<script src="<?= View::asset('js/lib/pizzip.js') ?>"></script>
<script src="<?= View::asset('js/lib/FileSaver.js') ?>"></script>
<script src="<?= View::asset('js/lib/pizzip-utils.js') ?>"></script>

<!-- Load Libraries for Export -->
<script src="<?= View::asset('js/lib/jspdf.umd.min.js') ?>"></script>
<script src="<?= View::asset('js/lib/jspdf.plugin.autotable.min.js') ?>"></script>
<script src="<?= View::asset('js/lib/docx.js') ?>"></script>
<script src="<?= View::asset('js/lib/FileSaver.js') ?>"></script>

</body>
</html>


