# Public website and landing-page CMS

Kelasona has a public marketing page and a console-only section editor. This is
part of the existing Rails application, not a second frontend or CMS service.

## Default homepage

`/` opens the promotional homepage for signed-out visitors. Signed-in admins go
to the console; otherwise signed-in users go to their workspace. The console
takes priority when both sessions exist. Redirects are not cached, and flash
messages survive the redirect. `/welcome` always opens the promotional page;
the canonical URL for visitors is `/`.
`/app` opens the learning workspace and retains the single-organization redirect
or multi-organization chooser. `/console` remains the administrator entry point.

The built-in Kelasona template ships with the code and is visible automatically
on both local and production installations before the first CMS publication.
It needs no manual page creation, export from a developer's database, or separate
hosting service. Seeds prepare an editable copy, but public requests render the
code-owned template rather than the database draft. Editing that copy does not
change the live default until **Publish draft**.

The app default is now the captured local published version (publication 5,
published 3 October 2026 at 23:53 WIB), stored in `config/website_default.json`.
It includes the six sections, bundled illustrations, fixed published colors,
top-bar link and the original footer behavior. At capture time the publication
contained no custom footer settings or uploaded files; unpublished footer edits
are not part of this default. Stable `starter-*` section identifiers replace
database IDs so section links work on every installation.

`LandingPageStarter` reads this file for the public fallback and seeds a matching
editable draft on a fresh database. Starter draft colors are explicit presets
matching the publication; editors can switch them to Auto. Section navigation
targets are remapped to the new database records. New sections still default to
Auto. Future CMS publications do not automatically rewrite the versioned file:
promoting a later publication to the app default is a separate code change.
If a future snapshot uses uploads, package those assets explicitly before making
it the default; local Active Storage IDs and development URLs are not portable.

Published snapshots take precedence over the default. Later deployments and seeds
do not replace them. Explicitly unpublishing a previously published page still
shows the minimal workspace sign-in screen, not the template: publication history
distinguishes a new site from a site whose page was deliberately hidden. The
default is not a fallback for database outages; normal health checks still apply.

## Customize and publish your first version

1. Run the normal migrations and seeds. For an existing local Docker checkout:

   ```sh
   docker compose exec web bin/rails db:migrate db:seed
   docker compose exec web bin/rails tailwindcss:build
   docker compose exec web bin/rails restart
   ```

2. Sign in at `/console` and open **Website**. Super administrators receive the
   website permissions during seeding. Custom console roles can separately
   receive **Edit website** and **Publish website** under Website permissions.
3. Review the starter draft. It contains accurate current product features and
   a distinctly labeled planned-features section. Nothing is published by seeds.
4. Edit sections: choose a layout, heading, copy, optional highlights, button,
   image and downloadable PDF. Highlights use one line per item. Blank lines in
   descriptions create paragraphs. Text is deliberately plain text, not HTML.
5. Use **Move up / Move down** to arrange sections. Clear **Include in published
   page** to hide a section. Keep exactly one visible Hero first. A hero may have
   an uploaded image or an editable numbered learning journey.
6. Set the site name, page title, search description and optional social image.
7. Open **Preview draft**, including on a phone. Check every button destination.
   Contact is a configurable link, not a contact-form inbox. Set it to your real
   HTTPS enquiry page, WhatsApp URL, or `mailto:` address. No contact address or
   demo-booking service is invented by the starter content.
8. Choose **Publish draft** and confirm. This replaces the public version with
   a snapshot of all saved changes. Unsaved edits in another tab are not included.
9. Check `/` signed out, then verify signed-in accounts reach their console or
   workspace. Use `/welcome` to view the public page while signed in. `/app`
   always leads to the authenticated workspace. Direct login chooses the matching
   user or console workspace; sign-out returns to that identity's sign-in form.
   Private enrollment is unchanged.

**Unpublish** hides the published landing page and leaves a minimal workspace
sign-in screen. The draft is preserved, so it can be edited and published again.
This does not disable organization accounts or sign-in.

