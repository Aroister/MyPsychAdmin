# ================================================
# FLET PROOF OF CONCEPT - MyPsychAdmin Mobile
# ================================================
# This demonstrates how the MyDetailsPanel would
# look as a Flet mobile app (Android/iOS)
# ================================================

import flet as ft

def main(page: ft.Page):
    # ==============================
    # PAGE CONFIGURATION
    # ==============================
    page.title = "MyPsychAdmin"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.padding = 0

    # Mobile-friendly settings
    page.window.width = 400
    page.window.height = 800

    # ==============================
    # FORM FIELD REFERENCES
    # ==============================
    inputs = {}

    # Status message for save confirmation
    status_text = ft.Text(
        "",
        color=ft.Colors.GREEN_700,
        size=14,
        text_align=ft.TextAlign.CENTER
    )

    # ==============================
    # EVENT HANDLERS
    # ==============================
    def save_details(e):
        # In real app, this would save to SQLite/SQLCipher
        values = {key: field.value for key, field in inputs.items()}
        print("Saving details:", values)

        status_text.value = "Details saved successfully!"
        page.update()

        # Clear message after 2 seconds
        import time
        page.run_task(clear_status)

    async def clear_status():
        import asyncio
        await asyncio.sleep(2)
        status_text.value = ""
        page.update()

    def pick_signature(e):
        # File picker for signature image
        status_text.value = "Signature picker would open here"
        page.update()

    # ==============================
    # BUILD FORM FIELDS
    # ==============================
    fields = [
        ("Full Name", "full_name"),
        ("Role Title", "role_title"),
        ("Discipline", "discipline"),
        ("Registration Body", "registration_body"),
        ("Registration Number", "registration_number"),
        ("Phone", "phone"),
        ("Email", "email"),
        ("Team/Service", "team_service"),
        ("Hospital/Organisation", "hospital_org"),
        ("Ward/Department", "ward_department"),
        ("Signature Block", "signature_block"),
    ]

    form_controls = []

    for label_text, key in fields:
        text_field = ft.TextField(
            label=label_text,
            border_radius=8,
            filled=True,
            bgcolor=ft.Colors.WHITE,
        )
        inputs[key] = text_field
        form_controls.append(text_field)

    # ==============================
    # SIGNATURE SECTION
    # ==============================
    signature_section = ft.Container(
        content=ft.Column([
            ft.Text("Signature Image (optional)", weight=ft.FontWeight.BOLD),
            ft.Container(
                content=ft.Icon(ft.Icons.DRAW, size=48, color=ft.Colors.GREY_400),
                width=240,
                height=120,
                bgcolor=ft.Colors.WHITE,
                border=ft.border.all(1, ft.Colors.GREY_400),
                border_radius=8,
                alignment=ft.alignment.center,
            ),
            ft.ElevatedButton(
                "Load Signature Image",
                icon=ft.Icons.UPLOAD_FILE,
                on_click=pick_signature,
            ),
        ]),
        padding=ft.padding.only(top=10, bottom=10),
    )

    # ==============================
    # SAVE BUTTON
    # ==============================
    save_button = ft.ElevatedButton(
        "Save Details",
        icon=ft.Icons.SAVE,
        bgcolor=ft.Colors.BLUE_600,
        color=ft.Colors.WHITE,
        width=float("inf"),
        height=50,
        on_click=save_details,
    )

    # ==============================
    # MAIN LAYOUT
    # ==============================
    content = ft.Column(
        controls=[
            # Header
            ft.Container(
                content=ft.Text(
                    "My Details",
                    size=28,
                    weight=ft.FontWeight.BOLD,
                    color=ft.Colors.WHITE,
                ),
                bgcolor=ft.Colors.BLUE_700,
                padding=20,
                width=float("inf"),
            ),
            # Scrollable form
            ft.Container(
                content=ft.Column(
                    controls=form_controls + [
                        signature_section,
                        status_text,
                        save_button,
                    ],
                    spacing=12,
                    scroll=ft.ScrollMode.AUTO,
                ),
                padding=20,
                expand=True,
            ),
        ],
        spacing=0,
        expand=True,
    )

    page.add(content)


