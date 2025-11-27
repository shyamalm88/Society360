**CURRENT TASK: STAGE 1 - The Guard Application (Flutter - Real Implementation)**

Please build the **Guard Application** using **Flutter**.
The app name should be `society360_guard`.

**1. Design & Theme (Critical)**

- **Theme:** "Cyber-Corporate" Dark Mode.
- **Colors:** - Background: `#0F172A` (Deep Slate).
  - Card Surface: `#1E293B` (Lighter Slate).
  - Primary Action: `#3B82F6` (Electric Blue).
  - Text: White (High Legibility).
- **Typography:** Large, readable fonts (Inter or Lato). The Guard persona needs big touch targets.

**2. Authentication (PROPER SESSION MANAGEMENT)**

- **Requirement:** Although the PIN is currently hardcoded ("123456"), the _mechanism_ must be production-grade.
- **Logic:**
  1. Create an `AuthRepository`.
  2. Method `loginWithPin(String pin)`:
     - Check if PIN matches "123456".
     - If valid: Save a "session_token" (dummy string) to `FlutterSecureStorage`.
     - Update Riverpod state to `authenticated`.
  3. **Auto-Login:** On App Start (in `main.dart`), check `FlutterSecureStorage`. If token exists, redirect immediately to Home.
  4. **Logout:** Clear storage and redirect to Login.

**3. Core Screens:**

- **A. Login Screen**

  - **UI:** A custom Numeric Keypad (Grid) taking up the bottom half.
  - **Visuals:** 6 large "Dot" indicators for the PIN.
  - **Validation:** If PIN is wrong, trigger a "Shake" animation (using `flutter_animate`) and clear the dots.

- **B. Dashboard (Home)**

  - **Header:** "Society360 Guard" + Current Date.
  - **Hero Action:** A MASSIVE Card/Button labeled "+ New Visitor".
  - **List:** "Recent Entries". Use a `ListView` to show dummy visitor cards (Time | Name | Status).

- **C. Visitor Entry Wizard (The Core Feature)**
  - **Step 1: Visitor Details**
    - Mobile Number (10 digit validation).
    - Name (Min 3 chars).
  - **Step 2: Purpose**
    - A Grid of 4 large selectable tiles: [Delivery], [Guest], [Cab], [Service].
  - **Step 3: Destination (Society Structure)**
    - _Mock Data:_ Use a static JSON/Map in a `SocietyRepository` to provide Blocks (A, B) -> Floors -> Flats.
    - **UI:** Horizontal Scroll for Block selection -> Grid for Flat selection.
  - **Step 4: Submit**
    - **Action:** Validate all fields.
    - **Logic:** Create a JSON object matching the `POST /visitors` API. Log it to console.
    - **Feedback:** Show a "Success" Dialog, then navigate back to Home.

**4. Technical Requirements:**

- **State:** Use `riverpod` (Code Generation) to manage the Wizard state (`VisitorFormController`).
- **Navigation:** Use `go_router`. Implement a `redirect` logic to protect routes from unauthenticated access.
- **Validation:** Ensure the Submit button is disabled until the form is valid.

**Deliverables:**

- `main.dart` (Auth Guard setup).
- `auth_repository.dart` (Secure Storage logic).
- `theme.dart` (Dark Mode palette).
- `login_screen.dart`, `dashboard_screen.dart`, `visitor_form_screen.dart`.