## Customize the top bar

Open **Console → Website → Top-bar navigation → Add navigation link**.

1. Enter the label visitors should see, such as “About us”.
2. Select any **Page section**, or leave it blank and enter a **Destination URL**.
   URLs may use HTTPS, `mailto:` or a local path. Use the section picker rather
   than manually entering an anchor. Choose only one destination type.
3. Save, then add more links as needed. Different sections can share the same
   layout, including multiple Features / benefits sections.
4. Use **Move up / Move down** to set the left-to-right order. Edit a link to
   rename it, change its destination, or clear **Show in navigation**. Remove
   deletes it from the draft after confirmation.
5. Preview and **Publish draft** to release the menu along with the page content.

Links to sections use stable section IDs: renaming or moving the section does
not change its destination. A hidden section's link is omitted from the menu;
deleting a section also removes its draft links. Existing published navigation
stays unchanged until the next publication. Removing every custom link leaves
workspace sign-in available without inventing a replacement menu.

On narrow screens the top-bar links and sign-in button live in a labeled **Menu**.
It supports keyboard activation, Escape and outside-click dismissal. Selecting a
section closes the menu and navigates to that section. Wider screens wrap a long
menu instead of overflowing.

The navigation migration preserves the old “The platform” link as an editable
draft item. Older published snapshots retain their original automatic link until
republished. New starter drafts create one editable link; subsequent seeds never
recreate links that an editor removed.

## Configure the footer

Open **Console → Website → Footer**. Set the footer text, optional copyright line,
and Cream, Sage or Forest background. The footer uses the site name from Site
settings. Blank text or copyright fields are omitted. **Show footer** hides or
shows the whole footer without deleting its content; **Show workspace link in
footer** controls the account link independently. The top-bar sign-in remains
available even when the footer is hidden. Save with **Save footer to draft**.

Under **Footer links**, choose **Add footer link**. Enter a label and select a
page section or a safe HTTPS, email or local URL, just like the top-bar editor.
Add as many as needed, then edit, hide, reorder or remove individual links.
Footer links have their own ordering and never appear in the top bar. Links to
hidden sections disappear until those sections become visible again. A link's
placement is fixed after creation; create a separate link to use the same
destination in both places. Do not link to policy or contact pages that do not exist.

**Preview draft** shows the complete footer. **Publish draft** releases it with
the rest of the saved page changes. Existing publications without footer settings
keep the original footer; neither migration nor seeds publish new settings. Footer
edits use `website.edit`; preview/publication use the existing website permissions.
Text is escaped, links use the shared URL validator, and changes are audited.

The migration adds draft fields to `landing_pages` and a header/footer placement
to `landing_navigation_items`, preserving all existing links as header links.
`LandingPage#draft_content` captures footer settings and filtered links, and
`landing/_footer` renders the snapshot with responsive, wrapping navigation.
No new service, environment variable or deployment step beyond normal migrations
and asset compilation is required.

## Section illustrations

The template uses two illustrations only: organized materials beside the learning
story, and written/audio feedback beside the review story. The hero, features,
roadmap and contact sections stay text-led. They illustrate activities, not actual
screenshots, customer identities or measured outcomes.

In the section editor, select **Built-in illustration** and **Image placement**.
Choose **No illustration** for text-only content. An uploaded image overrides
the built-in choice; removing that upload restores the selected illustration.
Clear both to remove images entirely. Uploads need alternative text; the two
built-ins have editable defaults. Images follow the text on mobile, regardless
of left/right desktop placement. Highlights stay with their section's copy.

The editor shows a **Section image preview** with its source: built-in illustration
or uploaded filename. Changing the illustration, selecting a replacement upload,
or marking the upload for removal updates the preview without saving. An existing
upload still takes priority when changing the illustration. The replacement file
input can say “No file chosen” while the section has an image; that input only
selects a new upload. Leaving it empty keeps the current image. To make a section
text-only, remove its upload if present and choose **No illustration**. Preview
loading and file errors are shown in text; server-side validation still applies.