# ==============================
# BOTTOM NAVIGATION (MOBILE PATTERN)
# ==============================
def main_with_nav(page: ft.Page):
    """Extended version with bottom navigation - common mobile pattern"""

    page.title = "MyPsychAdmin"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.padding = 0
    page.window.width = 400
    page.window.height = 800

    # Track current view
    current_view = {"index": 0}

    # ==============================
    # FORM FIELDS (My Details)
    # ==============================
    inputs = {}
    status_text = ft.Text("", color=ft.Colors.GREEN_700, size=14)

    def save_details(e):
        status_text.value = "Details saved!"
        page.update()

    fields = [
        ("Full Name", "full_name"),
        ("Role Title", "role_title"),
        ("Discipline", "discipline"),
        ("Registration Body", "registration_body"),
        ("Registration Number", "registration_number"),
        ("Phone", "phone"),
        ("Email", "email"),
        ("Team/Service", "team_service"),
        ("Hospital/Organisation", "hospital_org"),
    ]

    form_controls = []
    for label_text, key in fields:
        tf = ft.TextField(label=label_text, border_radius=8, filled=True, bgcolor=ft.Colors.WHITE)
        inputs[key] = tf
        form_controls.append(tf)

    # ==============================
    # VIEW: MY DETAILS
    # ==============================
    my_details_view = ft.Container(
        content=ft.Column(
            controls=[
                ft.Container(
                    content=ft.Text("My Details", size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    bgcolor=ft.Colors.BLUE_700,
                    padding=20,
                    width=float("inf"),
                ),
                ft.Container(
                    content=ft.Column(
                        controls=form_controls + [
                            status_text,
                            ft.ElevatedButton(
                                "Save Details",
                                icon=ft.Icons.SAVE,
                                bgcolor=ft.Colors.BLUE_600,
                                color=ft.Colors.WHITE,
                                width=float("inf"),
                                height=50,
                                on_click=save_details,
                            ),
                        ],
                        spacing=12,
                        scroll=ft.ScrollMode.AUTO,
                    ),
                    padding=20,
                    expand=True,
                ),
            ],
            spacing=0,
            expand=True,
        ),
        expand=True,
    )

    # ==============================
    # VIEW: PATIENTS (Placeholder)
    # ==============================
    patients_view = ft.Container(
        content=ft.Column(
            controls=[
                ft.Container(
                    content=ft.Text("Patients", size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    bgcolor=ft.Colors.BLUE_700,
                    padding=20,
                    width=float("inf"),
                ),
                ft.Container(
                    content=ft.Column([
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.PERSON),
                            title=ft.Text("John Smith"),
                            subtitle=ft.Text("DOB: 15/03/1985"),
                            on_click=lambda e: print("Patient clicked"),
                        ),
                        ft.Divider(),
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.PERSON),
                            title=ft.Text("Jane Doe"),
                            subtitle=ft.Text("DOB: 22/08/1990"),
                        ),
                        ft.Divider(),
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.PERSON),
                            title=ft.Text("Robert Johnson"),
                            subtitle=ft.Text("DOB: 10/12/1978"),
                        ),
                    ], scroll=ft.ScrollMode.AUTO),
                    padding=10,
                    expand=True,
                ),
            ],
            spacing=0,
            expand=True,
        ),
        expand=True,
        visible=False,
    )

    # ==============================
    # VIEW: FORMS (Placeholder)
    # ==============================
    forms_view = ft.Container(
        content=ft.Column(
            controls=[
                ft.Container(
                    content=ft.Text("Forms", size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    bgcolor=ft.Colors.BLUE_700,
                    padding=20,
                    width=float("inf"),
                ),
                ft.Container(
                    content=ft.Column([
                        ft.Card(
                            content=ft.Container(
                                content=ft.ListTile(
                                    leading=ft.Icon(ft.Icons.DESCRIPTION),
                                    title=ft.Text("H1 Form"),
                                    subtitle=ft.Text("Application for admission"),
                                ),
                                padding=10,
                            ),
                        ),
                        ft.Card(
                            content=ft.Container(
                                content=ft.ListTile(
                                    leading=ft.Icon(ft.Icons.DESCRIPTION),
                                    title=ft.Text("H5 Form"),
                                    subtitle=ft.Text("Medical recommendation"),
                                ),
                                padding=10,
                            ),
                        ),
                        ft.Card(
                            content=ft.Container(
                                content=ft.ListTile(
                                    leading=ft.Icon(ft.Icons.DESCRIPTION),
                                    title=ft.Text("CTO1 Form"),
                                    subtitle=ft.Text("Community treatment order"),
                                ),
                                padding=10,
                            ),
                        ),
                    ], scroll=ft.ScrollMode.AUTO),
                    padding=10,
                    expand=True,
                ),
            ],
            spacing=0,
            expand=True,
        ),
        expand=True,
        visible=False,
    )

    # ==============================
    # NAVIGATION HANDLER
    # ==============================
    views = [my_details_view, patients_view, forms_view]

    def on_nav_change(e):
        idx = e.control.selected_index
        for i, view in enumerate(views):
            view.visible = (i == idx)
        page.update()

    # ==============================
    # BOTTOM NAVIGATION BAR
    # ==============================
    nav_bar = ft.NavigationBar(
        destinations=[
            ft.NavigationBarDestination(icon=ft.Icons.PERSON, label="My Details"),
            ft.NavigationBarDestination(icon=ft.Icons.PEOPLE, label="Patients"),
            ft.NavigationBarDestination(icon=ft.Icons.DESCRIPTION, label="Forms"),
        ],
        on_change=on_nav_change,
    )

    # ==============================
    # PAGE LAYOUT
    # ==============================
    page.add(
        ft.Column(
            controls=[
                ft.Stack(
                    controls=views,
                    expand=True,
                ),
                nav_bar,
            ],
            spacing=0,
            expand=True,
        )
    )


if __name__ == "__main__":
    # Run the simple version:
    # ft.app(target=main)

    # Run the version with bottom navigation:
    ft.app(target=main_with_nav)
