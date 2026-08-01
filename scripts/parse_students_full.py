
import sys
import pandas as pd
import json
import re
import os

# Default values
file_path = r'c:\wamp64\www\OSAS_WEB\app\assets\Students\LIST-OF-ENROLLED-FOR-2ND-SEM-2025-26.xlsx'
output_path = r'c:\wamp64\www\OSAS_WEB\scripts\students_data.json'

# Accept command line arguments for input and output paths
if len(sys.argv) > 1:
    file_path = sys.argv[1]
if len(sys.argv) > 2:
    output_path = sys.argv[2]

# Sheets that are NOT student enrollment lists — skip them
SKIP_SHEETS = {'WITHDRAW', 'OD', 'STOPPED', 'OFFICIALLY DROPPED', 'TRANSFEREE'}

DEPT_NAMES = {
    "BPA":    "Bachelor of Public Administration",
    "BSIS":   "Bachelor of Science in Information Systems",
    "WFT":    "Welding and Fabrication Technology",
    "CHS":    "Computer Hardware Servicing",
    "BTVTED": "Bachelor of Technical-Vocational Teacher Education",
    "BSBA":   "Bachelor of Science in Business Administration",
    "BSIT":   "Bachelor of Science in Information Technology",
    "BSCS":   "Bachelor of Science in Computer Science",
}

# CHS and WFT are sections under BTVTED, not standalone departments
SECTION_TO_DEPT = {
    "CHS": "BTVTED",
    "WFT": "BTVTED",
}

# Section codes that need a parent prefix to match the DB format
SECTION_CODE_PREFIX = {
    "CHS": "BTVTED-CHS",
    "WFT": "BTVTED-WFT",
}

def normalize_section_code(sheet_name):
    """BPA 1 → BPA1, BSIS 2 → BSIS2, CHS 1 → BTVTED-CHS1, WFT 1 → BTVTED-WFT1"""
    code = re.sub(r'\s+', '', sheet_name).upper()
    # Extract the letter prefix (strip trailing digits)
    prefix = re.sub(r'\d+$', '', code).strip()
    suffix = code[len(prefix):]  # the digit(s)
    if prefix in SECTION_CODE_PREFIX:
        return SECTION_CODE_PREFIX[prefix] + suffix
    return code

def extract_department_code(sheet_name):
    """BPA 1 → BPA, BSIS 2 → BSIS, CHS 1 → BTVTED, WFT 1 → BTVTED"""
    code = re.sub(r'\s+', '', sheet_name).upper()
    # Strip trailing digits
    dept = re.sub(r'\d+$', '', code).strip()
    # Remap section-level codes to their parent department
    return SECTION_TO_DEPT.get(dept, dept)

def normalize_sex(raw):
    """Ensure only M or F is stored (max 1 char)."""
    if not raw:
        return ''
    val = str(raw).strip().upper()
    if val in ('M', 'MALE'):
        return 'M'
    if val in ('F', 'FEMALE'):
        return 'F'
    # Take first char if it's M or F
    if val and val[0] in ('M', 'F'):
        return val[0]
    return ''

def normalize_student_id(raw):
    """Remove extra spaces inside the ID: '2026- 0895' → '2026-0895'"""
    return re.sub(r'\s+', '', str(raw).strip())

def parse_excel():
    try:
        xl = pd.ExcelFile(file_path)
    except Exception as e:
        print(f"Error opening Excel file: {e}")
        return None

    all_data = {
        "departments": {},
        "sections": [],
        "students": []
    }

    print(f"Found sheets: {xl.sheet_names}")

    for sheet_name in xl.sheet_names:
        # Skip non-enrollment sheets
        normalized_sheet = sheet_name.strip().upper()
        if any(skip in normalized_sheet for skip in SKIP_SHEETS):
            print(f"  Skipping sheet: {sheet_name}")
            continue

        print(f"Processing sheet: {sheet_name}")
        df = pd.read_excel(xl, sheet_name=sheet_name, header=None)

        dept_code   = extract_department_code(sheet_name)
        section_code = normalize_section_code(sheet_name)   # e.g. BPA1
        section_name = section_code  # fallback

        if not dept_code:
            print(f"  Could not determine department for sheet '{sheet_name}', skipping.")
            continue

        dept_name = DEPT_NAMES.get(dept_code, dept_code)

        if dept_code not in all_data["departments"]:
            all_data["departments"][dept_code] = {
                "code": dept_code,
                "name": dept_name
            }

        found_section_name = False
        sheet_students = []

        for index, row in df.iterrows():
            r = [str(x).strip() if pd.notna(x) else "" for x in row]

            # A student row has: col0=row-number, col2=student-ID (YYYY-NNNN pattern)
            # Be lenient: col2 may have spaces like "2026- 0895"
            col0_is_num = r[0].isdigit() if r[0] else False
            col2_raw    = r[2] if len(r) > 2 else ""
            col2_norm   = normalize_student_id(col2_raw)
            is_student  = col0_is_num and bool(re.match(r'^\d{4}-\d+$', col2_norm))

            if is_student:
                # Parse name: "LASTNAME, FIRSTNAME M."
                full_name = r[1]
                parts     = full_name.split(',', 1)
                last_name  = parts[0].strip().title()
                first_name = ""
                middle_name = ""

                if len(parts) > 1:
                    rest       = parts[1].strip()
                    name_parts = rest.split()
                    # Middle initial: last token is 1-2 chars ending with '.'
                    if (len(name_parts) > 1
                            and len(name_parts[-1]) <= 2
                            and name_parts[-1].endswith('.')):
                        middle_name = name_parts[-1].rstrip('.').upper()
                        first_name  = " ".join(name_parts[:-1]).title()
                    else:
                        first_name = rest.title()

                sex_raw = r[4] if len(r) > 4 else ""
                sex     = normalize_sex(sex_raw)

                student = {
                    "student_id":      col2_norm,
                    "last_name":       last_name,
                    "first_name":      first_name,
                    "middle_name":     middle_name,
                    "section_code":    section_code,
                    "department_code": dept_code,
                    "sex":             sex,
                    "contact_number":  "",
                    "email":           "",
                    "address":         ""
                }
                sheet_students.append(student)
                continue

            # Try to capture the section title (e.g. "BPA SECOND YEAR")
            if not found_section_name:
                candidate = r[1] if len(r) > 1 else ""
                if candidate and "YEAR" in candidate.upper() and "LIST" not in candidate.upper():
                    section_name     = candidate.strip()
                    found_section_name = True

        # Register section
        all_data["sections"].append({
            "code":            section_code,
            "name":            section_name,
            "department_code": dept_code
        })

        all_data["students"].extend(sheet_students)
        print(f"  Found {len(sheet_students)} students in {section_code}")

    return all_data


data = parse_excel()
if data:
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Successfully saved data to {output_path}")
    except Exception as e:
        print(f"Error saving output file: {e}")
        sys.exit(1)

    print(f"Total Departments: {len(data['departments'])}")
    print(f"Total Sections:    {len(data['sections'])}")
    print(f"Total Students:    {len(data['students'])}")
else:
    print("Failed to parse data.")
    sys.exit(1)