Both JPEGs ship under `app/assets/images/marketing/`, with versioned filenames.
They are publicly accessible assets, not private uploads. New installs need no
manual upload. The migration adds choices to existing draft sections matching
the two original starter headings without replacing uploads or editing published
snapshots. Renamed/custom sections are unchanged. Later seeds never re-add an
illustration an editor removed. Preview and publish to update an existing site.

See [Website image assets](WEBSITE_ASSETS.md) for provenance, prompts and design
decisions. Keep asset filenames and keys compatible with historical snapshots.

## Section background styles

Each section has a **Background style** selector: **Auto**, **Cream**, **Sage** or
**Forest**. Auto is the default for newly added sections; the captured starter uses
fixed presets matching its source publication. Presets include matching
text, dividers, buttons, hover and keyboard-focus colors. Arbitrary CSS colors are
not accepted, so choosing a dark background cannot leave dark body text on it.

Auto walks the visible sections in order. It prefers Cream for Hero/Story, Forest
for Features/Contact and Sage for Planned features, then chooses the first available
color in Cream/Sage/Forest order if that preference matches the previous resolved
section or the next section's explicit choice. Manual choices are never overridden;
two manually selected Cream sections can intentionally sit together. Hidden sections
do not participate. Reordering or hiding sections can change automatic colors in
**Preview draft**.

The starter sequence is Cream hero, Sage introduction, Forest features, Cream
feedback, Sage roadmap and Forest contact. These colors separate adjacent content
while retaining the existing layouts and illustrations.

**Publish draft** stores each resolved color in the publication snapshot. Later
draft changes cannot recolor the live page. Older publications without resolved
colors retain their original layout-based colors until republished. The migration
only adds the draft preference; it does not publish or change custom content.

## Access and safety

- `website.edit` allows draft settings, sections and navigation CRUD/reordering.
- `website.publish` allows preview, publishing and unpublishing, but not edits.
- Both require an active console administrator with `console.access`.
- These permissions are excluded from organization role management.
- Previews require authentication, send `no-store` and `noindex,nofollow`, and
  are never used as a public fallback. Public HTML reads the current snapshot, or
  the code-owned template before the first publication, never a database draft.
- Text is escaped. Button destinations permit HTTPS, `mailto:`, local paths and
  anchors; executable, protocol-relative and backslash URLs are rejected.
- Images: JPEG, PNG or WebP, at most 5 MB; section images need alternative text.
  Brochures: PDF, at most 10 MB. SVG/HTML uploads are not accepted as images.
- Published assets have their own Active Storage attachment references. Replacing,
  removing or deleting a draft image does not break the current published page.
- Public media routes resolve assets only from the current publication. Draft
  media routes require console preview permission. Neither route caches responses.
  Unpublishing does not recall previously downloaded files or third-party copies.
- Changes and publishing actions record global `AuditEvent` entries with actor,
  section or revision identifiers. They do not enter organization audit logs.
- All edits and publishing serialize on the page row to avoid partially captured
  revisions. The editor is save-based, not collaborative; the latest saved edit to
  a field wins. There is no autosave or multi-editor conflict resolution.

## Code map

