# Photo deck — 1.0.8 BUILD 114

## Current status

This iteration is paused at the user's request. The photo stack motion and arrangement have not met the requested visual quality and must not be presented as accepted or as an exact iMessage reproduction. BUILD 114 is the last built implementation, not visual acceptance. No further implementation or build is requested. Preserve this state and its known limitations for any later continuation.

## Video-reference revision — BUILD 114

User authorized this rework and its necessary follow-up fixes, public sync, screenshot validation and builds. Source 1dd7f5bccf555c7e89db7c670899bee8244929a8; run https://github.com/adamnltwww/Afterimage/actions/runs/42829490345.

Removed snapshot substitutes. Four reusable UIImageViews exchange identity/order; the moving photo stays opaque. Front is centered, rear sheets alternate small left/right offsets and opposite rotations. Shared cover-based preview footprint prevents geometry jumps with mixed aspect ratios; preview uses aspectFill, fullscreen still opens the selected complete app-stored image. Counter remains attached and auto-hides. Timeline touch gating retained.

BUILD 112 and 113 passed tests but 113's offscreen drawHierarchy attachments were blank; they are not visual evidence. BUILD 114 binds the test window to the active UIWindowScene and captures presentation layers. All 10 focused tests passed. Eight colored-layer screenshots were inspected in build/verification/build-114/contact.jpg: opaque red front moves aside and behind the centered green front; rear layers remain visible at alternating offsets. This is an automated single forward exchange with color fixtures, not a real-photo UI regression or real-device gesture/visual acceptance. Do not claim exact iMessage reproduction based on these checks.

IPA build/releases/1.0.8/AFTERIMAGE-1.0.8-build114.ipa; 3,184,039 bytes; SHA256 ad3ae793231abdbfa78b075dc65fce1f3ea782d174c100d0dc8a9a48adf9a9b8. Integrity/version/bundle/arm64 checks passed. Supersedes earlier 1.0.8 packages.

## Revision BUILD 111

User approved syncing and rebuilding the stronger stack layers, front-to-back return animation and photo-attached counter hidden one second after browsing stops. Source a54f22cdf38ceaea5015d2b3824aec20f128b9d8; run https://github.com/adamnltwww/Afterimage/actions/runs/42823165593.

Device compilation/package validation passed. Three photo deck tests passed, including counter attachment and auto-hide; three browsing tests passed. Overall 8/9 focused tests passed: unchanged EnergyOptimizationTests.testDecorativeClockKeepsNormalSpeedAfterIdle failed timing threshold (0.1667 vs >0.2032) in a run reporting simulator service hub connection interruptions. No silk code was changed. Do not claim a fully green run or verified real-device animation quality.

IPA build/releases/1.0.8/AFTERIMAGE-1.0.8-build111.ipa; 3,181,559 bytes; SHA256 507201ea30e89799abc07f8c534a9ed5359b21ed9f00c45302f0e841539fda83. BUILD 111 supersedes BUILD 110.

- Timeline (including compact theme previews) and moment detail now share MemoryPhotoStack.
- Up to three visible layers, 9pt continuous corners, original aspect ratios and a position counter. Browsing never changes stored order or cover.
- Horizontal drags starting on the actual photo silhouettes turn the deck; transparent margins, captions and dates do not claim touches. The containing scroll view gives this recognizer first refusal only for touches routed through the photo surface. Vertical drags can continue scrolling detail.
- Timeline taps open the moment; detail taps open the selected original app-stored photo with the existing zoom viewer.
- Event-driven spring settling, no permanent animation clock; asynchronous ImageIO thumbnails and a small nearby-image cache. Reduced-motion setting supported.
- Added PhotoStackTests for exact photo hit regions, timeline tap callback, wraparound, unchanged-update selection retention and edit reset.
- User explicitly authorized public sync and build of 1.0.8. Public source: 7ea5aefbc1a32fad5cb06410b54f56ed9cc673a4. Run https://github.com/adamnltwww/Afterimage/actions/runs/42821114353 completed successfully. BUILD 109 caught an accessibility selector collision with UIResponder.next; renamed the actions before BUILD 110.
- Device Release compilation and all 8 focused unit tests passed (2 photo deck, 3 browsing, 3 energy). Package digest, ZIP integrity, version, bundle identity and arm64 validated locally. No screenshot/UI gesture test or real-device acceptance yet.
- IPA: build/releases/1.0.8/AFTERIMAGE-1.0.8-build110.ipa (3,177,814 bytes). SHA256 dd5f6d12c40654366034a513445d6865df265f32c0ee2a8033fba94ac96f26a5.
- Real-device acceptance: swipe on photo vs date vs blank space; drag timeline into a photo without lifting; quickly reverse deck direction; mixed portrait/landscape; edit/remove photos; tap current detail photo and zoom/close; confirm top wordmark scrubber and silk motion unchanged.
