# AGENTS.md

How this app is put together, and how to stand up another one like it.

Part 1 is the setup recipe: Rails 8, PostgreSQL, Tailwind, Devise with a
separate `/console`, and permission-based authorization. Part 2 is the working
agreement for this repository — conventions and the gotchas that have already
cost time.

---

# Part 1 — Setting up a Rails app like this one

## 1. Generate

```bash
rails new myapp --database=postgresql --css=tailwind
cd myapp
bin/rails db:create
```

Rails 8 defaults give Propshaft, importmap and Hotwire, which is what this uses.
No Node build step, no bundler for JavaScript.

**Tailwind or Bootstrap?** This app uses Tailwind (`--css=tailwind`). For
Bootstrap, `--css=bootstrap` instead — the rest of this guide is unaffected
except that you would define Bootstrap component classes rather than the
`@utility` block in step 2. Tailwind's advantage here is that the design system
lives in one file you control; Bootstrap's is that you get components for free.

## 2. Define the design vocabulary before writing any view

This is the step people skip, and every inconsistent screen traces back to it.
In `app/assets/tailwind/application.css`:

```css
@utility btn { @apply inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold; }
@utility btn-primary { @apply btn bg-indigo-600 text-white hover:bg-indigo-500; }
@utility field { @apply block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm; }
@utility label { @apply mb-1.5 block text-sm font-medium text-slate-700; }
@utility card  { @apply rounded-xl border border-slate-200 bg-white shadow-sm; }
```

See this repo's file for the full set (`hint`, `field-error`, `badge-*`, `th`,
`td`, `table-wrap`, `nav-link`). Then use only those names. Tailwind renders
nothing for a class that does not exist, so a view written against an invented
name comes out as unstyled text — which is how two forms shipped broken here.

## 3. Devise, with two identities

```bash
bundle add devise
bin/rails generate devise:install
bin/rails generate devise User
bin/rails generate devise Admin
```

Two scopes, two tables, two sessions. `User` is the app; `Admin` runs it.

**Give `Admin` no `:registerable`.** Administrators are created by other
administrators, never by signing up.

For `User`, decide about public signup on day one — retrofitting it later means
auditing who already got in. To keep account management but remove signup:

```ruby
# config/routes.rb
devise_for :users, skip: [ :registrations ], controllers: { registrations: "users/registrations" }

devise_scope :user do
  get   "users/edit" => "users/registrations#edit",   as: :edit_user_registration
  patch "users"      => "users/registrations#update", as: :user_registration
end
```

`:registerable` stays on the model — Devise files "change my own password" under
the same module — and `Users::RegistrationsController` overrides `new`/`create`
to refuse, so a route re-added by accident cannot reopen signup.

## 4. The `/console` namespace

```ruby
devise_for :admins, path: "console", path_names: { sign_in: "login", sign_out: "logout" }

namespace :console do
  root "dashboard#show"
  resources :users
  resources :admins
  resources :roles
end
```

`Console::BaseController` is where the console differs from the app:

```ruby
module Console
  class BaseController < ApplicationController
    before_action :authenticate_admin!
    before_action { authorize :console, :access? }
    after_action  :verify_authorized
    after_action  :verify_policy_scoped, only: :index
    layout "console"

    private

    def pundit_user = current_admin   # the console asks about the admin
  end
end
```

The `verify_*` callbacks make a controller that forgets to authorize fail loudly
rather than quietly serving everything.

## 5. Permissions, not role names

```bash
bundle add pundit
bin/rails generate migration CreateRbacTables
```

Four tables: `roles`, `permissions`, `role_permissions`, and a polymorphic
`role_assignments` so both `User` and `Admin` can hold roles.

The rule that makes this worth it: **policies ask about permissions, never role
names.**

```ruby
class ApplicationPolicy
  def update? = permitted?(:update)          # → principal.can?("users.update")
end
```

One policy set then serves every scope, and a new role is a database row rather
than a code change. Keep the catalog of keys in one constant
(`Permission::CATALOG`), seed it, and grant keys to roles in `db/seeds.rb`.