| File / component | Responsibility |
| --- | --- |
| `LandingPage` | Single `home` draft, site metadata, pointer to public snapshot |
| `LandingSection` | Ordered, visible/hidden reusable blocks and safe uploads/links |
| `LandingNavigationItem` | Independently ordered header/footer links, section/URL destinations, visibility and validation |
| `LandingPublication` | Content snapshot and independent references to published assets |
| `config/website_default.json` | Portable captured publication shipped with the app |
| `LandingPageStarter` | Reads the captured default and builds an idempotent editable draft, remapping section links; never overwrites existing copy |
| `LandingSectionBackgrounds` | Deterministic automatic palette selection for draft/default snapshots |
| `LandingPagePolicy` | Edit versus publish console permissions |
| `LandingController` | Anonymous live page and currently published assets |
| `Console::WebsiteController` | Draft metadata, protected preview/assets and publication |
| `Console::WebsiteSectionsController` | Draft section CRUD and ordering |
| `Console::WebsiteNavigationItemsController` | Permission-checked draft menu editing and ordering |
| `WebsiteLinkValidator` | Shared safe URL validation for section buttons and navigation |
| `app/views/landing/` and `layouts/landing.html.erb` | Shared public/preview rendering |
| `LandingHelper` | Escaped paragraphs and live/preview asset links |
| `website_image_preview_controller.js` | Local image-selection preview, loading/error feedback and object-URL cleanup |
| `.marketing-*` in `app/assets/tailwind/application.css` | Scoped responsive visual system |

Publication history is retained for audit purposes. This version does not expose
a restore-revision screen or automatic asset cleanup. Include the database and
Active Storage directory in normal backups; do not bulk-purge these attachments.

Footer appearance retains ENERGY 2 / RHYTHM 2 / MOTION 1 and the existing palette
and typography. The compact copy/link layout ends the page with useful navigation
rather than empty template columns. Links wrap and stack on narrow screens;
each has a 44px minimum height and visible keyboard focus. The footer uses the same
validated palette as the sections, with white focus on Forest and rust on light
backgrounds. No decorative icons, invented policy pages or new images are added.

## Deployment and checks

Use the existing production rollout procedure, including database migration,
seeding and rebuilding assets in the image. No new environment keys, services,
DNS records, or Nginx locations are needed. Seeds grant the two permissions to
existing system super-administrator roles, but not to custom roles. The deployment
must not automatically publish editable drafts: a console publisher reviews them
first. The built-in template is already public by default and requires no setup.

Focused checks:

```sh
docker compose exec web bin/rails db:test:prepare
docker compose exec web bin/rails test test/integration/website_test.rb test/integration/website_navigation_test.rb
docker compose exec web bin/rails test test/system/website_test.rb test/system/website_navigation_test.rb
docker compose exec web bin/ci
```

Tests cover public/private boundaries, separate permissions, section editing,
ordering and hiding, publish/unpublish snapshots, invalid links/uploads, safe
rendering, media retention, seed idempotence, confirmation UI and narrow layouts.
Navigation tests also cover distinct same-layout targets, section deletion/hiding,
legacy snapshots, empty menus, audit records and keyboard-operated mobile menus.
When updating an already-running development server, restart it once after the
navigation migration: the new `app/validators` autoload root is discovered at boot.
Production releases already start a new Rails process.

Navigation keeps the established palette, typography and controls (ENERGY 2 /
RHYTHM 2 / MOTION 1). A dedicated ordered list makes editing labels and destinations
explicit; the mobile disclosure keeps every link accessible without compressing
them into a crowded row. It reuses the existing menu controller and focus behavior.

### Initial CMS verification, 3 October 2026

- Rails suite: 276 tests, 2,439 assertions, no failures.
- Browser suite: 38 tests, 381 assertions, no failures on the same-order rerun
  (`bin/rails test test/system --seed 10473 --verbose`). The preceding full CI run
  had one intermittent session-isolation error: a certificate test's first visit
  to sign-in found a student already signed in. Its screenshot showed that state,
  not a certificate or CMS exception. The rerun did not reproduce it; the root
  cause remains unconfirmed, and the shared test harness was not changed.
- Ruby style, gem audit, importmap audit, Brakeman and seed replant passed.
- Desktop and 390px previews visually inspected; 320px and 390px overflow checks
  passed. Keyboard skip-link focus and minimum sign-in tap size are tested.
- Computed marketing button colors passed contrast at 6.04:1; body copy at
  7.30:1; dark-section body copy at 8.92:1.
- Development migration and seeds applied. Starter draft remains unpublished.
  No production deployment or publication was performed.

### Navigation follow-up verification, 3 October 2026

