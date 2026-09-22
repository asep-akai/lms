require "test_helper"

class TableSearchTest < ActiveSupport::TestCase
  test "normalizes whitespace and limits query length" do
    query = "  multiple   words #{"x" * 250}  "

    normalized = TableSearch.normalize(query)

    assert_equal 200, normalized.length
    assert normalized.start_with?("multiple words ")
  end

  test "escapes SQL wildcard characters" do
    matching = Organization.create!(name: "100% Learning", slug: "one-hundred-percent", timezone: "UTC", locale: "en")
    Organization.create!(name: "100X Learning", slug: "one-hundred-x", timezone: "UTC", locale: "en")

    results = TableSearch.call(Organization.all, query: "100%", columns: %w[organizations.name])

    assert_equal [ matching ], results.to_a
  end

  test "returns the original scope for a blank query" do
    scope = Organization.where(status: "active")

    assert_same scope, TableSearch.call(scope, query: "  ", columns: %w[organizations.name])
  end
end
