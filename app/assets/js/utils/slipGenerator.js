/**
 * OSAS Violation Slip Generator (PDF)
 * Uses jsPDF and AutoTable to generate a professional entrance slip.
 * Violation types and table rows are fully dynamic from DB.
 */

async function generateViolationSlipPDF(violationId) {
    console.log('📄 Generating Violation Slip PDF for ID:', violationId);

    if (typeof showLoadingOverlay === 'function') showLoadingOverlay('Preparing Entrance Slip...');

    try {
        // 1. Fetch Violation Data from API
        const response = await fetch(`${API_BASE}violations.php?action=get_slip_data&violation_id=${violationId}`);
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'Failed to fetch violation data');
        }

        const result = await response.json();
        const { violation, monthlyViolations, violationTypes, violationLevels, adminName } = result.data;

        // violationTypes: ordered array of type names from DB
        // violationLevels: ordered union of all level names from DB
        // monthlyViolations: { "TypeName": [...violations] }
        const typeNames = Array.isArray(violationTypes) && violationTypes.length > 0
            ? violationTypes
            : Object.keys(monthlyViolations);

        // Use DB-provided levels as column headers; fallback to collecting from data
        let allLevelNames = Array.isArray(violationLevels) && violationLevels.length > 0
            ? violationLevels
            : [];

        if (!window.jspdf) {
            throw new Error('PDF library (jsPDF) not loaded. Please refresh the page.');
        }

        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('p', 'mm', 'a4');
        const now = new Date();

        // Helper: load image
        const loadImage = (url) => new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = 'Anonymous';
            img.onload = () => resolve(img);
            img.onerror = (e) => reject(e);
            img.src = url;
        });

        // --- Header ---
        const headerPath = `${API_BASE.replace('api/', '')}app/assets/headers/header.png`;
        try {
            const headerImg = await loadImage(headerPath);
            doc.addImage(headerImg, 'PNG', 35, 10, 140, 25);
        } catch (e) {
            console.warn('Could not load header image, using text fallback');
            doc.setFontSize(16);
            doc.setTextColor(44, 62, 80);
            doc.text("E-OSAS SYSTEM", 105, 15, { align: 'center' });
            doc.setFontSize(10);
            doc.text("Office of Student Affairs and Services", 105, 22, { align: 'center' });
        }

        doc.setFontSize(14);
        doc.setFont("helvetica", "bold");
        doc.setTextColor(0, 0, 0);
        doc.text("ENTRANCE SLIP", 105, 45, { align: 'center' });

        // --- Student Info ---
        doc.setFontSize(10);
        doc.setFont("helvetica", "normal");

        const startY = 55;
        const leftColX = 20;
        const rightColX = 110;
        const lineSpacing = 7;

        const drawField = (label, value, x, y, width) => {
            doc.setFont("helvetica", "bold");
            doc.text(label + ":", x, y);
            doc.setFont("helvetica", "normal");
            doc.text(String(value || 'N/A'), x + 35, y);
            doc.setDrawColor(200);
            doc.line(x + 35, y + 1, x + width, y + 1);
        };

        const courseYear = `${violation.section || 'N/A'} - ${violation.studentYearlevel || 'N/A'}`;

        drawField("Name", violation.studentName, leftColX, startY, 190);
        drawField("ID Number", violation.studentId, leftColX, startY + lineSpacing, 100);
        drawField("Course & Year", courseYear, rightColX, startY + lineSpacing, 190);

        // --- Violation Type Checkboxes (dynamic) ---
        const currentTypeName = (violation.violationTypeLabel || '').trim();
        const currentLevelName = (violation.violationLevelLabel || '').trim();

        const drawCheckbox = (label, isChecked, x, y) => {
            doc.setDrawColor(0);
            doc.rect(x, y - 3, 4, 4);
            if (isChecked) {
                doc.setFont("zapfdingbats");
                doc.text("4", x + 0.5, y - 0.2);
                doc.setFont("helvetica", "normal");
            }
            doc.text(label, x + 6, y);
        };

        let checkY = startY + lineSpacing * 3;

        // Violation Type row
        doc.setFont("helvetica", "bold");
        doc.text("Violation Type:", leftColX, checkY);
        doc.setFont("helvetica", "normal");

        // Distribute type checkboxes across the line (max ~3 per row, wrap if more)
        const typeBoxStartX = leftColX + 35;
        const typeBoxSpacing = 55; // mm between each checkbox
        const maxPerRow = Math.floor((190 - 35) / typeBoxSpacing) || 3;

        typeNames.forEach((typeName, idx) => {
            const row = Math.floor(idx / maxPerRow);
            const col = idx % maxPerRow;
            const bx = typeBoxStartX + col * typeBoxSpacing;
            const by = checkY + row * lineSpacing;
            const isChecked = typeName.trim().toLowerCase() === currentTypeName.toLowerCase();
            drawCheckbox(typeName, isChecked, bx, by);
        });

        const typeRows = Math.ceil(typeNames.length / maxPerRow);
        checkY += typeRows * lineSpacing;

        // Offense Level row — use DB-provided levels; fallback to collecting from monthly data
        if (allLevelNames.length === 0) {
            typeNames.forEach(typeName => {
                const vList = monthlyViolations[typeName] || [];
                vList.forEach(v => {
                    const lvl = (v.violationLevelLabel || '').trim();
                    if (lvl && !allLevelNames.includes(lvl)) allLevelNames.push(lvl);
                });
            });
            // Always include the current violation's level
            if (currentLevelName && !allLevelNames.includes(currentLevelName)) {
                allLevelNames.unshift(currentLevelName);
            }
        }
        // Final fallback
        if (allLevelNames.length === 0) allLevelNames = ['1st Offense', '2nd Offense', '3rd Offense'];

        doc.setFont("helvetica", "bold");
        doc.text("Offense Level:", leftColX, checkY);
        doc.setFont("helvetica", "normal");

        allLevelNames.forEach((lvlName, idx) => {
            const row = Math.floor(idx / maxPerRow);
            const col = idx % maxPerRow;
            const bx = typeBoxStartX + col * typeBoxSpacing;
            const by = checkY + row * lineSpacing;
            const isChecked = lvlName.toLowerCase() === currentLevelName.toLowerCase();
            drawCheckbox(lvlName, isChecked, bx, by);
        });

        const levelRows = Math.ceil(allLevelNames.length / maxPerRow);
        checkY += levelRows * lineSpacing;

        // --- Monthly History Table (columns = DB level names) ---
        let tableY = checkY + 8;
        doc.setFont("helvetica", "bold");
        doc.text("Monthly Violation Record:", leftColX, tableY);
        tableY += 5;

        // Header: Violation Type | [one column per level name]
        const tableColumn = ["Violation Type", ...allLevelNames];

        // Build rows: for each type, find which level column has a violation date
        const tableRows = typeNames.map(typeName => {
            const vList = monthlyViolations[typeName] || [];
            // Index violations by level name (first match per level)
            const levelToViolation = {};
            vList.forEach(v => {
                const lvl = (v.violationLevelLabel || '').trim();
                if (lvl && !levelToViolation[lvl]) levelToViolation[lvl] = v;
            });

            const dateCells = allLevelNames.map(levelName => {
                const v = levelToViolation[levelName]
                    || Object.entries(levelToViolation).find(([k]) => k.toLowerCase() === levelName.toLowerCase())?.[1];
                return v ? v.dateReported : '-';
            });

            return [typeName, ...dateCells];
        });

        const totalWidth = 170;
        const firstColWidth = 50;
        const dateCellWidth = allLevelNames.length > 0
            ? (totalWidth - firstColWidth) / allLevelNames.length
            : (totalWidth - firstColWidth) / 3;

        const columnStyles = { 0: { halign: 'left', cellWidth: firstColWidth } };
        for (let i = 1; i <= allLevelNames.length; i++) {
            columnStyles[i] = { halign: 'center', cellWidth: dateCellWidth };
        }

        doc.autoTable({
            head: [tableColumn],
            body: tableRows,
            startY: tableY,
            theme: 'grid',
            styles: { fontSize: 9, cellPadding: 3, halign: 'center' },
            headStyles: { fillColor: [240, 240, 240], textColor: [0, 0, 0], fontStyle: 'bold' },
            columnStyles: columnStyles,
            margin: { left: leftColX, right: 20 }
        });

        let finalY = doc.lastAutoTable.finalY + 20;

        // --- Signatures ---
        doc.setFont("helvetica", "bold");
        doc.setFontSize(10);
        doc.text("__________________________", leftColX + 10, finalY);
        doc.text("__________________________", rightColX + 10, finalY);

        doc.setFont("helvetica", "normal");
        doc.setFontSize(9);
        doc.text("Student Signature", leftColX + 22, finalY + 5);
        doc.text(adminName || "OSAS Administrator", rightColX + 22, finalY + 5);

        // --- Footer ---
        doc.setFontSize(8);
        doc.setTextColor(150);
        const footerText = `Generated on: ${now.toLocaleString()} | Violation ID: ${violation.id}`;
        doc.text(footerText, 105, 285, { align: 'center' });

        doc.save(`EntranceSlip_${violation.studentName.replace(/[^a-z0-9]/gi, '_')}.pdf`);
        if (typeof showNotification === 'function') showNotification('PDF generated successfully!', 'success');

    } catch (error) {
        console.error('❌ Error generating PDF:', error);
        if (typeof showNotification === 'function') showNotification('Failed to generate PDF: ' + error.message, 'error');
    } finally {
        if (typeof hideLoadingOverlay === 'function') hideLoadingOverlay();
    }
}
