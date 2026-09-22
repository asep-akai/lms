class TableSearch
  MAX_QUERY_LENGTH = 200

  def self.normalize(value)
    value.to_s.squish.first(MAX_QUERY_LENGTH)
  end

  def self.call(scope, query:, columns:)
    normalized_query = normalize(query)
    return scope if normalized_query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%"
    conditions = Array(columns).map { |column| "#{column} ILIKE :table_search_query" }.join(" OR ")
    scope.where(conditions, table_search_query: pattern)
  end
end
