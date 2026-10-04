require "test_helper"

class WebsiteTest < ActionDispatch::IntegrationTest
  setup { @website = LandingPageStarter.call! }

  test "public page uses the built-in template without disclosing drafts and private routes require login" do
    @website.update!(title: "Private draft title")
    @website.sections.first.update!(heading: "Private draft headline")
    get root_path
    assert_response :success
    assert_select "h1", "Good teaching deserves a better workspace."
    assert_no_match "Private draft", response.body
    assert_select "link[rel=canonical][href='#{root_url}']"
    assert_select "a[href='#section-starter-3']", text: "The platform"
    assert_select "#platform", count: 1
    get user_root_path
    assert_redirected_to new_user_session_path
    get preview_console_website_path
    assert_redirected_to new_admin_session_path
  end

  test "homepage works without a seeded CMS and never creates records on a public request" do
    @website.destroy!
    assert_no_difference [ "LandingPage.count", "LandingSection.count", "LandingPublication.count" ] do
      get root_path
      assert_response :success
      assert_select "h1", "Good teaching deserves a better workspace."
      get landing_path
      assert_response :success
      assert_select "h1", "Good teaching deserves a better workspace."
    end
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "root prioritizes the signed in workspace and console while welcome remains public" do
    sign_in users(:one)
    get root_path
    assert_redirected_to user_root_path
    assert_includes response.headers["Cache-Control"], "no-store"
    get landing_path
    assert_response :success
    assert_select "h1", "Good teaching deserves a better workspace."
    assert_select "a[href='#{user_root_path}']", text: "Open workspace"
    get user_root_path
    assert_redirected_to organization_path(organizations(:one))
    follow_redirect!
    assert_select "a.brand[href='#{user_root_path}']", text: "LMS"
    sign_out users(:one)
    sign_in admins(:one), scope: :admin
    get root_path
    assert_redirected_to console_root_path
    get landing_path
    assert_response :success
    assert_select "h1", "Good teaching deserves a better workspace."
    assert_select "a[href='#{console_root_path}']", text: "Open console"
    sign_in users(:one)
    get root_path
    assert_redirected_to console_root_path
  end

  test "default illustrations are bundled and the CMS can choose replace hide and publish them" do
    get landing_path
    assert_select ".marketing-illustrated", count: 2
    assert_select "img[alt][loading=lazy][width='1536'][height='1024']", count: 2
    assert_select ".marketing-image-left", count: 1
    section = @website.sections.find_by!(illustration: "course-materials")
    sign_in admins(:one), scope: :admin
    patch console_website_section_path(section), params: { landing_section: { illustration: "review-feedback", image_position: "left" } }
    assert_redirected_to console_website_path
    assert_equal "review-feedback", section.reload.illustration
    get preview_console_website_path
    assert_select "#section-#{section.id} .marketing-image-left img[src*='review-feedback-v1']"
    section.update!(image_alt: "Our learning space")
    section.image.attach(io: StringIO.new("test-image"), filename: "space.png", content_type: "image/png")
    @website.publish!(actor: admins(:one))
    get landing_path
    assert_select "#section-#{section.id} img[alt='Our learning space'][src='#{landing_asset_path(section.image.blob_id)}']"
    patch console_website_section_path(section), params: { landing_section: { illustration: "", image_position: "right" }, remove_image: "1" }
    get preview_console_website_path
    assert_select "#section-#{section.id} img", count: 0
    get landing_path
    assert_select "#section-#{section.id} img", count: 1
    @website.reload.publish!(actor: admins(:one))
    get landing_path
    assert_select "#section-#{section.id} img", count: 0
    LandingPageStarter.call!
    assert_equal "", section.reload.illustration
  end

  test "illustration keys and placement reject arbitrary asset paths and CSS values" do
    sign_in admins(:one), scope: :admin
    section = @website.sections.first
    patch console_website_section_path(section), params: { landing_section: { illustration: "../../secrets", image_position: "invalid" } }
    assert_response :unprocessable_entity
    assert_select "h1", "Edit website section"
    assert_nil section.reload.illustration
    assert_equal "right", section.image_position
  end

  test "deployment seeds preserve published pages and deliberately unpublished pages" do
    @website.sections.first.update!(heading: "Published site")
    @website.publish!(actor: admins(:one))
    publication = @website.current_publication
    LandingPageStarter.call!
    assert_equal publication, @website.reload.current_publication
    get root_path
    assert_select "h1", "Published site"
    @website.update!(current_publication: nil)
    LandingPageStarter.call!
    get root_path
    assert_select "h1", "Your learning workspace."
    assert_no_match "Good teaching deserves", response.body
  end

  test "sign out retains the appropriate sign in destination" do
    sign_in users(:one)
    delete destroy_user_session_path
    assert_redirected_to new_user_session_path
    sign_in admins(:one), scope: :admin
    delete destroy_admin_session_path
    assert_redirected_to new_admin_session_path
  end

  test "direct login opens the correct workspace rather than the public site" do
    post admin_session_path, params: { admin: { email: admins(:one).email, password: "password" } }
    assert_redirected_to console_root_path
    delete destroy_admin_session_path
    post user_session_path, params: { user: { email: users(:one).email, password: "password" } }
    assert_redirected_to user_root_path
  end

  test "profile updates return to the workspace rather than the marketing homepage" do
    sign_in users(:one)
    patch user_registration_path, params: { user: { name: "Updated Name", current_password: "password" } }
    assert_redirected_to user_root_path
    assert_equal "Updated Name", users(:one).reload.name
  end

  test "console editor creates updates hides orders and removes sections without publishing" do
    sign_in admins(:one), scope: :admin
    get console_website_path
    assert_response :success
    assert_select "h2", "Default template is live"
    get new_console_website_section_path
    assert_response :success
    assert_difference "LandingSection.count", 1 do
      post console_website_sections_path, params: { landing_section: { layout: "story", heading: "Test section", body: "Hello" } }
    end
    section = @website.sections.last
    assert_redirected_to console_website_path
    get edit_console_website_section_path(section)
    assert_response :success
    patch console_website_section_path(section), params: { landing_section: { heading: "Changed heading", visible: "0" } }
    assert_equal "Changed heading", section.reload.heading
    assert_not section.visible?
    patch move_console_website_section_path(section), params: { direction: "up" }
    assert_equal section, @website.sections.reload.to_a[-2]
    get preview_console_website_path
    assert_response :success
    assert_no_match "Changed heading", response.body
    assert_select "meta[name=robots][content='noindex,nofollow']"
    assert_includes response.headers["Cache-Control"], "no-store"
    delete console_website_section_path(section)
    assert_not LandingSection.exists?(section.id)
    assert_nil @website.reload.current_publication
    assert AuditEvent.exists?(action: "website.section_created", auditable: @website, organization_id: nil)
  end

  test "publish is an explicit snapshot and unpublish keeps the draft" do
    sign_in admins(:one), scope: :admin
    post publish_console_website_path
    assert_redirected_to console_website_path
    hero = @website.sections.first
    original = hero.heading
    patch console_website_section_path(hero), params: { landing_section: { heading: "Still a draft" } }
    get landing_path
    assert_select "h1", original
    assert_no_match "Still a draft", response.body
    get preview_console_website_path
    assert_select "h1", "Still a draft"
    post publish_console_website_path
    get landing_path
    assert_select "h1", "Still a draft"
    assert_select ".marketing-planned", "Planned · Not yet available"
    delete unpublish_console_website_path
    get landing_path
    assert_select "h1", "Your learning workspace."
    assert_equal "Still a draft", hero.reload.heading
    assert_equal 2, @website.publications.count
    assert_equal 2, AuditEvent.where(action: "website.published", auditable: @website).count
  end

  test "publish requires a first visible hero and validation errors stay in the editor" do
    sign_in admins(:one), scope: :admin
    hero = @website.sections.first
    patch console_website_section_path(hero), params: { landing_section: { heading: "" } }
    assert_response :unprocessable_entity
    assert_select "h1", "Edit website section"
    hero.update!(visible: false)
    post publish_console_website_path
    assert_response :unprocessable_entity
    assert_select "h1", "Website"
    assert_nil @website.reload.current_publication
  end

  test "permissions separate editor and publisher and are never available to organizations" do
    assert_empty Permission.organization_assignable.where(key: %w[website.edit website.publish])
    admin = admins(:two)
    admin.roles.clear
    role = Role.create!(key: "website_editor", name: "Website editor")
    role.permissions = Permission.where(key: %w[console.access website.edit])
    admin.roles << role
    sign_in admin, scope: :admin
    get console_website_path
    assert_response :success
    assert_select "input[type=submit][value='Save settings to draft']"
    assert_select "button", text: "Publish draft", count: 0
    assert_no_difference "LandingPublication.count" do
      post publish_console_website_path
    end
    assert_redirected_to new_admin_session_path
    role.permissions = Permission.where(key: %w[console.access website.publish])
    sign_in admin, scope: :admin
    get console_website_path
    assert_response :success
    assert_select "input[type=submit][value='Save settings to draft']", count: 0
    assert_select "button", text: "Publish draft"
    patch console_website_path, params: { landing_page: { title: "Forbidden" } }
    assert_redirected_to new_admin_session_path
    assert_not_equal "Forbidden", @website.reload.title
    sign_in users(:one)
    get preview_console_website_path
    assert_redirected_to new_admin_session_path
  end

  test "safe links and plain text prevent active content" do
    hero = @website.sections.first
    %w[javascript:alert(1) data:text/html,test //example.com /\\example.com http://example.com].each do |url|
      hero.assign_attributes(button_url: url)
      assert_not hero.valid?, url
      assert hero.errors[:button_url].any?
    end
    hero.update!(button_url: "https://example.com/contact", body: "<script>alert(1)</script>")
    @website.publish!(actor: admins(:one))
    get landing_path
    assert_select "script", text: "alert(1)", count: 0
    assert_match "&lt;script&gt;", response.body
    assert_select "a[href='https://example.com/contact']"
  end

  test "published uploads survive draft removal and cannot be fetched after unpublishing" do
    section = @website.sections.first
    section.update!(image_alt: "A learning diagram")
    section.image.attach(io: StringIO.new("test-image"), filename: "diagram.png", content_type: "image/png")
    blob_id = section.image.blob_id
    get landing_asset_path(blob_id)
    assert_response :not_found
    sign_in admins(:one), scope: :admin
    get asset_console_website_path(blob_id)
    assert_response :success
    @website.publish!(actor: admins(:one))
    section.image.detach
    get landing_asset_path(blob_id)
    assert_response :success
    assert_equal "test-image", response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    @website.update!(current_publication: nil)
    get landing_asset_path(blob_id)
    assert_response :not_found
  end

  test "metadata and upload validations are enforced and seeds never replace an edited draft" do
    sign_in admins(:one), scope: :admin
    patch console_website_path, params: { landing_page: { title: "My learning platform", description: "Organization learning." } }
    assert_redirected_to console_website_path
    LandingPageStarter.call!
    assert_equal "My learning platform", @website.reload.title
    section = @website.sections.first
    section.image.attach(io: StringIO.new("<svg></svg>"), filename: "bad.svg", content_type: "image/svg+xml")
    assert_not section.valid?
    assert section.errors[:image].any?
    section.image.detach
    section.brochure.attach(io: StringIO.new("not a PDF"), filename: "bad.txt", content_type: "text/plain")
    assert_not section.valid?
    assert section.errors[:brochure].any?
  end

  test "deleting a draft section cannot purge a published attachment" do
    section = @website.sections.last
    section.brochure.attach(io: StringIO.new("%PDF-example"), filename: "guide.pdf", content_type: "application/pdf")
    blob_id = section.brochure.blob_id
    @website.publish!(actor: admins(:one))
    perform_enqueued_jobs { section.destroy! }
    assert ActiveStorage::Blob.exists?(blob_id)
    get landing_asset_path(blob_id)
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    @website.publish!(actor: admins(:one))
    get landing_asset_path(blob_id)
    assert_response :not_found
  end
end
