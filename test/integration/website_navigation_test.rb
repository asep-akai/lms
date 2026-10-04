require "test_helper"

class WebsiteNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @website = LandingPageStarter.call!
    sign_in admins(:one), scope: :admin
  end

  test "editor manages independent navigation labels destinations visibility and ordering" do
    get new_console_website_navigation_item_path
    assert_response :success
    post console_website_navigation_items_path, params: { landing_navigation_item: { label: "About us", landing_section_id: @website.sections.second.id } }
    assert_redirected_to console_website_path(anchor: "navigation")
    item = @website.navigation_items.last
    get edit_console_website_navigation_item_path(item)
    assert_response :success
    patch console_website_navigation_item_path(item), params: { landing_navigation_item: { label: "Our approach", landing_section_id: "", url: "https://example.com/about" } }
    assert_equal "https://example.com/about", item.reload.url
    patch move_console_website_navigation_item_path(item), params: { direction: "up" }
    assert_equal item, @website.navigation_items.first
    get preview_console_website_path
    assert_select "nav[aria-label='Website navigation'] a", text: "Our approach"
    patch console_website_navigation_item_path(item), params: { landing_navigation_item: { visible: "0" } }
    get preview_console_website_path
    assert_select "nav a", text: "Our approach", count: 0
    delete console_website_navigation_item_path(item)
    assert_not LandingNavigationItem.exists?(item.id)
    assert AuditEvent.exists?(action: "website.navigation_created", auditable: @website)
    assert AuditEvent.exists?(action: "website.navigation_reordered", auditable: @website)
  end

  test "multiple sections of the same layout have distinct snapshot destinations" do
    first = @website.sections.find_by!(layout: "features")
    second = @website.sections.create!(layout: "features", heading: "For training teams", position: 8)
    item = @website.navigation_items.create!(label: "Training teams", landing_section: second, position: 1)
    post publish_console_website_path
    patch console_website_navigation_item_path(item), params: { landing_navigation_item: { label: "Draft label" } }
    get landing_path
    assert_select "nav a[href='#section-#{first.id}']", "The platform"
    assert_select "nav a[href='#section-#{second.id}']", "Training teams"
    assert_select "section#section-#{second.id}"
    assert_select "nav a", text: "Draft label", count: 0
    get preview_console_website_path
    assert_select "nav a[href='#section-#{second.id}']", "Draft label"
  end

  test "hidden or deleted sections do not leave dead links in the next publication" do
    section = @website.sections.find_by!(layout: "features")
    @website.publish!(actor: admins(:one))
    section.update!(visible: false)
    get preview_console_website_path
    assert_select "nav a", text: "The platform", count: 0
    get landing_path
    assert_select "nav a", text: "The platform"
    section.destroy!
    assert_empty @website.navigation_items.reload
    @website.publish!(actor: admins(:one))
    get landing_path
    assert_select "nav a", text: "The platform", count: 0
    assert_select "nav a[href='#{console_root_path}']", text: "Open console"
  end

  test "invalid labels unsafe URLs and conflicting destinations return editable validation errors" do
    [
      { label: "", url: "https://example.com" },
      { label: "No destination" },
      { label: "Conflicting", landing_section_id: @website.sections.first.id, url: "/app" },
      { label: "Missing section", landing_section_id: 99999999 },
      { label: "Unsafe", url: "javascript:alert(1)" },
      { label: "Unsafe", url: "//example.com" },
      { label: "Dead anchor", url: "#does-not-exist" }
    ].each do |attributes|
      assert_no_difference "LandingNavigationItem.count" do
        post console_website_navigation_items_path, params: { landing_navigation_item: attributes }
      end
      assert_response :unprocessable_entity
      assert_select "h1", "Add navigation link"
    end
  end

  test "publish-only administrators cannot modify navigation" do
    admin = admins(:two)
    admin.roles.clear
    role = Role.create!(key: "website_publisher", name: "Publisher")
    role.permissions = Permission.where(key: %w[console.access website.publish])
    admin.roles << role
    sign_in admin, scope: :admin
    get console_website_path
    assert_select "a", text: "Add navigation link", count: 0
    assert_no_difference "LandingNavigationItem.count" do
      post console_website_navigation_items_path, params: { landing_navigation_item: { label: "Not allowed", url: "/app" } }
    end
    assert_redirected_to new_admin_session_path
  end

  test "legacy publications retain their original link and an intentionally empty menu stays empty" do
    @website.publish!(actor: admins(:one))
    publication = @website.reload.current_publication
    publication.update!(content: publication.content.except("navigation"))
    get landing_path
    assert_select "nav a[href='#platform']", "The platform"
    @website.navigation_items.destroy_all
    LandingPageStarter.call!
    assert_empty @website.navigation_items.reload
    @website.publish!(actor: admins(:one))
    get landing_path
    assert_select "nav a", text: "The platform", count: 0
  end
end
