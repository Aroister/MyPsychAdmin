# ================================================================
#  PDF LOADER - Extract data from T131/T134 tribunal report PDFs
# ================================================================

import re
import xml.etree.ElementTree as ET
from pathlib import Path

try:
    import fitz  # PyMuPDF
    PYMUPDF_AVAILABLE = True
except ImportError:
    PYMUPDF_AVAILABLE = False


def extract_xfa_data(pdf_path: str) -> dict:
    """
    Extract XFA form data from a tribunal report PDF.

    Returns a dict with:
        - 'form_type': 'T131' or 'T134' or 'unknown'
        - 'fields': dict mapping field names to values
        - 'raw_xml': the raw XFA XML string
    """
    if not PYMUPDF_AVAILABLE:
        return {'error': 'PyMuPDF not installed. Run: pip install PyMuPDF'}

    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        return {'error': f'Could not open PDF: {e}'}

    # Search for XFA datasets in PDF streams
    xfa_xml = None
    candidates = []

    for xref in range(1, doc.xref_length()):
        try:
            stream = doc.xref_stream(xref)
            if stream:
                decoded = stream.decode('utf-8', errors='ignore')
                # Look for XFA data streams
                if '<xfa:data' in decoded or '<xfa:datasets' in decoded:
                    # Check if this has actual text content (not just structure)
                    has_content = False
                    # Look for filled field indicators
                    if '>Dr ' in decoded or '>Mr ' in decoded or '>Mrs ' in decoded:
                        has_content = True
                    elif re.search(r'>\d{4}-\d{2}-\d{2}<', decoded):  # Date fields
                        has_content = True
                    elif re.search(r'>[A-Z][a-z]+\s+[A-Z][a-z]+<', decoded):  # Names
                        has_content = True
                    elif len(decoded) > 5000:  # Large stream likely has content
                        has_content = True

                    if has_content:
                        candidates.append((xref, len(decoded), decoded))
        except:
            pass

    doc.close()

    # Pick the largest candidate (most likely has all the data)
    if candidates:
        candidates.sort(key=lambda x: x[1], reverse=True)
        xfa_xml = candidates[0][2]

    if not xfa_xml:
        return {'error': 'No XFA form data found in PDF. This may not be a filled tribunal report form.'}

    # Parse the XML
    try:
        root = ET.fromstring(xfa_xml)
    except ET.ParseError as e:
        return {'error': f'Could not parse XFA XML: {e}'}

    # Extract all fields
    fields = {}

    def extract_fields(element, path=""):
        tag = element.tag.split('}')[-1] if '}' in element.tag else element.tag
        current_path = f"{path}/{tag}" if path else tag

        if element.text and element.text.strip():
            text = element.text.strip()
            # Clean up XML entities
            text = text.replace('&#xD;', '\n').replace('&#x9;', '\t')
            text = text.replace('&#xA;', '\n')
            fields[tag] = text

        for child in element:
            extract_fields(child, current_path)

    extract_fields(root)

    # Detect form type from field names and content
    form_type = 'unknown'
    # T131 has Q1-Q23 fields
    if any(f.startswith('Q') and f[1:2].isdigit() for f in fields.keys()):
        form_type = 'T131'
    if 'T131' in xfa_xml or 'Responsible Clinician' in xfa_xml:
        form_type = 'T131'
    elif 'T134' in xfa_xml or 'Nursing Report' in xfa_xml:
        form_type = 'T134'

    return {
        'form_type': form_type,
        'fields': fields,
        'raw_xml': xfa_xml
    }


