require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "normalizes its slug" do
    organization = Organization.new(name: "Example", slug: " Example School ", timezone: "Jakarta", locale: "en")
    assert_equal "example-school", organization.slug
  end

  test "requires WIB" do
    organization = organizations(:one)
    organization.timezone = "UTC"
    assert_not organization.valid?
  end
end
