# Frosted course overlay — 2026-10-31

The course picker is a non-opaque route over the existing teaching screen, using a clipped BackdropFilter and translucent tint. Opening it pauses an active lesson; closing it preserves that lesson and its checkpoint. Both classroom icon buttons retain matching size and styling.

The picker has exactly two levels: type and course. A horizontally scrollable text/underline type selector filters actual course IDs (basic expressions, situations, descriptions, review); All includes every course. The mapping lives in course_catalog.dart, with a test requiring each course to appear in exactly one type. No empty future categories are presented.

The full remaining screen is the infinite, depth-sorted card deck in both orientations. There is no side panel, description block or separate start button. Only a tap within the centered card opens the browsed course; dragging and tapping its exposed neighbors do not enter or change the learner's active course. Opening awaits the existing selection flow without autoplay, mic activation or resetting progress. A one-course type displays one card and disables cycling. The compact footer offers accessible previous/next controls and a position hint.

Tests cover transparent route and backdrop preservation, type membership, filtered selection, touch/mouse drag, wrap, outside taps, direct card entry, reopening at the selected course, single-course categories, cancellation, and reduced motion at 320×568, 390×844, 844×390 and 1280×900. No administrator code is changed.
