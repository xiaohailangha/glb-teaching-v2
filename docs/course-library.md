# Frosted course overlay — 2026-10-31

The course picker is a non-opaque route over the existing teaching screen, with a clipped BackdropFilter and translucent tint. Opening pauses the lesson; closing preserves its checkpoint. Classroom course and settings icons retain matching styling.

The picker has two levels: type and course. A horizontally scrollable pill strip filters actual course IDs. There is no All option; opening selects the active course’s type. Selection scrolls into view. There is no search, all-types menu, or secondary picker. The catalog mapping assigns every live course to exactly one type.

The remaining screen holds the infinite depth-sorted card deck. Clicking any exposed side card centers it without selecting a lesson. Clicking the centered card enters that course through the existing selection flow, without autoplay, microphone activation or progress reset. One-course types show one card. There is no side panel, separate start button, footer line, arrow controls or card drop shadow. A plain bottom counter shows the current position and playable course count within the selected type, e.g. 02 / 03; planned but unimplemented courses are not counted.

Widget checks cover touch/mouse drag, side-card centering, centered-card entry, looping, filtered selection, cancellation, reopening, single-course types, reduced motion, and backdrop preservation at 320×568, 390×844, 844×390 and 1280×900. A 48-type fixture verifies horizontal browsing without search or a menu.

Current course design: `curriculum/adult-type-plan-v2.html` and matching JSON. Four types each contain 12 designed lessons, with goals, words, phrases, sentences, tasks and prerequisite references. Eight existing courses remain playable; the other 40 must receive full runtime lessons, audio/assets and acceptance checks before entering the runtime catalog. Design codes do not replace existing course IDs. Administrator code is unchanged.
