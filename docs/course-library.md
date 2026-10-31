# Course library — 2026-10-31

- Flutter APP only; the independent Vue admin repository is unchanged.
- Classroom has a dedicated Courses button beside Settings. Settings no longer contains the course catalog.
- Full-screen course library: eight illustrated cards, two unit filters, current lesson, and saved teaching position. Wide screens use a compact two-column introduction; narrow screens use stacked cards. Return-to-classroom stays fixed.
- Opening the library pauses an active adult lesson. Selecting a card awaits the existing course-selection flow and returns to the classroom; tapping the teacher starts/resumes learning. It does not request microphone access or autoplay from the library.
- Progress is the saved stage index relative to the course's stage count, not a mastery score. Checkpoints are isolated using the controller's existing account-scoped storage keys; corrupt records are ignored independently.
- Flutter-native fade, hover lift, and press feedback; reduced-motion settings disable these transitions. No GSAP/JavaScript dependency.

Validation: Flutter full suite 85 passing; new course-library tests cover 320×568, 390×844, 844×390 and 1280×900, filtering/selection, no automatic playback, account isolation and malformed records. Static analysis passes. Release build passes. Online scene checks pass (8 checks), including unchanged original entry and independent models.