- Full `bin/ci` passed: 282 Rails tests / 2,515 assertions and 40 browser tests /
  421 assertions, with no failures, errors or skips. Ruby style, dependency audits,
  Brakeman and seed replant also passed.
- The earlier signed-in-session leak recurred during the first full run. The
  browser test setup now leaves the previous document before clearing browser
  cookies, preventing in-flight responses from restoring the previous session
  during cleanup. The full rerun passed without test retries.
- Desktop and 320px, 390px and 700px menu layouts were checked, including keyboard
  activation, Escape dismissal, minimum tap size and horizontal overflow.
- Development migration, seeds and CSS build completed. Rails was restarted to
  discover the validator directory; the actual console editor and section picker
  were checked in the browser. Existing content and publication were preserved;
  no production deployment or publication was performed by this change.

### Default-homepage follow-up, 3 October 2026

Historical record: the subsequent signed-in routing refinement below supersedes
the signed-in homepage behavior verified in this subsection.

- Full CI passed: 285 Rails tests / 2,554 assertions and 41 browser tests /
  427 assertions, plus style, dependency audits, Brakeman and seed replant.
  The first run stopped at fixture setup because the previous seed-replant run
  left stale test data; `db:test:prepare` resolved it before the full rerun.
- Tests cover fresh/unseeded CMS state without public-request database writes,
  unpublished draft isolation, existing publications and intentional unpublishing,
  signed-in and signed-out homepage access, and workspace routing.
- After preserving the profile-update redirect to `/app`, the focused website
  suite passed all 15 tests / 170 assertions, including that additional regression;
  style checks on the final controller and test changes also passed.
- Browser verification confirmed `/` renders the existing published page while
  signed in, **Open workspace** opens the organization dashboard, and returning
  to `/` shows the promotional page again. No browser console errors were found.
- No visual redesign, production deployment or CMS publication was performed.
  The existing layout and copy remain unchanged; only routing, default-content
  selection and the CMS publication-status explanation changed.

### Signed-in routing and illustrations, 3 October 2026

- The final routing contract is visitor homepage, admin console, then user
  workspace. `/welcome` always shows the public page. This replaces the earlier
  all-sessions-homepage behavior at the user's request.
- Added two bundled illustrations, selectable in the CMS with left/right desktop
  placement and text-first mobile layout. Existing matching starter drafts were
  annotated by migration; uploads, custom sections, navigation and publication
  snapshots were preserved. Local migration, seeds and CSS build completed.
- Rails regression suite: 288 tests / 2,594 assertions passed. Browser suite:
  42 tests / 441 assertions passed after correcting an old console-link expectation
  and the image test's scrolling so it actually triggered lazy loading.
- Final full `bin/ci` passed with both suites, Ruby style, dependency audits,
  Brakeman and seed replant.
- Actual browser preview and root-to-console routing were checked. Desktop and
  320px/390px layouts, loaded image pixels, keyboard focus and image placement
  were verified. Design decisions and gate evidence are in
  [Website image assets](WEBSITE_ASSETS.md).
- No production deployment or CMS publication was performed. Use Preview draft
  and Publish draft to apply the images to an existing published page.

### Background and image-editor checks, 3 October 2026

- Local migration added `background_style` with Auto as the draft default; assets
  were rebuilt and Rails restarted. No production deployment was performed.
- Focused service/integration checks: 23 tests / 247 assertions passed, including
  manual and automatic colors, hidden/reordered sections, validation, immutable
  publications, legacy rendering and current-image source labels.
- Focused browser checks: 6 tests / 285 assertions passed. All three palettes
  render across the five layouts at desktop, 390px and 320px without horizontal
  overflow. The image editor covers built-in, absent, uploaded, removed,
  replacement and invalid-file states. Actual local preview and editor showed
  no browser console errors. See [visual verification](WEBSITE_ASSETS.md).
- Full `bin/ci` passed: 294 Rails tests / 2,638 assertions, 44 browser tests /
  688 assertions, Ruby style, dependency audits, Brakeman and seed replant.
