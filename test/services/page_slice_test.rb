require "test_helper"

class PageSliceTest < ActiveSupport::TestCase
  test "limits and offsets a relation" do
    pagination, records = PageSlice.call(User.order(:id), page: 2, per_page: 1)

    assert_equal 2, pagination.current_page
    assert_equal User.count, pagination.total_count
    assert_equal 1, records.size
    assert_equal User.order(:id).second, records.first
  end

  test "clamps invalid and out of range pages" do
    first_page, = PageSlice.call(User.all, page: "invalid", per_page: 1)
    last_page, = PageSlice.call(User.all, page: 10_000, per_page: 1)

    assert_equal 1, first_page.current_page
    assert_equal first_page.total_pages, last_page.current_page
  end
end
