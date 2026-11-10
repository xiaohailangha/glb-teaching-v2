# Formal cloud curriculum — 2026-11-04

The production App source is `C:/Users/dyw/Documents/CodexActive/2026-11-03/snow-speaks/app/scene-preview`. Backend/deployment SDK: `D:/AI语言训练/v2`. Independent admin: `D:/AI语言训练/admin`. Build the authoritative App with `tools/flutter-scene.ps1 -WorkingDirectory <the App path>`; an older App checkout is not the production build source.

## Active release

- Runtime: `0f8d04fdefe16800bd2ab2d774e74e7b90e89849dc92e9970efd94d5f3ea7176`.
- Source archive: `e26f69209a2bfcd1150eec2df98ba5e5aa94f2c85a68cd4afcdafbf51a0ac580`.
- 555 lessons, 12 categories, 87 units, 3000 canonical words, 16148 audio IDs. Titles, first-teaching ownership, prerequisites and quality facts are preserved. Audio presence does not imply human acceptance of every lesson.
- `data/curriculum/cloud-runtime/current.json` selects the release. The index SHA-256 equals its runtime ID. Private server-only teacher documents retain authoritative checks; signed student documents omit answers.
- COS resources are private, encrypted and addressed by release/hash. The App loads the selected lesson and its audio instead of requesting 16k signatures at startup.

## Runtime and evidence

`services/cloud-curriculum.mjs` serves the formal directory, pinned lesson descriptors, audio signatures, level selection, heard records, progress, challenges and source-authorized listen-and-continue actions. Old B101/test/preview activation routes are retired.

The backend validates original course/unit prerequisites and first-taught words against formal learner records. A narrated step requires its heard record. A check requires its matched response or explicit listen-and-continue branch. Revisions guard conflicting progress writes.

These sources provide guided teaching. Completion can unlock a declared successor, but does not award independent word mastery. App summaries and admin records use formal progress/completion; legacy events cannot manufacture completions or mastery. Duration calculation is unchanged.

The loading sequence remains login, resource preparation, fully prepared character, then classroom. Web/Android/iOS source shares the signed cloud model contract, verified cache and bounded loading failures. Native installer/device acceptance is separate from the Web release.

## Deployment and reset

Verified Nginx root: `/opt/glb-teaching/build/web`. App target: `/opt/glb-teaching/build/web/scene`. Root `/` and `/index.html` redirect to `/scene/`. Admin remains independently served through `/admin/`; its management bridge is authenticated and loopback-only.

Final reset epoch: `formal555-reset-v2`, with a matching one-time preferences marker and new offline queue key. Earlier batch epochs return 409. New formal records are retained after this one-time migration.

Authorized cleanup retains only App phone `19919852100` and admin username `admin` as login identities. It removes previous learning/session/test records, other accounts, old database copies and old COS backup versions. Real billing/cloud configuration and formal production assets are retained. Receipts contain scope/counts rather than deleted learner contents.

The fixed four-digit code `8888` remains the explicitly authorized temporary authentication exception; real SMS integration is pending. Passwords and credentials must not appear in source or reports.

`tools/backup-project.mjs` schema 2 snapshots current identity/learning/admin databases and the formal pointer/index/teacher/student documents. It verifies encrypted COS read-back, file hashes and SQLite integrity. Formal audio/model assets remain in private COS releases. Voice-production workers and their automations remain paused independently of deployment.