# T131 Field mappings to psychiatric tribunal sections
T131_MAPPINGS = {
    # Field name -> (section_key, section_number, section_title)
    'Q1_TextField2': ('patient_details', 1, 'Patient Details'),
    'Q1_DateTimeField': ('patient_dob', 1, 'Patient DOB'),
    'TextField9': ('author_name', 2, 'Author Name'),
    'TextField10': ('author_role', 2, 'Author Role'),
    'Q2_TextField': ('author', 2, 'Responsible Clinician'),
    'Q3_TextField': ('factors_hearing', 3, 'Factors affecting understanding'),
    'Q4_TextField': ('adjustments', 4, 'Adjustments for tribunal'),
    'Q5_TextField': ('forensic', 5, 'Index offence and forensic history'),
    'Q6_TextField': ('previous_mh_dates', 6, 'Previous mental health involvement'),
    'Q7_TextField': ('previous_admission_reasons', 7, 'Previous admission reasons'),
    'Q8_TextField': ('current_admission', 8, 'Current admission circumstances'),
    'Q9_TextField': ('diagnosis', 9, 'Mental disorder and diagnosis'),
    'Q10_Radiobuttons': ('learning_disability', 10, 'Learning disability'),
    'Q11_Radiobuttons': ('detention_required', 11, 'Detention required'),
    'Q12_TextField': ('treatment', 12, 'Medical treatment'),
    'Q13_TextField': ('strengths', 13, 'Strengths/positive factors'),
    'Q14_TextField': ('progress', 14, 'Progress, behaviour, capacity, insight'),
    'Q15_TextField': ('compliance', 15, 'Understanding/compliance with treatment'),
    'Q16_TextField': ('mca_dol', 16, 'MCA DoL consideration'),
    'Q17_TextField': ('risk_harm', 17, 'Incidents of harm'),
    'Q18_TextField': ('risk_property', 18, 'Incidents of property damage'),
    'Q19_Radiobuttons': ('s2_detention', 19, 'Section 2 detention'),
    'Q20_Radiobuttons': ('other_detention', 20, 'Other sections detention'),
    'Q21_TextField': ('discharge_risk', 21, 'Risk if discharged'),
    'Q22_TextField': ('community', 22, 'Community risk management'),
    'Q23_TextField': ('recommendations', 23, 'Recommendations to tribunal'),
    'DateTimeField2': ('signature_date', 24, 'Signature date'),
    'DateTimeField3': ('report_date', 1, 'Report date'),
}


# T134 Field mappings to nursing tribunal sections (to be completed)
T134_MAPPINGS = {
    # Will need to analyze a T134 PDF to complete these mappings
}


def map_fields_to_sections(extracted_data: dict, form_type: str = None) -> dict:
    """
    Map extracted PDF fields to tribunal report sections.

    Returns a dict mapping section_key -> content
    """
    if 'error' in extracted_data:
        return extracted_data

    fields = extracted_data.get('fields', {})
    detected_type = form_type or extracted_data.get('form_type', 'unknown')

    mappings = T131_MAPPINGS if detected_type == 'T131' else T134_MAPPINGS

    sections = {}

    for field_name, field_value in fields.items():
        if field_name in mappings:
            section_key, section_num, section_title = mappings[field_name]

            # If section already has content, append
            if section_key in sections:
                sections[section_key] += '\n\n' + field_value
            else:
                sections[section_key] = field_value

    return {
        'form_type': detected_type,
        'sections': sections,
        'unmapped_fields': {k: v for k, v in fields.items() if k not in mappings}
    }


def load_tribunal_pdf(pdf_path: str) -> dict:
    """
    Main entry point: Load a tribunal PDF and return mapped sections.

    Usage:
        result = load_tribunal_pdf('/path/to/report.pdf')
        if 'error' in result:
            print(f"Error: {result['error']}")
        else:
            for section_key, content in result['sections'].items():
                print(f"{section_key}: {content[:100]}...")
    """
    extracted = extract_xfa_data(pdf_path)
    if 'error' in extracted:
        return extracted

    return map_fields_to_sections(extracted)


# Radio button value mappings
RADIO_MAPPINGS = {
    '1': 'Yes',
    '2': 'No',
    '3': 'N/A',
}


def format_radio_value(value: str) -> str:
    """Convert radio button value to readable text."""
    return RADIO_MAPPINGS.get(value, value)


if __name__ == '__main__':
    # Test with sample PDF
    import sys
    if len(sys.argv) > 1:
        result = load_tribunal_pdf(sys.argv[1])
        if 'error' in result:
            print(f"Error: {result['error']}")
        else:
            print(f"Form type: {result['form_type']}")
            print(f"\nMapped sections ({len(result['sections'])}):")
            for key, value in result['sections'].items():
                print(f"\n[{key}]")
                print(value[:500] + '...' if len(value) > 500 else value)
