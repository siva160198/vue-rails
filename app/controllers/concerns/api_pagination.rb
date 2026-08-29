module ApiPagination
  extend ActiveSupport::Concern

  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 10
  MIN_PER_PAGE = 5
  MAX_PER_PAGE = 50
  MAX_SEARCH_LENGTH = 100

  private
    def paginate_api(scope, search_columns:, sortable_columns:, default_sort:, default_direction: :asc)
      filtered = apply_api_search(scope, search_columns)
      total = filtered.count
      per_page = integer_api_param(:per_page, DEFAULT_PER_PAGE).clamp(MIN_PER_PAGE, MAX_PER_PAGE)
      total_pages = [ (total.to_f / per_page).ceil, 1 ].max
      page = integer_api_param(:page, DEFAULT_PAGE).clamp(DEFAULT_PAGE, total_pages)
      sort = allowed_api_sort(params[:sort], sortable_columns, default_sort)
      direction = allowed_api_direction(params[:direction], default_direction)

      records = filtered
        .order(sort => direction, id: direction)
        .offset((page - 1) * per_page)
        .limit(per_page)

      [ records, { page: page, per_page: per_page, total: total, total_pages: total_pages } ]
    end

    def apply_api_search(scope, columns)
      term = params[:search].to_s.strip.first(MAX_SEARCH_LENGTH)
      return scope if term.blank? || columns.empty?

      table = scope.klass.connection.quote_table_name(scope.klass.table_name)
      predicates = columns.map do |column|
        unless scope.klass.column_names.include?(column.to_s)
          raise ArgumentError, "Unknown search column: #{column}"
        end

        "#{table}.#{scope.klass.connection.quote_column_name(column)} ILIKE :api_search"
      end
      escaped = scope.klass.sanitize_sql_like(term)
      scope.where(predicates.join(" OR "), api_search: "%#{escaped}%")
    end

    def integer_api_param(key, default)
      Integer(params[key], exception: false) || default
    end

    def allowed_api_sort(requested, allowed, default)
      allowed = allowed.map(&:to_s)
      requested = requested.to_s
      allowed.include?(requested) ? requested : default.to_s
    end

    def allowed_api_direction(requested, default)
      requested = requested.to_s
      %w[asc desc].include?(requested) ? requested.to_sym : default.to_sym
    end
end
