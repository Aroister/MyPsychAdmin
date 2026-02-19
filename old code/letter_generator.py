# ================================================================
#  LETTER GENERATOR — Extractor → Template → Polished Text
#  Module 7/10 for MyPsy Dynamic Letter Writer
# ================================================================
from __future__ import annotations
from typing import Dict, Any

from datetime import datetime

# Templates (Module 5)
from letter_templates import (
    PRESENTING_COMPLAINT_TEMPLATE,
    HPC_TEMPLATE,
    MSE_TEMPLATE,
    RISK_TEMPLATE,
    SOCIAL_HISTORY_TEMPLATE,
    FORENSIC_HISTORY_TEMPLATE,
    PHYSICAL_HEALTH_TEMPLATE,
    MEDICATION_TEMPLATE,
    DIAGNOSIS_TEMPLATE,
    PLAN_TEMPLATE,
    FULL_LETTER_TEMPLATE
)


# ================================================================
#  MAIN CLASS
# ================================================================
class LetterGenerator:

    def __init__(self, parent_window):
        """
        parent_window: the main MyPsy window, where extractors and data live.
        """
        self.win = parent_window

    # ------------------------------------------------------------
    # Helper to get patient name
    # ------------------------------------------------------------
    @property
    def patient_name(self) -> str:
        return getattr(self.win, "patient_name", "the patient")

    # ------------------------------------------------------------
    # Helper safe getter
    # ------------------------------------------------------------
    def _safe(self, obj, key, default=""):
        return obj.get(key, default) if obj else default

    # ============================================================
    #  PRESENTING COMPLAINT
    # ============================================================
    def generate_presenting_complaint(self) -> str:
        pc = self._safe(self.win.history_data, "presenting_complaint", "")
        primary = self._safe(self.win.history_data, "pc_primary", "")

        if not pc and not primary:
            return f"{self.patient_name} presents today for psychiatric review."

        return PRESENTING_COMPLAINT_TEMPLATE.format(
            patient_name=self.patient_name,
            chief_complaint=pc or "current mental health difficulties",
            primary_issues=primary or "ongoing symptoms and functional concerns"
        ).strip()

    # ============================================================
    #  HPC
    # ============================================================
    def generate_hpc(self) -> str:
        hd = self.win.history_data

        duration = hd.get("duration", "recent weeks")
        symptoms = hd.get("symptom_summary", "a range of psychological symptoms")
        course = hd.get("course", "fluctuations")
        key_details = hd.get("key_details", "relevant clinical features")
        context = hd.get("context", "psychosocial stressors")

        return HPC_TEMPLATE.format(
            patient_name=self.patient_name,
            duration=duration,
            symptoms=symptoms,
            course=course,
            key_details=key_details,
            context=context
        ).strip()

    # ============================================================
    #  MENTAL STATE EXAMINATION
    # ============================================================
    def generate_mse(self) -> str:
        mse = self._safe(self.win.history_data, "mse", {})

        return MSE_TEMPLATE.format(
            appearance=mse.get("appearance", "Appropriate and well-groomed."),
            speech=mse.get("speech", "Normal in rate, volume, and tone."),
            mood=mse.get("mood", "Reported as stable."),
            thought_form=mse.get("thought_form", "Organised and goal-directed."),
            thought_content=mse.get("thought_content", "No abnormalities detected."),
            perception=mse.get("perception", "No perceptual disturbances reported."),
            cognition=mse.get("cognition", "Grossly intact."),
            insight=mse.get("insight", "Reasonable understanding of current difficulties.")
        ).strip()

    # ============================================================
    #  RISK
    # ============================================================
    def generate_risk(self) -> str:
        r = self._safe(self.win.history_data, "risk", {})

        return RISK_TEMPLATE.format(
            risk_factors=r.get("risk_factors", "no acute concerns"),
            protective_factors=r.get("protective_factors", "supportive personal strengths"),
            risk_level=r.get("risk_level", "low to moderate")
        ).strip()

    # ============================================================
    #  SOCIAL HISTORY
    # ============================================================
    def generate_social(self) -> str:
        s = self._safe(self.win.history_data, "social", {})

        return SOCIAL_HISTORY_TEMPLATE.format(
            patient_name=self.patient_name,
            living_situation=s.get("living", "in their current accommodation"),
            family_context=s.get("family", "stable family relationships"),
            work_history=s.get("work", "recent work history"),
            social_factors=s.get("additional", "relevant social circumstances")
        ).strip()

    # ============================================================
    #  FORENSIC HISTORY
    # ============================================================
    def generate_forensic(self) -> str:
        f = self._safe(self.win.history_data, "forensic", {})

        return FORENSIC_HISTORY_TEMPLATE.format(
            forensic_summary=f.get("summary", "no recorded forensic concerns")
        ).strip()

    # ============================================================
    #  PHYSICAL HEALTH
    # ============================================================
    def generate_physical(self) -> str:
        p = self._safe(self.win.physical_data, "summary", "")
        investigations = self._safe(self.win.physical_data, "investigations", "no significant abnormalities identified")
        concerns = self._safe(self.win.physical_data, "concerns", "no acute physical health concerns")

        return PHYSICAL_HEALTH_TEMPLATE.format(
            physical_summary=p or "physical health is stable",
            investigations=investigations,
            physical_concerns=concerns
        ).strip()

    # ============================================================
    #  MEDICATION
    # ============================================================
    def generate_medication(self) -> str:
        m = self.win.medication_data

        current = m.get("current_list", "current regimen documented")
        changes = m.get("recent_changes", "no recent changes reported")
        adherence = m.get("adherence", "good adherence reported")

        return MEDICATION_TEMPLATE.format(
            current_medications=current,
            med_changes=changes,
            med_adherence=adherence
        ).strip()

    # ============================================================
    #  DIAGNOSIS
    # ============================================================
    def generate_diagnosis(self) -> str:
        d = self._safe(self.win.history_data, "diagnosis", "")

        if not d:
            return "A working diagnosis has not yet been formally established."

        differentials = self._safe(self.win.history_data, "differentials", "none specified")

        return DIAGNOSIS_TEMPLATE.format(
            diagnosis=d,
            differentials=differentials
        ).strip()

    # ============================================================
    #  PLAN
    # ============================================================
    def generate_plan(self) -> str:
        p = self._safe(self.win.history_data, "plan", {})

        return PLAN_TEMPLATE.format(
            plan_medication=p.get("medication", "continue current regimen"),
            plan_psychology=p.get("psychology", "consider engagement with psychological therapy"),
            plan_social=p.get("social", "ongoing social support"),
            plan_risk=p.get("risk", "review risk regularly"),
            plan_followup=p.get("followup", "follow-up in clinic")
        ).strip()

    # ============================================================
    #  FULL LETTER CONSTRUCTOR
    # ============================================================
    def generate_full_letter(self) -> str:
        """
        Builds a full structured letter, useful when inserting the entire letter at once.
        """

        return FULL_LETTER_TEMPLATE.format(
            presenting_complaint=self.generate_presenting_complaint(),
            hpc=self.generate_hpc(),
            mse=self.generate_mse(),
            diagnosis=self.generate_diagnosis(),
            risk=self.generate_risk(),
            medication=self.generate_medication(),
            social=self.generate_social(),
            forensic=self.generate_forensic(),
            physical=self.generate_physical(),
            plan=self.generate_plan()
        ).strip()
