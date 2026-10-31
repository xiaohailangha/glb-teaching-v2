# Immersive course picker — 2026-10-31

The previous catalog/dashboard layout has been replaced completely. The Flutter APP now uses a single-screen dark stage with full-bleed illustrated course posters, one primary entry action, and a small position/navigation control. There are no filter tabs, resume panels, grids or progress percentages. The classroom has matching course and settings icon buttons, with courses on the left.

Inspired by the interaction in https://demos.gsap.com/demo/infinite-card-slider/ (source preview inspected at https://codepen.io/GreenSock/pen/RwKwLWK). No GSAP dependency or copied demo assets are included: Flutter renders the gesture-driven deck natively.

- Infinite position wraps modulo the eight actual course IDs, starting at the currently selected course.
- Custom depth-sorted Stack draws the nearest poster last; adjacent posters scale, translate, fade and rotate with drag position. Release velocity and distance determine a smoothly snapped target.
- Touch and mouse drags browse only; the separate primary action awaits course selection and returns to the classroom without autoplay or resetting saved progress.
- Portrait uses a bounded full-screen deck and bottom action. Landscape uses a deck with controls alongside. Reduced-motion settings remove decorative transforms and use immediate settling.
- Account-scoped saved records determine the continue label. Storage failures do not block course browsing.

Verification: focused tests pass at 320×568, 390×844, 844×390 and 1280×900, including forward/backward wrap, touch/mouse swipe, reduced motion, preserved active lesson while browsing, correct selection and no autoplay. Static analysis passes.
