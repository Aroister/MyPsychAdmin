# MyPsychAdmin - App Store Submission Guide

## Step 1: Apple Developer Program

1. Go to https://developer.apple.com/programs/
2. Click "Enroll"
3. Sign in with your Apple ID
4. Pay £79/year
5. Wait for approval (usually 24-48 hours)

---

## Step 2: App Store Connect Setup

Once enrolled, go to https://appstoreconnect.apple.com

### Create New App
- Click "+" → "New App"
- Platform: iOS
- Name: **MyPsychAdmin**
- Primary Language: English (UK)
- Bundle ID: **com.mypsychadmin.app**
- SKU: **mypsychadmin-ios-001**

---

## Step 3: App Information

### App Name
```
MyPsychAdmin
```

### Subtitle (30 chars max)
```
Psychiatric Documentation
```

### Category
- Primary: **Medical**
- Secondary: **Productivity**

### Age Rating
- Medical/Treatment Information: **Yes**
- Answer "No" to violence, gambling, etc.
- Result will be: **12+** or **17+**

---

## Step 4: App Description

### Description (4000 chars max)
```
MyPsychAdmin is a professional psychiatric documentation app designed for UK mental health clinicians.

KEY FEATURES:

• Letter Writer
Create comprehensive psychiatric assessment letters with 16 structured sections including presenting complaint, mental state examination, risk assessment, and management plans.

• Clinical Forms
Complete statutory Mental Health Act forms including:
- Section 2, 3 admission forms
- CTO forms (Community Treatment Orders)
- Section 17 leave forms
- Tribunal reports

• Patient Notes Management
Import and organise clinical notes from PDF, Word, and Excel documents. Automatic extraction of medications, diagnoses, and risk factors.

• Risk Assessment
Comprehensive risk overview with categorised incidents, severity ratings, and protective factors.

• Secure & Private
All patient data stays on your device. No cloud storage. No data leaves your phone.

DESIGNED FOR:
- Psychiatrists
- Mental health nurses
- Approved Mental Health Professionals (AMHPs)
- Clinical psychologists

LICENSE REQUIRED:
This app requires a valid license key to activate. Contact info@mypsychadmin.com to purchase a license.

Note: This app is a clinical tool for healthcare professionals. It does not provide medical advice and should be used in conjunction with professional clinical judgement.
```

### Keywords (100 chars max, comma separated)
```
psychiatry,mental health,MHA,clinical,forms,letters,NHS,assessment,documentation,psychiatric
```

### Support URL
```
mailto:info@mypsychadmin.com
```

### Marketing URL (optional)
```
https://mypsychadmin.com
```

---

## Step 5: Privacy Policy

**REQUIRED** - You must host this at a public URL.

### Option A: Create a simple webpage
Host at: `https://mypsychadmin.com/privacy` or use a free service like GitHub Pages.

### Privacy Policy Text:
```
MYPSYCHADMIN PRIVACY POLICY
Last updated: January 2026

OVERVIEW
MyPsychAdmin is designed with privacy as a core principle. All patient data is stored locally on your device and never transmitted to external servers.

DATA COLLECTION
We do not collect, store, or transmit any patient data or clinical information.

The only data transmitted is:
- License activation verification (your device ID and license key)
- Activation notification to confirm your license is active

LOCAL DATA STORAGE
All clinical data you enter (patient information, notes, letters, forms) is stored exclusively on your device using iOS secure storage.

DATA SHARING
We do not share any data with third parties.

DATA DELETION
Uninstalling the app removes all locally stored data. You can also clear data from within the app settings.

CONTACT
For privacy questions: info@mypsychadmin.com

CHANGES
We may update this policy. Check this page for the latest version.
```

---

## Step 6: Screenshots Required

### iPhone Screenshots (Required)
You need screenshots for these sizes:
- **6.7" Display** (iPhone 15 Pro Max): 1290 x 2796 pixels
- **6.5" Display** (iPhone 11 Pro Max): 1284 x 2778 pixels
- **5.5" Display** (iPhone 8 Plus): 1242 x 2208 pixels

### Recommended Screenshots (5-10)
1. Activation screen (showing license entry)
2. Home/Dashboard view
3. Letter Writer - section cards
4. Letter Writer - popup editor
5. Forms list
6. A form being filled
7. Patient notes view
8. Risk assessment view
9. My Details / clinician profile
10. Settings

### How to Take Screenshots
1. Run app in Simulator with correct device
2. Press Cmd+S to save screenshot
3. Screenshots save to Desktop

---

## Step 7: What's New (for version 1.0)
```
Initial release of MyPsychAdmin for iOS.

Features include:
- 16-section Letter Writer
- Mental Health Act forms
- CTO forms
- Patient notes with document import
- Risk assessment tools
- Clinician profile management
```

---

## Step 8: App Review Information

### Contact Information
- First Name: [Your first name]
- Last Name: [Your last name]
- Phone: [Your phone]
- Email: info@mypsychadmin.com

### Demo Account (if needed)
Since your app requires a license, provide a test license:
```
Notes: This app requires a license key. Use the following test license for review:

[Generate a 30-day license and paste here]
```

### Notes for Reviewer
```
MyPsychAdmin is a professional tool for UK mental health clinicians to create psychiatric documentation.

LICENSE ACTIVATION:
The app requires a license key which is provided after purchase. A test license is provided above for review purposes.

PROFESSIONAL USE:
This app is designed for qualified healthcare professionals. It does not provide medical advice or diagnosis.

DATA PRIVACY:
All patient data is stored locally on device only. No cloud storage or data transmission of clinical information.
```

---

## Step 9: Pricing

- Price: **Free**
- In-App Purchases: **No** (license sold separately outside app)

---

## Step 10: Build & Upload

### In Xcode:
1. Select your Team (requires Apple Developer enrollment)
2. Set destination to "Any iOS Device (arm64)"
3. Product → Archive
4. Window → Organizer
5. Select archive → Distribute App
6. Choose "App Store Connect"
7. Upload

### After Upload:
1. Go to App Store Connect
2. Select your app
3. Add build to the version
4. Submit for Review

---

## Checklist Before Submission

- [ ] Apple Developer account active
- [ ] Bundle ID registered in developer portal
- [ ] App icon 1024x1024 (no transparency) ✓
- [ ] Screenshots for all required sizes
- [ ] Privacy policy URL live and accessible
- [ ] App description written
- [ ] Keywords set
- [ ] Support email/URL set
- [ ] Test license generated for reviewer
- [ ] Archive uploaded successfully
- [ ] All app metadata completed in App Store Connect
