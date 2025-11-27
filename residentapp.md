**CURRENT TASK: STAGE 2 - The Resident Application (Flutter - Real Implementation)**

Please build the **Resident Application** using **Flutter**.
The app name should be `society360_resident`.

**1. Prerequisites & Design**

- **Theme:** Deep Midnight Corporate Theme (`#0F172A`). Use **Glassmorphism** (Blur effects) for overlay cards.
- **Firebase:** Assume `firebase_core` and `firebase_auth` are configured.

**2. App Architecture (Critical)**

- Use **Riverpod** for state management.
- Create a `MetadataRepository` to handle the Society/Block/Flat data fetching.
  - _Constraint:_ Since the backend is not ready, this repository must simulate network calls (use `Future.delayed(Duration(seconds: 1))`) and return **mock JSON data** that matches the provided SQL schema structure.

**3. Application Flow:**

- **A. Splash & Routing Logic (`main.dart`)**

  - Show a logo with a Fade/Scale animation.
  - **Logic:** Check `SharedPreferences` and `FirebaseAuth`.
    - If `isFirstLaunch` == true OR null -> Go to **Intro Screen**.
    - If `currentUser` == null -> Go to **Login Screen**.
    - If `currentUser` != null BUT `flatId` not found in local storage -> Go to **Onboarding Screen**.
    - Else -> Go to **Home Screen**.

- **B. Intro Screen**

  - A generic `PageView` carousel with 3 slides: "Security", "Convenience", "Community".
  - "Get Started" button -> Sets `isFirstLaunch = false` -> Navigates to Login.

- **C. Login Screen (Real Firebase)**

  - **UI:** Sleek Dark Mode Input for Phone Number.
  - **Logic:**
    1.  Input Phone -> `verifyPhoneNumber()`.
    2.  Show OTP Modal/Screen -> Input OTP -> `signInWithCredential()`.
    3.  On Success: Navigate to **Onboarding**.

- **D. Onboarding Screen (Dynamic Cascading Select)**

  - _Goal:_ The user must select where they live.
  - **UI:** A step-by-step wizard or single form using `DropdownButtonFormField`.
  - **Logic (The "Cascading" Effect):**
    1.  **Load Cities:** Call `MetadataRepository.getCities()`.
    2.  **Select City:** Triggers `MetadataRepository.getSocieties(cityId)`. Enable Society Dropdown.
    3.  **Select Society:** Triggers `MetadataRepository.getBlocks(societyId)`. Enable Block Dropdown.
    4.  **Select Block:** Triggers `MetadataRepository.getFlats(blockId)`. Enable Flat Dropdown.
    5.  **Submit:** Save the selected `Flat` object to Riverpod state & Local Storage. Navigate to Home.

- **E. Home Dashboard**
  - **Header:** Display "Welcome, [Name]" and the selected Society Name.
  - **Status Card:** A Glassmorphic card.
    - _Default:_ "No new visitors."
    - _Active:_ "Visitor at Gate: [Name]". (Clicking opens Approval Modal).
  - **Quick Actions:** [Invite], [Pre-Approve], [Help].

**4. Technical Requirements:**

- **Notification Service:** Create `notification_service.dart`. Stub the `initialize()` method for FCM.
- **Validation:** Use regex for phone number validation.
- **Mock Data:** The `MetadataRepository` must return realistic data (e.g., "Bangalore" -> "Green Acres" -> "Block A" -> "Flat 101").

**Deliverables:**

- `main.dart` with the Routing Logic.
- `metadata_repository.dart` (The mock data layer).
- `society_onboarding_screen.dart` (The cascading logic).
- `auth_controller.dart` (Firebase Logic).
- `home_screen.dart` (UI).
