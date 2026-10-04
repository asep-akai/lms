# Website illustration assets

Generated on 3 October 2026 with the built-in image-generation tool. The images
are conceptual editorial illustrations, not screenshots, photographs of customers,
or claims about outcomes. The final files are JPEG exports at quality 80 from
1536 × 1024 PNG originals. No text or private user data was submitted as a reference.

| File under `app/assets/images/marketing/` | Use | Why it earns its place |
| --- | --- | --- |
| `course-materials-v1.jpg` | Learning story | Connects chapter organization, reading and video in one recognizable scene |
| `review-feedback-v1.jpg` | Review story | Connects audio listening and written feedback while keeping the reviewer central |

The two files total roughly 968 KiB. Below-the-fold images use lazy loading and
async decoding, with intrinsic dimensions to reserve space. The hero remains
text-led; features, roadmap and contact sections need no supporting image.

## Design decisions

ENERGY 2 / RHYTHM 2 / MOTION 1. Retain the existing ivory, forest, sage and rust
palette and system typography. Paper texture reflects the materials and feedback
described in the copy; it is contained inside the illustrations. Alternate image
placement separates the learning story from the review story. Keep highlights
with their explanation rather than starting an unrelated full-width row. On
mobile, text comes first and the illustration follows. No text overlays the
images, and no additional animations are introduced. The two assets share a
visual style without filling every section with decoration.

## Prompt: organized learning materials

Use case: illustration-story. Asset type: editorial section illustration for the
Kelasona learning management website. Create one landscape 3:2 illustration of
organizing a learning course: a carefully composed overhead/three-quarter still
life of an open ring binder with several staggered chapter dividers, a small
stack of cream lesson sheets, one pencil, and a compact tablet showing only a
simple play triangle (no app interface). The story is course materials organized
into chapters with video alongside reading. No people. Sophisticated tactile
cut-paper and screenprinted editorial style, subtle paper grain, crisp purposeful
silhouettes, not 3D plastic, not clipart. Restrained existing brand palette: warm
ivory #faf9f5, deep forest #183f3c, sage #bac8be, a little rust #ae3d16, natural
paper neutrals. Matte ivory background with composition filling the canvas and
generous breathing room at the outer edge. No lettering, words, numerals, brand
marks, UI text, charts, invented performance data, decorative stars, globes,
arrows, gradients, or watermark. This is a conceptual illustration, not a
screenshot. Keep props legible at phone size. A unified scene, not panels or a
collage of floating icons.

## Prompt: essay and audio feedback

Use case: illustration-story. Asset type: companion editorial section illustration
for Kelasona LMS about human-reviewed essay and audio feedback. One landscape 3:2
illustration. A unified overhead still-life of a thoughtful review desk: dark
forest over-ear headphones gently curled beside an open cream notebook with a
few rust pencil underlines and simple charcoal handwritten strokes (not readable
words); a rust wooden pencil resting diagonally across a page; one small flat
audio recorder with a simple waveform on its dark display, with no letters or
numbers. The subject should clearly suggest listening to a student's recording
and writing feedback, without looking like an app screenshot. Sophisticated
tactile paper-cut / screenprinted editorial aesthetic, subtle paper grain, crisp
shapes, natural soft shadows, no shiny 3D. Restrained palette from website: ivory
#faf9f5, forest #183f3c, sage #bac8be, restrained rust #ae3d16. Sage-tinted paper
backdrop, visually quiet edges. Balance the composition around the notebook and
headphones; fill the canvas without clutter, objects legible at phone size. No
people, faces, logos, readable text, numerals, scores, robots, AI sparkles, arrows,
certificates, decorative plants, watermarks or gradients. This is a conceptual
illustration of work, not a product mockup or testimonial. No multi-panel layout.

## Maintenance

`LandingSection::ILLUSTRATIONS` is the allowlist of keys, labels, asset paths and
default alternative text. `LandingPageStarter` selects illustrations for fresh
drafts and the default public page. `LandingHelper#marketing_section_image`
prefers uploads, then resolves an allowlisted asset. Snapshots store the selected
key and placement. Keep old keys and versioned files if adding replacements, so
existing publications keep rendering the images they selected.

The one-time migration annotates the two original starter headings in existing
drafts. It does not replace uploaded images or update published snapshots. CMS
editors can select either asset, upload their own, or remove illustrations; seeds
never undo those choices. These bundled images are intentionally public, so do
not use this mechanism for private course or student media.

## Visual verification

- Hard gates PASS: the two images load at desktop and mobile sizes, have useful
  alternative text, and add no invented people, statistics or product screens.
  Browser tests verify no horizontal overflow at 320px and 390px, and verify that
  mobile images follow the text. No text is overlaid on either illustration.
- Purpose PASS: the materials image explains mixed course content; the review
  image explains listening and written feedback. Other sections remain text-led.
- Liveliness PASS: ENERGY 2 / RHYTHM 2 / MOTION 1 is retained through the existing
  headline hierarchy, paper imagery, alternate image placement and restrained
  rust action color. No new animation or visual theme was added.
- Craft PASS: the browser editor test selects a different built-in image, changes
  placement, saves and previews it, and follows Open console. Integration tests
  cover upload precedence, image removal, publication isolation and invalid keys.
  The existing body color passes at 7.30:1 and primary-button text at 6.04:1.
  Desktop preview showed no browser console errors; private CMS drafts remain
  separate from the published page.

## Background presets and image-editor follow-up

The existing ENERGY 2 / RHYTHM 2 / MOTION 1 direction remains. Cream and Sage
separate lighter reading sections; Forest gives features and contact stronger
emphasis. Automatic neighbor checks prevent accidental same-color runs without
overriding a deliberate manual choice. Existing typography, spacing, image
placement and section compositions are unchanged. Rust remains the light-section
action accent; Forest uses a cream button for a clearly visible boundary.

The editor thumbnail answers which image the section will use. Its source label
distinguishes an uploaded file from a bundled illustration, and the replacement
input explicitly explains that an empty file picker preserves the current image.
This preview is functional feedback, not a new decorative asset.

- Hard gates PASS: preset button text is checked in a browser across every
  section layout at 1400px, 390px and 320px; all meet 4.5:1. Formula checks give
  body text 6.47:1 on Sage and 8.92:1 on Forest; Forest hero-panel secondary text
  is 7.49:1. Light-button text is 6.04:1 normally and 8.59:1 on hover. Forest
  cream-button text is 10.98:1. Focus uses rust on light sections and white on
  Forest, both above 3:1. No text overlays images.
- Purpose PASS: the palette separates content, the preset supplies coordinated
  readable colors, and the thumbnail identifies current image state. No icons,
  claims, decorative effects, or new marketing images were added.
- Liveliness PASS: the existing varied compositions and editorial imagery remain;
  the automatic starter sequence is Cream/Sage/Forest/Cream/Sage/Forest.
- Craft PASS: browser tests change a built-in selection, clear it, restore it,
  select Forest, save and preview. Upload tests verify existing-image precedence,
  removal fallback, invalid-file feedback, local replacement preview, saving and
  reopening. Keyboard focus and narrow-screen overflow checks pass. The actual
  local section editor and landing preview were inspected with no console errors.
  Published snapshots remain separate from draft choices.
