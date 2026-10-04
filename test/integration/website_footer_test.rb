require "test_helper"

class WebsiteFooterTest < ActionDispatch::IntegrationTest
  setup do
    @website = LandingPageStarter.call!
    sign_in admins(:one), scope: :admin
  end

  test "footer settings stay in draft until published and support hiding" do
    get console_website_path
    assert_select "section#footer input[value='Save footer to draft']"
    patch console_website_path, params: { landing_page: { footer_text: "Contact our team", footer_copyright: "Copyright example", footer_background_style: "forest", footer_workspace_link: "0" } }
    assert_redirected_to console_website_path(anchor: "footer")
    get preview_console_website_path
    assert_select "footer.marketing-theme-forest", text: /Contact our team/
    assert_select "footer", text: /Copyright example/
    assert_select "footer a", count: 0
    get landing_path
    assert_select "footer", text: /Learning, organized/
    @website.reload.publish!(actor: admins(:one))
    patch console_website_path, params: { landing_page: { footer_visible: "0", footer_text: "Private footer draft" } }
    get preview_console_website_path
    assert_select "footer", count: 0
    get landing_path
    assert_select "footer", text: /Contact our team/
    assert_no_match "Private footer draft", response.body
    @website.reload.publish!(actor: admins(:one))
    get landing_path
    assert_select "footer", count: 0
    assert_select "header a", text: "Open console"
  end

  test "footer links can be created edited reordered hidden and removed independently of header links" do
    header = @website.navigation_items.first
    post console_website_navigation_items_path, params: { landing_navigation_item: { placement: "footer", label: "Contact", url: "mailto:hello@example.com" } }
    assert_redirected_to console_website_path(anchor: "footer")
    first = @website.navigation_items.where(placement: "footer").first
    post console_website_navigation_items_path, params: { landing_navigation_item: { placement: "footer", label: "Course overview", landing_section_id: @website.sections.second.id } }
    second = @website.navigation_items.where(placement: "footer").last
    patch move_console_website_navigation_item_path(second), params: { direction: "up" }
    assert_equal [ second.id, first.id ], @website.navigation_items.where(placement: "footer").pluck(:id)
    assert_equal 0, header.reload.position
    patch console_website_navigation_item_path(first), params: { landing_navigation_item: { label: "Email us", placement: "header" } }
    assert_equal "footer", first.reload.placement
    get preview_console_website_path
    assert_select "header a", text: "Email us", count: 0
    assert_select "footer nav[aria-label='Footer navigation'] a[href='mailto:hello@example.com']", text: "Email us"
    second.landing_section.update!(visible: false)
    get preview_console_website_path
    assert_select "footer a", text: "Course overview", count: 0
    @website.publish!(actor: admins(:one))
    patch console_website_navigation_item_path(first), params: { landing_navigation_item: { visible: "0" } }
    get preview_console_website_path
    assert_select "footer a", text: "Email us", count: 0
    delete console_website_navigation_item_path(first)
    assert_redirected_to console_website_path(anchor: "footer")
    get landing_path
    assert_select "footer a", text: "Email us"
    assert AuditEvent.exists?(action: "website.navigation_created", auditable: @website)
  end

  test "footer validates colors lengths destinations and escapes text" do
    patch console_website_path, params: { landing_page: { footer_background_style: "injected", footer_text: "x" * 501 } }
    assert_response :unprocessable_entity
    assert_select "section#footer"
    assert_equal "cream", @website.reload.footer_background_style
    assert_no_difference "LandingNavigationItem.count" do
      post console_website_navigation_items_path, params: { landing_navigation_item: { placement: "footer", label: "Unsafe", url: "javascript:alert(1)" } }
      assert_response :unprocessable_entity
      assert_select "h1", "Add footer link"
      post console_website_navigation_items_path, params: { landing_navigation_item: { placement: "unknown", label: "Invalid", url: "/app" } }
      assert_response :unprocessable_entity
    end
    patch console_website_path, params: { landing_page: { footer_text: "<script>unsafe()</script>", footer_copyright: nil } }
    assert_redirected_to console_website_path(anchor: "footer")
    get preview_console_website_path
    assert_select "footer script", count: 0
    assert_select "footer", text: /<script>unsafe\(\)<\/script>/
  end

  test "old snapshots and seed reruns preserve the footer contract" do
    content = @website.draft_content.except("footer")
    @website.update!(current_publication: @website.publications.create!(content: content), footer_text: "Draft footer")
    LandingPageStarter.call!
    assert_equal "Draft footer", @website.reload.footer_text
    get landing_path
    assert_select "footer", text: /Learning, organized/
    assert_no_match "Draft footer", response.body
  end

  test "publish only administrators cannot edit footer settings or links" do
    admin = admins(:two)
    admin.roles.clear
    role = Role.create!(key: "footer_publisher", name: "Publisher")
    role.permissions = Permission.where(key: %w[console.access website.publish])
    admin.roles << role
    sign_in admin, scope: :admin
    get console_website_path
    assert_select "input[value='Save footer to draft']", count: 0
    assert_select "a", text: "Add footer link", count: 0
    patch console_website_path, params: { landing_page: { footer_text: "Forbidden" } }
    assert_redirected_to new_admin_session_path
    assert_not_equal "Forbidden", @website.reload.footer_text
    sign_in admin, scope: :admin
    assert_no_difference "LandingNavigationItem.count" do
      post console_website_navigation_items_path, params: { landing_navigation_item: { placement: "footer", label: "Contact", url: "/app" } }
    end
    assert_redirected_to new_admin_session_path
  end
end
