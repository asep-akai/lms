class PageSlice
  DEFAULT_PER_PAGE = 25

  attr_reader :current_page, :per_page, :total_count, :total_pages

  def self.call(scope, page:, per_page: DEFAULT_PER_PAGE)
    requested_page = Integer(page || 1, exception: false).to_i.clamp(1, Float::INFINITY)
    total_count = scope.count
    total_count = total_count.size if total_count.is_a?(Hash)
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    current_page = [ requested_page, total_pages ].min
    records = scope.limit(per_page).offset((current_page - 1) * per_page)

    [ new(current_page:, per_page:, total_count:, total_pages:), records ]
  end

  def initialize(current_page:, per_page:, total_count:, total_pages:)
    @current_page = current_page
    @per_page = per_page
    @total_count = total_count
    @total_pages = total_pages
  end

  def previous_page
    current_page - 1 if current_page > 1
  end

  def next_page
    current_page + 1 if current_page < total_pages
  end
  def first_item = total_count.zero? ? 0 : ((current_page - 1) * per_page) + 1
  def last_item = [ current_page * per_page, total_count ].min
  def multiple_pages? = total_pages > 1
end
