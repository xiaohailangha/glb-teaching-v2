# Guided teaching revision — 2026-11-02

Local implementation only. No commit, COS publication, production deployment or database migration was performed in this revision. Previous formal-live verification reports describe the previous production build, not this revision.

## Teaching contract

- Preserve the formal course picker, left avatar, fixed right content frame, automatic playback/capture, existing navigation and no lesson scrollbar.
- Keep the six-part teaching approach, with understanding demonstrated inside the lesson rather than multiple-choice questions. Model expressions before asking learners to use them. Support remains available; an unsuccessful turn leads to a model and supported retry.
- `food-01-v1` uses apple and banana only. It explicitly models the two noun phrases and the two `This is…` sentences. Wanting a fruit is expressed with an already-modelled noun phrase, not a new `I want…` sentence. No orange, choice screen or forced hidden-answer block remains.
- The six B1.01 courses use `sample.guidedLessons`; no leftover word checks are appended at the end. Role and location stay Li/China. Current lesson metadata describes the narrowed teaching scope; the 3000-word planning catalogue has not been rewritten or declared fully delivered.

## Passive evidence

- Teaching checks cannot mint independent mastery, even if the client omits a hint flag. Supported turns are also marked through the existing server hint endpoint.
- Unassisted natural oral turns retain server ASR, semantic matching and pronunciation evidence. Server-authored `passiveWords` and `contextVariant` record only words actually spoken; two contexts remain necessary for learned-word status.
- Course completion uses observed authored steps and successful speech. Navigation alone cannot complete a course. This is distinct from independent word mastery.
- Capability prerequisites now refer to natural oral exchanges, including understanding a partner's spoken cue, rather than requiring the retired choice checks. Existing earned account evidence is preserved.
- No evidence scores, pass/fail wording or independent-evidence messages are displayed during the guided lesson. Reliable evidence is evaluated separately from continuing a matched teaching response.

## UI

- Summary vocabulary comes from the actual authored lesson, including previously encountered words, rather than only the new-word increment. Each whole word and its whole IPA line can replay pronunciation.
- Summary preview does not restart capture or advance the course. The next-lesson action uses the page's mint colour and alignment.
- Five rounded microphone bars echo the login identity. Height uses the existing noise-gated PCM signal; no looping animation or random amplitude is used. Playback, processing, pause and errors suppress response.
- Fruit checkpoints include a stage sequence signature so an old numerical position cannot resume at the wrong stage after the lesson sequence changes; existing account vocabulary is retained.

## Validation and release boundary

- Flutter analyze: no issues.
- Focused Flutter suite: 21 tests passed, including six-course small/desktop layout, summary word/IPA clicks, preview/capture isolation, microphone gating, navigation and assistance persistence.
- Backend curriculum/evidence suite: 15 tests passed, including passive two-context evidence and prevention of assisted mastery.
- Fruit script checked for no orange/choice steps and model-before-practice ordering. Summary component rendered with real fonts to `work/guided-review/summary.png` and visually inspected. This is component rendering, not a live-browser or human microphone acceptance.
- `git diff --check` passed.
- Before production release, review and regenerate the immutable course release and its quality manifest. The existing `data/curriculum/release-quality.json` deliberately remains the historical verified manifest; its hash no longer matches edited fruit content. Do not bypass that gate or deploy only the web bundle against the old COS course assets.

## Production update

Published on 2026-11-02 after explicit user authorization. App/backend and immutable fruit resources are active. Corrected the web base href to /scene/ and added a pre-deploy guard. Live login, bundle hash, fruit manifest, automatic playback and synthetic-microphone guided practice passed; see guided-live-verification.json. Local test server is stopped. Human study remains pending.

## B1.01 six-lesson revision — local preview, 2026-11-02

This later revision is local only and supersedes the local-server status above. Scope is exactly the six B1.01 lessons, using food-04 / food-05 as teaching references. Those two source lessons and other existing course scripts are unchanged by this revision.

- Each target now has spoken Chinese meaning, an English model, and immediate capture on the same model/follow-read beat. Phrases and complete sentences are introduced after their words; supported expression precedes the short situation. No choice screens or added practice targets. Li and China remain consistent through the unit.
- Chinese meanings preserve the English display instead of replacing it with the narration text. Meaning audio advances directly into the model without the former fixed pause. Final narration plays before the shared summary.
- 48 new recordings passed the existing audio/alignment checks and a separate transcription pass. Metadata is in `data/curriculum/teaching-audio.json`; reviewed WAVs are in `work/b101-guided-v2`. The local proxy serves only manifest-listed, hash-verified WAVs. Nothing was uploaded to COS or deployed. A future production release must publish these reviewed assets and integrate their immutable release into production media delivery first.
- Reproduce authoring with `node tools/author-b101-guided-v2.mjs`, then prepare/review audio using `node tools/prepare-b101-guided-v2.mjs`. Local runtime is `node tools/start-local-preview.mjs`, using isolated local data, test-code login, and loopback ports 5296/5297.
- Validation: 15 backend evidence/curriculum tests; 2 authoring/audio integrity tests; 8 focused Flutter tests including all six courses at small/desktop sizes and immediate capture; Flutter analyze clean; debug web build with `/scene/` base; Chinese glyph coverage checked. Human microphone/teaching acceptance is still for user testing.
- Local browser smoke passed on the rebuilt bundle: login, course picker, actual narration/model playback, synthetic-microphone automatic oral submission, and My/pause navigation. Report and screenshots: `work/guided-local-live/`. Local server remains running for user testing at `http://127.0.0.1:5296/scene/`.

### Avatar parity repair

The initial B1.01 adapter played verified audio and mouth cues but omitted the teaching phase used by the existing body/face animation path. Its audio completion also returned the avatar to idle while the learner was speaking. The adapter now passes each teaching phase with playback and sends silent listening, support, success and finish transitions. SceneRuntime applies the same `lessonPoseTime`, `applyCourseFace` and secondary motion as the original courses without requiring a TeachingDirector. Audio completion preserves the teaching state; stop/pause still clears it. No new animation reel or randomly timed expression was added.

Validation: Flutter analyze clean; 14 focused course/capture/audio/intent/parity tests and a runtime phase/pause regression passed. Build and browser verification use the local preview only.
