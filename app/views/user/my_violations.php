<?php
require_once __DIR__ . '/../../core/View.php';
?>
<link rel="stylesheet" href="<?= View::asset('styles/violation.css') ?>">

<main id="Violations-page">
  <!-- HEADER -->
  <div class="Violations-head-title">
    <div class="Violations-left">
      <h1>My Violations</h1>
      <ul class="Violations-breadcrumb">
        <li><a href="#">Dashboard</a></li>
        <li><i class='bx bx-chevron-right'></i></li>
        <li><a class="active" href="#">My Violations</a></li>
      </ul>
    </div>
    <div class="Violations-header-actions">
        <a href="#" class="Violations-btn primary" id="btnDownloadReport">
            <i class='bx bxs-download'></i> Download Report
        </a>
    </div>
  </div>

  <!-- STATS CARDS -->
  <div class="Violations-stats-overview">
    <div class="Violations-stat-card">
      <div class="Violations-stat-icon">
        <i class='bx bxs-t-shirt'></i>
      </div>
      <div class="Violations-stat-content">
        <h3 class="Violations-stat-title">Improper Uniform</h3>
        <div class="Violations-stat-value" id="statUniform">0</div>
      </div>
    </div>

    <div class="Violations-stat-card">
        <div class="Violations-stat-icon">
            <i class='bx bxs-shopping-bag-alt'></i>
        </div>
        <div class="Violations-stat-content">
            <h3 class="Violations-stat-title">Improper Footwear</h3>
            <div class="Violations-stat-value" id="statFootwear">0</div>
        </div>
    </div>

    <div class="Violations-stat-card">
        <div class="Violations-stat-icon">
            <i class='bx bxs-id-card'></i>
        </div>
        <div class="Violations-stat-content">
            <h3 class="Violations-stat-title">No ID Card</h3>
            <div class="Violations-stat-value" id="statId">0</div>
        </div>
    </div>

    <div class="Violations-stat-card">
        <div class="Violations-stat-icon">
            <i class='bx bxs-calendar-check'></i>
        </div>
        <div class="Violations-stat-content">
            <h3 class="Violations-stat-title">Total Violations</h3>
            <div class="Violations-stat-value" id="statTotal">0</div>
        </div>
    </div>
  </div>

  <!-- CONTENT CARD -->
  <div class="Violations-content-card">
    <div class="Violations-table-header">
        <div class="Violations-header-left">
            <h2 class="Violations-table-title">Violation History</h2>
        </div>
        <div class="Violations-header-right">
             <div class="Violations-search-box">
                <i class='bx bx-search'></i>
                <input type="text" id="searchViolation" placeholder="Search violations...">
             </div>
             <select id="violationFilter" class="Violations-filter-select" onchange="filterViolations()">
                <option value="all">All Types</option>
                <option value="improper_uniform">Improper Uniform</option>
                <option value="improper_footwear">Improper Footwear</option>
                <option value="no_id">No ID Card</option>
             </select>
             <select id="statusFilter" class="Violations-filter-select" onchange="filterViolations()">
                <option value="all">All Status</option>
                <option value="resolved">Resolved / Permitted</option>
                <option value="pending">Pending</option>
                <option value="warning">Warning</option>
             </select>
        </div>
    </div>

    <div class="Violations-table-container">
        <table class="Violations-table">
            <thead>
                <tr>
                    <th>Case ID</th>
                    <th>Violation Type</th>
                    <th>Offense Level</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody id="violationsTableBody">
                <!-- Loaded via JS -->
                 <tr>
                    <td colspan="6" style="text-align: center; padding: 40px;">
                        <div class="loading-spinner"></div>
                        <p>Loading violations...</p>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
    
    <!-- Table Footer -->
    <div class="Violations-table-footer">
      <div class="Violations-footer-info">
        Showing <span id="showingViolationsCount">0</span> violations
      </div>
    </div>
  </div>

  <!-- DETAILS MODAL -->
  <div id="ViolationDetailsModal" class="Violations-modal" style="display: none;">
    <div class="Violations-modal-overlay" id="modalOverlay" onclick="closeViolationModal()"></div>
    <div class="Violations-modal-container">
        <div class="Violations-modal-header">
            <h2>
                <i class='bx bxs-info-circle'></i>
                <span>Violation Details</span>
            </h2>
            <button class="Violations-close-btn" onclick="closeViolationModal()">
                <i class='bx bx-x'></i>
            </button>
        </div>

        <div class="violation-details-content">
            <!-- Case Header -->
            <div class="case-header">
                <span class="case-id">Case: <span id="detailCaseId">-</span></span>
                <span class="case-status-badge" id="detailStatusBadge">-</span>
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
                        <span class="student-id">ID: <span id="detailStudentId">-</span></span>
                        <span class="student-dept badge" id="detailStudentDept">-</span>
                        <span class="student-section">Section: <span id="detailStudentSection">-</span></span>
                    </div>
                    <div class="student-contact">
                        <i class='bx bx-phone'></i> <span id="detailStudentContact">-</span>
                    </div>
                </div>
            </div>

            <div class="violation-details-grid">
                <div class="detail-item">
                    <span class="detail-label">Violation Type:</span>
                    <span class="detail-value badge" id="detailViolationType">-</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Level:</span>
                    <span class="detail-value badge warning" id="detailViolationLevel">-</span>
                </div>
                 <div class="detail-item">
                    <span class="detail-label">Date & Time:</span>
                    <span class="detail-value" id="detailDateTime">-</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Location:</span>
                    <span class="detail-value" id="detailLocation">-</span>
                </div>
                 <div class="detail-item">
                    <span class="detail-label">Reported By:</span>
                    <span class="detail-value" id="detailReportedBy">-</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">Status:</span>
                    <span class="detail-value badge warning" id="detailStatus">-</span>
                </div>
            </div>

            <div class="violation-notes-section">
                <h4>Violation Description</h4>
                <div class="notes-content">
                    <p id="detailNotes">-</p>
                </div>
            </div>

            <!-- Evidence Section -->
            <div class="violation-evidence-section" id="evidenceSection">
                <h4>Evidence / Attachments</h4>
                <div id="detailAttachments" class="attachments-grid">
                    <p class="no-attachments">No attachments available.</p>
                </div>
            </div>
            
             <div class="violation-notes-section" id="resolutionSection" style="display:none;">
                <h4>Resolution</h4>
                <div class="notes-content">
                    <p id="detailResolution">-</p>
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

            <div class="Violations-form-actions">
                <button class="Violations-btn primary" onclick="printViolationSlip()">
                    <i class='bx bxs-printer'></i> Print Slip
                </button>
                <button class="Violations-btn-outline" onclick="closeViolationModal()">Close</button>
            </div>
        </div>
    </div>
  </div>
</main>