- At the user's subsequent request, the local existing published page was recolored
  in a separate publication (revision 4 to 5). Only resolved section backgrounds
  changed; the previous publication, published copy/navigation/assets and all draft
  content were preserved. This was an explicit local maintenance action, not an
  automatic migration or a publication of the current draft. The audit event records
  `section_backgrounds_only` and the source revision. `/welcome` was verified with
  the new six-section color sequence. Hosted production was not accessed or changed.

### Footer verification

- Final full `bin/ci` passed: 299 Rails tests / 2,707 assertions and 45 browser
  tests / 712 assertions, plus Ruby style, dependency audits, Brakeman and seeds.
- Focused Rails checks: 28 tests / 348 assertions passed for website, navigation
  and footer behavior. Coverage includes draft/publication isolation, hidden
  footer and links, independent ordering, invalid settings and URLs, escaping,
  permission boundaries, seed preservation and historical snapshots.
- Focused browser checks: 3 tests / 64 assertions passed for footer and header
  navigation. The footer test edits settings, adds and edits a link, previews its
  section destination, confirms publication, and verifies 1400px/390px/320px
  layouts, 44px link targets and visible keyboard focus.
  The actual editor's visibility labels also measure 44px high.
- Hard gates PASS: existing validated text/background pairs are reused; tests
  cover escaping and URL rejection, overflow, focus and tap targets. Public
  empty-link states omit empty navigation. The editor includes an explicit empty
  state, saving state and shared validation errors.
- Purpose and liveliness PASS: the footer retains the existing editorial palette
  and compact reading hierarchy without adding template columns or decoration.
- Craft PASS: actual browser Add footer link opens the correct form; Cancel
  returns to `#footer`. No console errors were recorded. Local migrations and
  CSS build completed; footer settings were not published and production was not
  accessed.
- The first full run exposed an over-broad section-color test selector: it counted
  the new footer as a seventh section. The assertion now explicitly counts
  `main section` elements. Desktop/mobile footer screenshots were also inspected,
  and whitespace preservation was limited to paragraph text to keep spacing compact.

### Captured app default, 4 October 2026

- Full `bin/ci` passed: 302 Rails tests / 2,752 assertions and 45 browser tests /
  712 assertions, plus Ruby style, dependency audits, Brakeman and seed replant.
- Promoted local publication 5 into the versioned `config/website_default.json`.
  A read-only comparison confirmed exact content equality after replacing section
  database IDs and matching links with portable `starter-*` anchors. No database
  draft or publication was changed during capture.
- No uploaded assets were referenced. Both illustrations already ship in the
  repository, so a new host needs no development upload storage or database copy.
- Focused checks passed: 37 tests / 437 assertions covering fresh defaults,
  seed/link remapping, fixed published colors, preservation of customized and
  deliberately unpublished sites, CMS permissions and publication isolation.
- This changes the default content source, not the visual design. Existing
  publications remain authoritative, and future draft edits still require an
  explicit CMS publication. No production access or deployment was performed.

## Future template improvements

Prioritize a real enquiry/demo destination, a visual explanation of the learning
workflow, audience-specific content for administrators/teachers/students, and
Indonesian/English copy. Image placement and bundled illustrations now exist.
Later CMS controls could support secondary buttons. These are proposals, not
implemented features or claims for the public page.

## Deliberately deferred

Organization-level branding, organization logos, additional customization and
blog publishing are future features. The landing page can describe that roadmap;
it must not promise those capabilities as already available. This CMS controls
the global promotional page only. Pricing, customer testimonials, customer logos,
analytics trackers and contact-form processing have not been fabricated or added.

Visual inspiration: [Hacktivate](https://www.hacktivate.io/) (strong editorial
headlines and learning-workflow emphasis). Content organization inspiration:
[ARKA](https://arkatranspsikologi.com/) (introduction, services, differentiators,
brochure and contact). The page uses original Kelasona copy and layout, not their
assets, customer claims or branding.
