<!-- Logout Confirmation Modal -->
<div id="LogoutModal" class="logout-modal-overlay">
    <div class="logout-modal-content">
        <div class="logout-modal-header">
            <div class="logout-icon-wrapper">
                <i class='bx bx-log-out-circle'></i>
            </div>
            <h2>Confirm Logout</h2>
        </div>
        <div class="logout-modal-body">
            <p>Are you sure you want to logout? Any unsaved changes will be lost.</p>
        </div>
        <div class="logout-modal-footer">
            <button class="logout-btn-cancel" id="cancelLogoutBtn">Cancel</button>
            <button class="logout-btn-confirm" id="confirmLogoutBtn">Logout</button>
        </div>
    </div>
</div>

<style>
.logout-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.4);
    backdrop-filter: blur(6px);
    display: none;
    justify-content: center;
    align-items: center;
    z-index: 10000;
    opacity: 0;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.logout-modal-overlay.show {
    display: flex;
    opacity: 1;
}

.logout-modal-content {
    background: #fff;
    width: 90%;
    max-width: 380px;
    padding: 32px;
    border-radius: 24px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
    transform: scale(0.9) translateY(20px);
    transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    text-align: center;
}

.logout-modal-overlay.show .logout-modal-content {
    transform: scale(1) translateY(0);
}

.logout-icon-wrapper {
    width: 72px;
    height: 72px;
    background: rgba(255, 215, 0, 0.12);
    color: #ffd700;
    font-size: 36px;
    border-radius: 50%;
    display: flex;
    justify-content: center;
    align-items: center;
    margin: 0 auto 24px;
    animation: pulseLogout 2s infinite;
}

@keyframes pulseLogout {
    0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(255, 215, 0, 0.4); }
    70% { transform: scale(1.05); box-shadow: 0 0 0 10px rgba(255, 215, 0, 0); }
    100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(255, 215, 0, 0); }
}

.logout-modal-header h2 {
    font-size: 22px;
    font-weight: 700;
    color: #1a1a1a;
    margin-bottom: 12px;
}

.logout-modal-body p {
    color: #666;
    font-size: 15px;
    line-height: 1.6;
    margin-bottom: 32px;
}

.logout-modal-footer {
    display: flex;
    gap: 12px;
    justify-content: center;
}

.logout-btn-cancel, .logout-btn-confirm {
    flex: 1;
    padding: 14px;
    border-radius: 14px;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.25s ease;
    border: none;
    outline: none;
}

.logout-btn-cancel {
    background: #f3f4f6;
    color: #4b5563;
}

.logout-btn-cancel:hover {
    background: #e5e7eb;
    color: #1f2937;
}

.logout-btn-confirm {
    background: #ffd700;
    color: #000;
    box-shadow: 0 4px 12px rgba(255, 215, 0, 0.2);
}

.logout-btn-confirm:hover {
    background: #ffcc00;
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(255, 215, 0, 0.3);
}

.logout-btn-confirm:active {
    transform: translateY(0);
}
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('LogoutModal');
    const cancelBtn = document.getElementById('cancelLogoutBtn');
    const confirmBtn = document.getElementById('confirmLogoutBtn');

    if (cancelBtn) {
        cancelBtn.onclick = closeLogoutModal;
    }

    if (confirmBtn) {
        confirmBtn.onclick = function() {
            console.log('🚪 Logout confirmed from modal');
            if (typeof window.executeLogout === 'function') {
                window.executeLogout();
            } else if (typeof executeLogout === 'function') {
                executeLogout();
            } else {
                // Final fallback - redirect to index (which will handle logout if not authenticated)
                window.location.href = '<?= View::url('index.php') ?>';
            }
        };
    }

    // Close on overlay click
    modal.onclick = function(e) {
        if (e.target === modal) closeLogoutModal();
    };
});

window.openLogoutModal = function(e) {
    console.log('🚪 Opening modern logout modal...');
    if (e) {
        if (typeof e.preventDefault === 'function') e.preventDefault();
        if (typeof e.stopPropagation === 'function') e.stopPropagation();
    }
    
    const modal = document.getElementById('LogoutModal');
    if (!modal) {
        console.error('❌ LogoutModal element not found');
        return;
    }
    
    modal.style.display = 'flex';
    // Small delay to trigger transition
    setTimeout(() => {
        modal.classList.add('show');
    }, 10);
    
    // Disable scrolling
    document.body.style.overflow = 'hidden';
}

window.closeLogoutModal = function() {
    const modal = document.getElementById('LogoutModal');
    if (!modal) return;
    
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
        // Enable scrolling
        document.body.style.overflow = '';
    }, 300);
}
</script>
