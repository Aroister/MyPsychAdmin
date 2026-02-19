# ============================================================
# SHARED DATA STORE - Centralized data sharing across app
# ============================================================
"""
Singleton data store that allows all sections of the app to share
imported notes and extracted data. When data is uploaded in one
section (Notes, Forms, Reports), it becomes available everywhere.
"""

from __future__ import annotations
from typing import Dict, List, Any, Optional
from PySide6.QtCore import QObject, Signal


class SharedDataStore(QObject):
    """
    Centralized store for sharing imported data across all app sections.

    Emits signals when data changes so all connected components can update.
    """

    # Signals emitted when data changes
    notes_changed = Signal(list)           # Emitted when notes are updated
    patient_info_changed = Signal(dict)    # Emitted when patient demographics change
    extracted_data_changed = Signal(dict)  # Emitted when extracted category data changes
    report_sections_changed = Signal(dict, str)  # Emitted when report sections imported (sections, source_form)
    uploaded_documents_changed = Signal(list)  # Emitted when uploaded documents list changes

    _instance: Optional['SharedDataStore'] = None

    def __new__(cls):
        """Singleton pattern - only one instance exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        super().__init__()
        self._initialized = True

        # Core data storage
        self._notes: List[Dict] = []
        self._patient_info: Dict[str, Any] = {}
        self._extracted_data: Dict[str, Any] = {}
        self._report_sections: Dict[str, Any] = {}
        self._report_source: str = ""
        self._uploaded_documents: List[Dict] = []

        # Track source of last update for debugging
        self._last_update_source: str = ""

        print("[SharedDataStore] Initialized singleton instance")

    # --------------------------------------------------------
    # Notes Management
    # --------------------------------------------------------
    @property
    def notes(self) -> List[Dict]:
        """Get all imported notes."""
        return self._notes

    def set_notes(self, notes: List[Dict], source: str = "unknown"):
        """
        Set notes from any upload point in the app.

        Args:
            notes: List of note dictionaries
            source: Identifier for where the upload came from (e.g., "notes_panel", "asr_form")
        """
        if notes is None:
            notes = []

        # Only update if there's actual new data
        if len(notes) == 0 and len(self._notes) == 0:
            return

        old_count = len(self._notes)
        self._notes = list(notes)
        self._last_update_source = source

        print(f"[SharedDataStore] Notes updated from '{source}': {old_count} → {len(self._notes)} notes")

        # Emit signal to notify all listeners
        self.notes_changed.emit(self._notes)

    def add_notes(self, new_notes: List[Dict], source: str = "unknown"):
        """
        Add notes to existing collection (merge).

        Args:
            new_notes: New notes to add
            source: Identifier for upload source
        """
        if not new_notes:
            return

        # Simple merge - could add deduplication logic here
        self._notes.extend(new_notes)
        self._last_update_source = source

        print(f"[SharedDataStore] Added {len(new_notes)} notes from '{source}', total: {len(self._notes)}")
        self.notes_changed.emit(self._notes)

    def clear_notes(self):
        """Clear all notes."""
        self._notes = []
        self._last_update_source = "clear"
        print("[SharedDataStore] Notes cleared")
        self.notes_changed.emit(self._notes)

    def has_notes(self) -> bool:
        """Check if any notes are loaded."""
        return len(self._notes) > 0

    def set_notes_and_extract(self, notes: List[Dict], source: str = "import"):
        """
        Set notes and automatically extract patient demographics.

        This is the recommended method for importing notes as it ensures
        demographics are extracted immediately and available to all forms.

        Args:
            notes: List of note dictionaries
            source: Identifier for upload source
        """
        # First, set the notes
        self.set_notes(notes, source)

        # Then extract demographics
        if notes:
            try:
                from patient_demographics import extract_demographics
                demographics = extract_demographics(notes)
                # Only update fields that were actually extracted (not None)
                filtered_demographics = {k: v for k, v in demographics.items() if v is not None}
                if filtered_demographics:
                    self.set_patient_info(filtered_demographics, source=f"{source}_auto")
                    print(f"[SharedDataStore] Auto-extracted demographics: {list(filtered_demographics.keys())}")
            except ImportError as e:
                print(f"[SharedDataStore] Could not import patient_demographics: {e}")
            except Exception as e:
                print(f"[SharedDataStore] Error extracting demographics: {e}")

    # --------------------------------------------------------
    # Patient Information
    # --------------------------------------------------------
    @property
    def patient_info(self) -> Dict[str, Any]:
        """Get patient demographics."""
        return self._patient_info

    def set_patient_info(self, info: Dict[str, Any], source: str = "unknown"):
        """
        Set patient demographics.

        Expected keys: name, dob, nhs_number, gender, address, etc.
        """
        if info is None:
            info = {}

        self._patient_info = dict(info)
        print(f"[SharedDataStore] Patient info updated from '{source}': {list(info.keys())}")
        self.patient_info_changed.emit(self._patient_info)

    def update_patient_info(self, updates: Dict[str, Any], source: str = "unknown"):
        """Merge updates into existing patient info."""
        if not updates:
            return

        self._patient_info.update(updates)
        print(f"[SharedDataStore] Patient info merged from '{source}': {list(updates.keys())}")
        self.patient_info_changed.emit(self._patient_info)

    def get_patient_field(self, field: str, default: Any = None) -> Any:
        """Get a specific patient field."""
        return self._patient_info.get(field, default)

    @property
    def age(self) -> Optional[int]:
        """
        Computed age from DOB.

        Returns calculated age if DOB is available, otherwise returns
        any explicitly stored age value.
        """
        dob = self._patient_info.get('dob')
        if dob:
            try:
                from patient_demographics import calculate_age
                return calculate_age(dob)
            except ImportError:
                pass
        return self._patient_info.get('age')

    @property
    def gender_pronouns(self) -> Dict[str, str]:
        """
        Get pronoun set based on gender.

        Returns:
            Dictionary with keys: subject, object, possessive
            e.g., {'subject': 'he', 'object': 'him', 'possessive': 'his'}
        """
        try:
            from patient_demographics import get_pronouns
            return get_pronouns(self._patient_info.get('gender'))
        except ImportError:
            g = (self._patient_info.get('gender') or '').lower()
            if g in ('male', 'm'):
                return {'subject': 'he', 'object': 'him', 'possessive': 'his'}
            elif g in ('female', 'f'):
                return {'subject': 'she', 'object': 'her', 'possessive': 'her'}
            return {'subject': 'they', 'object': 'them', 'possessive': 'their'}

    @property
    def gender_descriptor(self) -> str:
        """
        Get gender descriptor word.

        Returns: 'man', 'woman', or 'person'
        """
        try:
            from patient_demographics import get_gender_descriptor
            return get_gender_descriptor(self._patient_info.get('gender'))
        except ImportError:
            g = (self._patient_info.get('gender') or '').lower()
            if g in ('male', 'm'):
                return 'man'
            elif g in ('female', 'f'):
                return 'woman'
            return 'person'

    # --------------------------------------------------------
    # Extracted Data by Category
    # --------------------------------------------------------
    @property
    def extracted_data(self) -> Dict[str, Any]:
        """Get all extracted category data."""
        return self._extracted_data

    def set_extracted_data(self, data: Dict[str, Any], source: str = "unknown"):
        """
        Set extracted data by category.

        Expected structure:
        {
            "presenting_complaint": [...],
            "history_presenting_complaint": [...],
            "past_psychiatric": [...],
            "background_history": [...],
            "social_history": [...],
            "forensic_history": [...],
            "drugs_alcohol": [...],
            "physical_health": [...],
            "mental_state": [...],
            "risk_assessment": [...],
            ...
        }
        """
        if data is None:
            data = {}

        self._extracted_data = dict(data)
        print(f"[SharedDataStore] Extracted data updated from '{source}': {list(data.keys())}")
        self.extracted_data_changed.emit(self._extracted_data)

    def update_extracted_category(self, category: str, data: Any, source: str = "unknown"):
        """Update a specific category of extracted data."""
        self._extracted_data[category] = data
        print(f"[SharedDataStore] Category '{category}' updated from '{source}'")
        self.extracted_data_changed.emit(self._extracted_data)

    def get_extracted_category(self, category: str, default: Any = None) -> Any:
        """Get data for a specific category."""
        return self._extracted_data.get(category, default)

    # --------------------------------------------------------
    # Report Sections (Cross-talk between forms)
    # --------------------------------------------------------
    @property
    def report_sections(self) -> Dict[str, Any]:
        """Get all imported report sections."""
        return self._report_sections

    def set_report_sections(self, sections: Dict[str, Any], source_form: str = "unknown"):
        """
        Set report sections from any tribunal form.
        This enables cross-talk between psychiatric and nursing forms.

        Args:
            sections: Dictionary of section_key -> content
            source_form: Identifier for which form imported ("tribunal", "nursing_tribunal")
        """
        if not sections:
            return

        self._report_sections = dict(sections)
        self._report_source = source_form
        self._last_update_source = f"report_sections:{source_form}"

        print(f"[SharedDataStore] Report sections updated from '{source_form}': {len(sections)} sections")
        print(f"  Keys: {list(sections.keys())}")

        # Emit signal so other forms can update
        self.report_sections_changed.emit(self._report_sections, source_form)

    def get_report_section(self, key: str, default: Any = None) -> Any:
        """Get a specific report section by key."""
        return self._report_sections.get(key, default)

    def get_report_source(self) -> str:
        """Get the source form that last imported sections."""
        return self._report_source

    # --------------------------------------------------------
    # Uploaded Documents Tracking
    # --------------------------------------------------------
    def add_uploaded_document(self, path: str):
        """Register a file that was uploaded via the notes panel or toolbar."""
        import os
        from datetime import datetime
        filename = os.path.basename(path)
        # Avoid duplicates by path
        if any(d["path"] == path for d in self._uploaded_documents):
            print(f"[SharedDataStore] Document already registered: {filename}")
            return
        entry = {"path": path, "filename": filename, "uploaded_at": datetime.now().isoformat()}
        self._uploaded_documents.append(entry)
        print(f"[SharedDataStore] Uploaded document registered: {filename}")
        self.uploaded_documents_changed.emit(self._uploaded_documents)

    def get_uploaded_documents(self) -> List[Dict]:
        """Return list of uploaded document dicts."""
        return self._uploaded_documents

    def clear_uploaded_documents(self):
        """Clear all uploaded documents."""
        self._uploaded_documents = []
        print("[SharedDataStore] Uploaded documents cleared")
        self.uploaded_documents_changed.emit(self._uploaded_documents)

    # --------------------------------------------------------
    # Utility Methods
    # --------------------------------------------------------
    def clear_all(self):
        """Clear all stored data."""
        self._notes = []
        self._patient_info = {}
        self._extracted_data = {}
        self._report_sections = {}
        self._report_source = ""
        self._uploaded_documents = []
        self._last_update_source = "clear_all"

        print("[SharedDataStore] All data cleared")

        self.notes_changed.emit(self._notes)
        self.patient_info_changed.emit(self._patient_info)
        self.extracted_data_changed.emit(self._extracted_data)
        self.report_sections_changed.emit(self._report_sections, "")
        self.uploaded_documents_changed.emit(self._uploaded_documents)

    def get_summary(self) -> Dict[str, Any]:
        """Get a summary of stored data for debugging."""
        return {
            "notes_count": len(self._notes),
            "patient_info_fields": list(self._patient_info.keys()),
            "extracted_categories": list(self._extracted_data.keys()),
            "last_update_source": self._last_update_source,
        }

    def __repr__(self) -> str:
        return (f"SharedDataStore(notes={len(self._notes)}, "
                f"patient_fields={len(self._patient_info)}, "
                f"categories={len(self._extracted_data)})")


# Convenience function to get the singleton instance
def get_shared_store() -> SharedDataStore:
    """Get the singleton SharedDataStore instance."""
    return SharedDataStore()
