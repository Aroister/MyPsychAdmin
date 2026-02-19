# MyPsychAdmin iOS

Native SwiftUI iOS app for psychiatric documentation, ported from the PyQt desktop application.

## Requirements

- Xcode 15.0 or later
- iOS 17.0 or later
- macOS Sonoma (for development)

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "iOS" → "App"
4. Configure:
   - Product Name: `MyPsychAdmin`
   - Team: Your team
   - Organization Identifier: `com.yourcompany`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
5. Choose location: Save in the `MyPsychAdminIOS` folder (replace the generated files)

### 2. Copy Source Files

After creating the Xcode project, the source files are already organized in:
- `MyPsychAdmin/` - Main source code
  - `Core/` - AppState, Services, Database
  - `Models/` - Data models
  - `Features/` - Feature modules (Home, LetterWriter, Forms, etc.)
  - `Navigation/` - Navigation components
  - `SharedComponents/` - Reusable UI components

### 3. Add Files to Xcode

1. In Xcode, right-click on the project navigator
2. Select "Add Files to MyPsychAdmin..."
3. Select all the folders in `MyPsychAdmin/`
4. Ensure "Copy items if needed" is unchecked
5. Ensure "Create groups" is selected
6. Click Add

### 4. Configure SwiftData

The app uses SwiftData for persistent storage. The model container is configured in `MyPsychAdminApp.swift`:

```swift
@main
struct MyPsychAdminApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ClinicianDetailsModel.self)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    // ...
}
```

### 5. Build and Run

1. Select your target device or simulator
2. Press Cmd+R to build and run

## Project Structure

```
MyPsychAdmin/
├── MyPsychAdminApp.swift         # App entry point
├── Core/
│   ├── AppState/
│   │   ├── AppStore.swift        # Main app state
│   │   └── SharedDataStore.swift # Shared data singleton
│   ├── Services/                 # Document import/export
│   └── Database/                 # SwiftData configuration
├── Models/
│   ├── Domain/                   # PatientInfo, ClinicalNote, etc.
│   ├── LetterWriter/             # SectionType, SectionState
│   ├── Forms/                    # Form definitions
│   └── SwiftData/                # Persistent models
├── Features/
│   ├── Home/                     # Home screen
│   ├── MyDetails/                # Clinician profile
│   ├── LetterWriter/             # Letter writing module
│   ├── Forms/                    # Statutory forms
│   ├── PatientNotes/             # Notes viewer
│   └── DocumentImport/           # File import
├── Navigation/                   # TabBarView, NavigationDestination
└── SharedComponents/             # Reusable views and modifiers
```

## Features

### Implemented

- **Home Screen**: Quick actions, session summary
- **My Details**: Clinician profile with SwiftData persistence
- **Letter Writer**: 16-section letter composition
  - Section cards with lock/unlock
  - Font size controls
  - Section popup editors
- **Forms List**: Form selection by category
- **Patient Notes**: Note viewing with search/filter
- **Document Import**: File picker for PDF, DOCX, Excel

### To Implement

- Full popup editors for all 16 sections
- Individual form implementations (A2-A8, CTO1-7, etc.)
- Document processing (PDF text extraction, OCR)
- DOCX export
- Rich text editing

## Architecture

### State Management

The app uses SwiftUI's `@Observable` macro for state management:

- **SharedDataStore**: Singleton for shared clinical data (notes, patient info, extracted data)
- **AppStore**: Main app state including letter sections, navigation, UI state

### Data Flow

1. Documents imported → processed → notes extracted
2. Notes stored in SharedDataStore
3. SharedDataStore publishes changes via Combine
4. Views react to state changes automatically

### Persistence

- **SwiftData**: Used only for clinician profile (matches desktop app pattern)
- **In-Memory**: Patient data lives only during session

## Dependencies

No external dependencies required. Uses only Apple frameworks:
- SwiftUI
- SwiftData
- Combine
- PDFKit
- Vision
- UniformTypeIdentifiers
- PhotosUI

## License

Proprietary - All rights reserved.
