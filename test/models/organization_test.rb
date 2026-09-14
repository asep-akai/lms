require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "normalizes its slug" do
    organization = Organization.new(name: "Example", slug: " Example School ", timezone: "UTC", locale: "en")
    assert_equal "example-school", organization.slug
  end

  test "requires a valid timezone" do
    organization = organizations(:one)
    organization.timezone = "Not/A_Timezone"
    assert_not organization.valid?
  end
end
