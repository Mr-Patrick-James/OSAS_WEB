<?php
require_once __DIR__ . '/../../core/View.php';
?>
<?php
require_once '../../config/db_connect.php';
?>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Students | OSAS System</title>
  <link href='https://unpkg.com/boxicons@2.0.9/css/boxicons.min.css' rel='stylesheet'>
  <link rel="stylesheet" href="<?= View::asset('styles/students.css') ?>">
</head>
<body>
  
<!-- Students.html -->
<main id="Students-page">

  <!-- HEADER -->
  <div class="Students-head-title">
    <div class="Students-left">
      <h1>Students</h1>
      <p class="Students-subtitle">Manage all student records in the institution</p>
      <ul class="Students-breadcrumb">
        <li><a href="#">Dashboard</a></li>
        <li><i class='bx bx-chevron-right'></i></li>
        <li><a class="active" href="#">Students Data</a></li>
      </ul>
    </div>

    <div class="Students-header-actions">
      <div class="Students-button-group">
        <button id="btnImportStudents" class="Students-btn outline small">
          <i class='bx bx-upload'></i>
          <span>Import</span>
        </button>
        <button id="btnExportStudents" class="Students-btn outline small">
          <i class='bx bx-download'></i>
          <span>Export</span>
        </button>
        <button id="btnArchivedStudents" class="Students-btn outline small">
          <i class='bx bx-archive'></i>
          <span>Archived</span>
        </button>
      </div>
      <button id="btnAddStudents" class="Students-btn primary">
        <i class='bx bx-plus'></i> Add Student
      </button>
    </div>
  </div>

  <!-- STATS CARDS -->
  <div class="Students-stats-overview">
    <div class="Students-stat-card">
      <div class="Students-stat-icon">
        <i class='bx bx-user'></i>
      </div>
      <div class="Students-stat-content">
        <h3 class="Students-stat-title">Total Students</h3>
        <div class="Students-stat-value" id="totalStudents">0</div>
        <div class="Students-stat-change positive">
          <i class='bx bx-up-arrow-alt'></i>
          <span>+25 this month</span>
        </div>
      </div>
    </div>

    <div class="Students-stat-card">
      <div class="Students-stat-icon">
        <i class='bx bx-user-check'></i>
      </div>
      <div class="Students-stat-content">
        <h3 class="Students-stat-title">Active</h3>
        <div class="Students-stat-value" id="activeStudents">0</div>
        <div class="Students-stat-percentage">96%</div>
      </div>
    </div>

    <div class="Students-stat-card">
      <div class="Students-stat-icon">
        <i class='bx bx-user-x'></i>
      </div>
      <div class="Students-stat-content">
        <h3 class="Students-stat-title">Inactive</h3>
        <div class="Students-stat-value" id="inactiveStudents">0</div>
        <div class="Students-stat-percentage">4%</div>
      </div>
    </div>

    <div class="Students-stat-card">
      <div class="Students-stat-icon">
        <i class='bx bx-calendar'></i>
      </div>
      <div class="Students-stat-content">
        <h3 class="Students-stat-title">Graduating</h3>
        <div class="Students-stat-value" id="graduatingStudents">0</div>
        <div class="Students-stat-percentage">15%</div>
      </div>
    </div>
  </div>

  <!-- MAIN CONTENT CARD -->
  <div class="Students-content-card">
    <!-- Table Header -->
    <div class="Students-table-header">
      <div class="Students-header-left">
        <h2 class="Students-table-title">Student List</h2>
        <p class="Students-table-subtitle">All student records and their details</p>
      </div>

      <div class="Students-header-right">
        <div class="Students-search-box">
          <i class='bx bx-search'></i>
          <input type="text" id="searchStudent" placeholder="Search students...">
        </div>

        <div class="Students-filter-group">
          <select id="StudentsFilterSelect" class="Students-filter-select">
            <option value="all">All Students</option>
            <option value="active">Active Only</option>
            <option value="inactive">Inactive</option>
            <option value="graduating">Graduating</option>
            <option value="archived">Archived</option>
          </select>

          <button class="Students-filter-btn" title="More filters">
            <i class='bx bx-filter-alt'></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Students Table -->
    <div id="StudentsPrintArea" class="Students-table-container">
      <table class="Students-table">
        <thead>
          <tr>
            <th class="Students-sortable" data-sort="id">
              <div class="Students-table-header-content">
                <span>ID</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Image</th>
            <th class="Students-sortable" data-sort="studentId">
              <div class="Students-table-header-content">
                <span>Student ID</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th class="Students-sortable" data-sort="name">
              <div class="Students-table-header-content">
                <span>Name</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th class="Students-sortable" data-sort="department">
              <div class="Students-table-header-content">
                <span>Department</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th class="Students-sortable" data-sort="section">
              <div class="Students-table-header-content">
                <span>Section</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th class="Students-sortable" data-sort="yearlevel">
              <div class="Students-table-header-content">
                <span>Year Level</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Contact No</th>
            <th class="Students-sortable" data-sort="status">
              <div class="Students-table-header-content">
                <span>Status</span>
                <i class='bx bx-sort'></i>
              </div>
            </th>
            <th>Actions</th>
          </tr>
        </thead>

        <tbody id="StudentsTableBody">
          <!-- JS will populate rows from database -->
        </tbody>
      </table>
    </div>

    <!-- Table Footer -->
    <div class="Students-table-footer">
      <div class="Students-footer-info">
        Showing <span id="showingStudentsCount">4</span> of <span id="totalStudentsCount">250</span> students
      </div>
      <div class="Students-pagination">
        <button class="Students-pagination-btn" disabled>
          <i class='bx bx-chevron-left'></i>
        </button>
        <button class="Students-pagination-btn active">1</button>
        <button class="Students-pagination-btn">2</button>
        <button class="Students-pagination-btn">3</button>
        <button class="Students-pagination-btn">4</button>
        <button class="Students-pagination-btn">5</button>
        <button class="Students-pagination-btn">
          <i class='bx bx-chevron-right'></i>
        </button>
      </div>
    </div>
  </div>

  <!-- MODAL -->
  <div id="StudentsModal" class="Students-modal">
    <div class="Students-modal-overlay" id="StudentsModalOverlay"></div>
    <div class="Students-modal-container">
      <div class="Students-modal-header">
        <h2 id="StudentsModalTitle">
          <i class='bx bxs-group'></i>
          <span>Add New Student</span>
        </h2>
        <button class="Students-close-btn" id="closeStudentsModal">
          <i class='bx bx-x'></i>
        </button>
      </div>

      <form id="StudentsForm">
        <div class="Students-form-row">
          <div class="Students-form-group">
            <label for="studentId">Student ID</label>
            <input type="text" id="studentId" name="studentId" required placeholder="e.g., 2023-001">
          </div>
          
          <div class="Students-form-group">
            <label for="studentStatus">Status</label>
            <select id="studentStatus" name="studentStatus" required>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="graduating">Graduating</option>
            </select>
          </div>
        </div>

        <div class="Students-form-group">
          <label for="studentImage">Student Photo</label>
          <div class="Students-image-upload">
            <div class="Students-image-preview" id="imagePreview">
              <div class="Students-preview-placeholder">
                <i class='bx bx-user'></i>
                <span>Upload photo</span>
              </div>
              <img class="Students-preview-img" style="display:none" alt="Preview">
            </div>
            <input type="file" id="studentImage" name="studentImage" accept="image/*" class="Students-file-input">
            <button type="button" class="Students-upload-btn" id="uploadImageBtn">
              <i class='bx bx-upload'></i> Choose Photo
            </button>
          </div>
        </div>

        <div class="Students-form-row">
          <div class="Students-form-group">
            <label for="firstName">First Name</label>
            <input type="text" id="firstName" name="firstName" required placeholder="e.g., John">
          </div>
          
          <div class="Students-form-group">
            <label for="lastName">Last Name</label>
            <input type="text" id="lastName" name="lastName" required placeholder="e.g., Doe">
          </div>
        </div>

        <div class="Students-form-group">
          <label for="middleName">Middle Name (Optional)</label>
          <input type="text" id="middleName" name="middleName" placeholder="e.g., Michael">
        </div>

        <div class="Students-form-row">
          <div class="Students-form-group">
            <label for="studentEmail">Email Address</label>
            <input type="email" id="studentEmail" name="studentEmail" required placeholder="student@example.com">
          </div>
          
          <div class="Students-form-group">
            <label for="studentContact">Contact Number</label>
            <input type="tel" id="studentContact" name="studentContact" required placeholder="+63 912 345 6789">
          </div>
        </div>

        <div class="Students-form-row">
          <div class="Students-form-group">
            <label for="studentDept">Department</label>
            <select id="studentDept" name="studentDept" required>
              <option value="">Select Department</option>
              <!-- Options loaded from database via JavaScript -->
            </select>
          </div>
          
          <div class="Students-form-group">
            <label for="studentSection">Section</label>
            <select id="studentSection" name="studentSection" required>
              <option value="">Select Section</option>
              <!-- Options loaded from database based on selected department -->
            </select>
          </div>
        </div>

        <div class="Students-form-row">
          <div class="Students-form-group">
            <label for="studentYearlevel">Year Level</label>
            <select id="studentYearlevel" name="studentYearlevel" required>
              <option value="">Select Year Level</option>
              <option value="1st Year">1st Year</option>
              <option value="2nd Year">2nd Year</option>
              <option value="3rd Year">3rd Year</option>
              <option value="4th Year">4th Year</option>
              <option value="5th Year">5th Year</option>
            </select>
          </div>
        </div>

        <div class="Students-form-group">
          <label for="studentAddress">Address</label>
          <textarea id="studentAddress" name="studentAddress" rows="2" placeholder="Complete address..."></textarea>
        </div>

        <div class="Students-form-actions">
          <button type="button" class="Students-btn-outline" id="cancelStudentsModal">Cancel</button>
          <button type="submit" class="Students-btn-primary">Save Student</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Empty State -->
  <div class="Students-empty-state" id="StudentsEmptyState" style="display: none;">
    <div class="Students-empty-icon">
      <i class='bx bx-user'></i>
    </div>
    <h3>No Students Found</h3>
    <p>Get started by adding your first student</p>
    <button class="Students-btn-primary" id="btnAddFirstStudent">
      <i class='bx bx-plus'></i> Add Student
    </button>
  </div>

  <!-- Export Modal -->
  <div id="ExportStudentsModal" class="Students-modal">
    <div class="Students-modal-overlay" id="ExportModalOverlay"></div>
    <div class="Students-modal-container" style="max-width: 400px;">
      <div class="Students-modal-header">
        <h2>
          <i class='bx bx-download'></i>
          <span>Export Students Data</span>
        </h2>
        <button class="Students-close-btn" id="closeExportModal">
          <i class='bx bx-x'></i>
        </button>
      </div>
      <div class="Students-modal-body" style="padding: 20px;">
        <p style="margin-bottom: 20px; color: #666;">Select your preferred format to download the student records.</p>
        <div class="export-options" style="display: flex; flex-direction: column; gap: 10px;">
          <button id="exportPDF" class="Students-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-pdf' style="color: #e74c3c; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as PDF</span>
          </button>
          <button id="exportExcel" class="Students-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-export' style="color: #27ae60; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as Excel (CSV)</span>
          </button>
          <button id="exportWord" class="Students-btn outline" style="justify-content: flex-start; width: 100%;">
            <i class='bx bxs-file-doc' style="color: #3498db; font-size: 24px;"></i>
            <span style="margin-left: 10px;">Export as Word (DOCX)</span>
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Student Profile Modal -->
  <div id="StudentProfileModal" class="Students-modal">
    <div class="Students-modal-overlay" id="ProfileModalOverlay"></div>
    <div class="Students-modal-container" style="max-width: 600px;">
      <div class="Students-modal-header">
        <h2>
          <i class='bx bx-user-circle'></i>
          <span>Student Profile</span>
        </h2>
        <button class="Students-close-btn" id="closeProfileModal">
          <i class='bx bx-x'></i>
        </button>
      </div>
      <div class="Students-modal-body">
        <div class="profile-details-wrapper" style="padding: 20px;">
          <div class="profile-header" style="display: flex; gap: 20px; align-items: center; margin-bottom: 25px; padding-bottom: 20px; border-bottom: 1px solid #eee;">
            <div class="profile-avatar-large">
              <img id="profileAvatar" src="" alt="Avatar" style="width: 100px; height: 100px; border-radius: 50%; object-fit: cover; border: 3px solid var(--gold);">
            </div>
            <div class="profile-main-info">
              <h3 id="profileFullName" style="font-size: 1.5rem; color: var(--dark); margin-bottom: 5px;"></h3>
              <p id="profileId" style="color: var(--gold); font-weight: 600; font-size: 1rem;"></p>
              <span id="profileStatusBadge" class="status-badge"></span>
            </div>
          </div>
          
          <div class="profile-info-grid" style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px;">
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Department</label>
              <p id="profileDept" style="font-weight: 500; color: var(--dark);"></p>
            </div>
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Section</label>
              <p id="profileSection" style="font-weight: 500; color: var(--dark);"></p>
            </div>
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Year Level</label>
              <p id="profileYear" style="font-weight: 500; color: var(--dark);"></p>
            </div>
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Email</label>
              <p id="profileEmail" style="font-weight: 500; color: var(--dark);"></p>
            </div>
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Contact</label>
              <p id="profileContact" style="font-weight: 500; color: var(--dark);"></p>
            </div>
            <div class="info-group">
              <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Enrollment Date</label>
              <p id="profileDate" style="font-weight: 500; color: var(--dark);"></p>
            </div>
          </div>
          
          <div class="info-group" style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #eee;">
            <label style="display: block; font-size: 0.8rem; color: #888; margin-bottom: 4px; text-transform: uppercase;">Address</label>
            <p id="profileAddress" style="font-weight: 500; color: var(--dark); line-height: 1.5;"></p>
          </div>
        </div>
      </div>
      <div class="Students-modal-footer" style="padding: 15px 20px; border-top: 1px solid #eee; display: flex; justify-content: flex-end;">
        <button type="button" class="Students-btn outline" id="closeProfileBtn">Close</button>
      </div>
    </div>
  </div>

  <!-- Modern Alert/Confirm Modal -->
  <div id="ModernAlertModal" class="Students-modal">
    <div class="Students-modal-overlay" id="ModernAlertOverlay"></div>
    <div class="Modern-modal-container">
      <div id="ModernAlertIcon" class="Modern-modal-icon warning">
        <i class='bx bx-help-circle'></i>
      </div>
      <h2 id="ModernAlertTitle" class="Modern-modal-title">Confirm Action</h2>
      <p id="ModernAlertMessage" class="Modern-modal-message">Are you sure you want to proceed?</p>
      <div id="ModernAlertStats" class="result-stats" style="display: none;">
        <div class="stat-item">
          <span class="stat-value" id="statNew">0</span>
          <span class="stat-label">New</span>
        </div>
        <div class="stat-item">
          <span class="stat-value" id="statUpdated">0</span>
          <span class="stat-label">Updated</span>
        </div>
        <div class="stat-item">
          <span class="stat-value" id="statSkipped">0</span>
          <span class="stat-label">Skipped</span>
        </div>
      </div>
      <div class="Modern-modal-actions" id="ModernAlertActions">
        <button id="ModernAlertCancel" class="Modern-modal-btn cancel">Cancel</button>
        <button id="ModernAlertConfirm" class="Modern-modal-btn confirm">Confirm</button>
      </div>
    </div>
  </div>

</main>

<!-- Load Libraries for Export -->
<script src="<?= View::asset('js/lib/jspdf.umd.min.js') ?>"></script>
<script src="<?= View::asset('js/lib/jspdf.plugin.autotable.min.js') ?>"></script>
<script src="<?= View::asset('js/lib/docx.js') ?>"></script>
<script src="<?= View::asset('js/lib/FileSaver.js') ?>"></script>

<!-- Load Student JavaScript -->
<script src="<?= View::asset('js/student.js') ?>?v=<?= time() ?>"></script>
<script>
    // Initialize the students module when DOM is ready
    document.addEventListener('DOMContentLoaded', function() {
        if (typeof initStudentsModule === 'function') {
            initStudentsModule();
        } else {
            console.error('initStudentsModule function not found');
        }
    });
</script>

</body>
</html>