**Every key a policy asks for must exist in the catalog and be granted to some
role.** Eight keys once existed only in policies here, which left two whole
features reachable by nobody, looking like broken screens rather than missing
permissions.

## 6. Testing setup

- Seed roles and permissions in tests rather than fixturing them, so the suite
  cannot drift from the shipped catalog (see `test/test_helper.rb`)
- `bundle add webmock --group test` and block outbound HTTP entirely
- Add **one system test early**. `bin/rails test:system` with headless Chrome.
  One browser test is worth a dozen assertions about served HTML — this repo
  shipped a modal that had never actually been opened.
- `bin/ci` runs style, audits, brakeman and both suites. Make it green and keep
  it that way.

## 7. Things worth adding early

| Piece | Why early |
| --- | --- |
| `ApiTransport` | One place for timeouts and connection errors, before the second API client exists |
| Jobs in the primary database | Lets you enqueue inside a transaction with the rows the job is about |
| A recovery sweep job | Recovery paths get written and then never run unless something runs them |
| Modal + `modal_link_to` | ~150 lines, and every form opens in place afterwards |

---

# Part 2 — Working in this repository

## Setup and the loop

```bash
bin/setup     # gems, database, seeds
bin/dev       # web + Tailwind watcher + job worker
bin/ci        # style, audits, brakeman, tests, system tests
```

Ruby 3.3.8, PostgreSQL, Rails 8.1. `bin/ci` is the check to run before calling
something done; it is green, so a failure is yours.

**After changing `db/seeds.rb` or `Permission::CATALOG`, run
`bin/rails db:test:prepare`** — RBAC comes from the seeds, and a stale test
database makes a permission change look like it did not take.

## Conventions

**Views.** Use the utilities in `app/assets/tailwind/application.css`. Do not
invent class names; add one there instead.

**Back navigation.** Detail pages and full-page create, edit, or management
screens must include a `back_link_to` the nearest parent page. Put it in the
page header. Modal forms keep their Close or Cancel action instead of adding a
second back control.

**Modals.** `modal_link_to` in the view, `render_modal(...) if modal_request?`
in the action. The link keeps its `href` and the same URL without `?modal=1`
renders the full page — one route, one policy, one form partial.
Confirmations route through the modal automatically via
`Turbo.config.forms.confirm`, so `data: { turbo_confirm: "…" }` needs no change.

**JavaScript.** Stimulus only. No `<script>` blocks in views.

## Gotchas

Each of these has already cost an afternoon.

- **Test parallelism hangs.** Pinned to one worker in `test/test_helper.rb`. The
  cause is unknown and survived removing both prime suspects. The suite runs in
  five seconds; leave it.
- **`@request` is taken** in `ActionDispatch::IntegrationTest`.
- **`assert_select` cannot prove "no layout"** — Nokogiri invents an `<html>`
  wrapper around fragments. Assert on `response.body`.
- **Headless Chrome will not go below ~500px.** Compare against
  `window.innerWidth`, never a number you picked.
- **Minitest 6 has no `minitest/mock`.** Inject dependencies instead — every
  service here takes its client as a keyword.
- **`render "shared/x"` from a controller looks for a template**; partials need
  `render partial:`.
- **A `before_action ... only: [:gone]` referencing a removed action 404s** the
  whole controller.
- **Active Storage resolves a variant processor at boot.** `image_processing`
  2.0 raises a message Rails does not rescue, and `ruby-vips` deadlocks the dev
  server through FFI. `variant_processor` is `:disabled` — leave it unless
  something actually needs variants.
- **An `Admin` is not a `User`.** Assigning one to a `User` association raises
  `AssociationTypeMismatch`. Console wallet creation and approval both did this
  and could never run.

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, load the antislop skill for the task:
- Core filter, always on: `antislop`
- UI / visual: `antislop-ui`
- Copy & text: `antislop-copywriting`
- People: `antislop-human`
- Code comments: `antislop-code`
- Mobile / responsive: `antislop-layoutmobile`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
