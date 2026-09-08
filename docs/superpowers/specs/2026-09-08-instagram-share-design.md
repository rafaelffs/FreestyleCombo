# Share to Instagram — Design Spec

**Status:** Approved (visual design). See mockup: `/private/tmp/.../instagram-share-mockup.html`, iterated live with the user before this was written up — this doc is the durable record of what was approved.

## Goal

Extend the existing combo share button with a second option, "Share to Instagram," that generates a branded overlay image showing the combo's name and stats, handed to Instagram's Story composer so the person can share it alongside their own freestyle video or photo.

## Scope

**Mobile only for v1.** The handoff mechanic (`instagram-stories://share` with a `stickerImage` pasteboard item) requires native pasteboard access — not available from a web browser. Web keeps only the existing "Share Link" option; no Instagram entry point is added there. A web fallback (render + manual download) is an explicit non-goal for v1, worth revisiting only if requested later.

## Entry point

The existing share icon on the combo detail hero (`mobile/lib/features/combos/combo_detail_screen.dart`, `_shareCombo`) currently calls `Share.share(url, ...)` directly. It instead opens a bottom sheet with two options:
- **Share Link** — unchanged existing behavior (`Share.share` with the `share/combos/{id}` URL).
- **Share to Instagram** — opens the new style/stats picker described below.

## The core mechanic: full-canvas transparent overlay, not a card

The generated image is a **single PNG sized to exactly match the Instagram Story canvas (1080×1920, 9:16)**, fully transparent except for a text band. It is **not** a small floating card/sticker with its own background — the user's own photo or video shows through everywhere except where text sits. This was the key correction mid-design: the first draft used a small ~30%-width card-style sticker (Strava/Spotify-Wrapped style); the user clarified they want the info to sit directly on their content instead, like a caption band, not a separate graphic object.

Handed to Instagram via the sticker pasteboard mechanism (full-size image as a `stickerImage`) — Instagram still lets the person nudge/resize it like any sticker, but since it matches the canvas exactly it starts already filling the screen, nothing to position.

### Content band

- Positioned at the bottom of the frame.
- A soft black-to-transparent gradient scrim sits behind the text (not a solid box) so it stays legible over any photo/video, without visually reading as a card.
- Individual trick chips get their own small translucent-black pill background (not a card-wide background) — this is the one place a background exists, and it's per-chip, matching how overlay chips are commonly done on top of arbitrary video content.
- A small "FSCOMBO" wordmark sits in the bottom-right corner, fixed size (see Text size below), quiet — branding, not primary content.

## Three layout styles

The person picks one on a single picker screen. All three read from the same underlying combo data; they just arrange it differently. Same 220×391-scaled-up-to-1080×1920 canvas for all three.

1. **Minimal** — combo name (left-aligned, bold) + a single meta line (whichever of trick count / difficulty / rating are enabled, joined with " · "). Quietest option.
2. **Sequence** — combo name + difficulty badge (lime-accent number) on one row, a secondary line (trick count / rating), then the full trick-chip row below. The only style whose default state shows the chip row.
3. **Stat** — combo name (smaller, muted, uppercase) + big bold stat numbers (difficulty / trick count / rating) side by side, scoreboard-style. Leads with whichever numbers are enabled.

## Per-field display toggles (shared across all three styles)

Five independent toggles, all defaulting per below, control what's shown regardless of which style is picked:

| Field | Default | Notes |
|---|---|---|
| Combo name | on | See nameless-combo behavior below — becomes non-interactive when the combo has no name. |
| Difficulty | on | |
| Trick count ("Quantity") | on | |
| Rating | off | Off by default — not every combo has enough ratings to be meaningful. |
| Trick sequence | on | The chip row. See nameless/forced-on behavior below. |

If everything relevant to a given style ends up off, that style shows a small italic "No stats selected" note rather than a blank void.

## Nameless-combo behavior

Some combos have no name — the app already falls back to the trick sequence as the effective display name elsewhere (combo cards, share links; see `CLAUDE.md`'s trick-name-fallback convention). The overlay follows the same rule:

- No title is ever shown for a nameless combo, regardless of the Combo name toggle.
- The Combo name toggle itself becomes disabled/non-interactive in this case (greyed out) — there's nothing to hide.
- The trick-chip row is **forced on** in this case even if the Trick sequence toggle is off, since the chips become the card's only identifying content once there's no title.

## Trick list length

The chip row shows the **entire** trick sequence — no arbitrary truncation for an ordinary combo (an earlier draft capped at 4 chips with a "+2"-style summary; the user explicitly rejected this). Only past **20 tricks** does the list collapse to the first 20 plus a quiet "+N more" (italic, no chip background, reads as a summary rather than another trick). 20 is comfortably above the app's typical combo length range (the random-unset-field default range is 5–20 tricks; see `CLAUDE.md`'s "Unset-field resolution during generation") — this only engages for genuinely long manually-built combos.

## Text size control

A "Text size" selector (Small / Medium / Large) on the picker screen scales all overlay text and spacing uniformly (name, stat numbers, chip text/padding, meta line, gaps) via a single multiplier — not per-element. Default is Medium. The FSCOMBO wordmark is deliberately **excluded** from this scaling — it stays a small, fixed size regardless of the Text size choice, since it's branding, not user content.

Approximate multipliers (validate against real device rendering during implementation, these came from the HTML mockup and may need adjusting for Flutter's text metrics): Small 0.82×, Medium 1×, Large 1.28×.

## Open technical questions for the implementation plan

1. **Rendering approach**: render the same widget tree used for the on-screen preview to an offscreen image via Flutter's `RenderRepaintBoundary.toImage()` (client-side, no server round-trip, works offline) — this is the natural fit given the mobile-only scope and should be the default assumption unless the plan finds a blocker.
2. **Exact export pixel size**: mockup used a 220×391 (≈1:1.78) base proportion; confirm this is close enough to Instagram Story's exact 1080×1920 and adjust font-size base values in the render widget accordingly (they don't need to match the HTML mockup's px values exactly, just the same *relative* proportions).
3. **Font**: mockup uses Plus Jakarta Sans (name/UI text) + JetBrains Mono (stat numbers, chip text) — same pairing already used app-wide (`mobile/lib/theme/app_colors.dart`'s design system, `google_fonts` package), so no new font dependency expected.
4. **Instagram handoff plumbing**: confirm the exact pasteboard payload Instagram's iOS/Android apps expect for a sticker-image share via `instagram-stories://share` (source app ID registration, content-type UTI on iOS, `Intent` extras on Android) — not yet verified against Instagram's current documented behavior.
5. **Android parity**: mockup and this spec were written iOS-first (matches this app's only-iOS-shipped-so-far status); confirm the Android `instagram-stories://` equivalent behaves the same way before assuming parity.

## Explicit non-goals for v1

- Web support (see Scope above).
- Saving/reusing a chosen style+toggle combination as a default for future shares (always starts fresh, matching how the rest of this app's generate/preference toggles already default to their own baseline each time — no evidence yet this needs persistence).
- Custom user-uploaded backgrounds or in-app video capture — this feature only produces the overlay; the user supplies their own photo/video entirely within Instagram's own Story camera/composer.
