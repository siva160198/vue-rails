module ApiPagination
  extend ActiveSupport::Concern

  class InvalidCursor < StandardError; end

  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 10
  MIN_PER_PAGE = 5
  MAX_PER_PAGE = 50
  MAX_SEARCH_LENGTH = 100

  private
    def paginate_cursor_api(scope, search_columns:, sortable_columns:, default_sort:, default_direction: :desc)
      filtered = apply_api_search(scope, search_columns)
      per_page = integer_api_param(:per_page, DEFAULT_PER_PAGE).clamp(MIN_PER_PAGE, MAX_PER_PAGE)
      sort = allowed_api_sort(params[:sort], sortable_columns, default_sort)
      direction = allowed_api_direction(params[:direction], default_direction)
      search = params[:search].to_s.strip.first(MAX_SEARCH_LENGTH)
      cursor = decode_api_cursor(params[:cursor], sort: sort, direction: direction, search: search)
      traversal = cursor&.fetch("traversal", "next") || "next"
      query = cursor ? apply_api_cursor(filtered, cursor, sort: sort, direction: direction) : filtered
      query_direction = traversal == "previous" ? opposite_direction(direction) : direction
      nulls = traversal == "previous" ? "FIRST" : "LAST"
      table = scope.klass.connection.quote_table_name(scope.klass.table_name)
      column = scope.klass.connection.quote_column_name(sort)
      records = query.order(Arel.sql("#{table}.#{column} #{query_direction.to_s.upcase} NULLS #{nulls}"), id: query_direction).limit(per_page + 1).to_a
      has_more = records.length > per_page
      records = records.first(per_page)
      records.reverse! if traversal == "previous"

      has_previous = cursor.present? && (traversal == "next" || has_more)
      has_next = traversal == "previous" || has_more
      total = cached_api_total(filtered) if ActiveModel::Type::Boolean.new.cast(params[:include_total])
      pagination = {
        per_page: per_page,
        next_cursor: has_next && records.any? ? encode_api_cursor(records.last, sort: sort, direction: direction, search: search, traversal: "next") : nil,
        previous_cursor: has_previous && records.any? ? encode_api_cursor(records.first, sort: sort, direction: direction, search: search, traversal: "previous") : nil,
        has_next: has_next,
        has_previous: has_previous,
        total: total
      }
      [ records, pagination ]
    end

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

    def encode_api_cursor(record, sort:, direction:, search:, traversal:)
      Rails.application.message_verifier(:api_pagination_cursor).generate(
        { "sort" => sort, "direction" => direction.to_s, "search" => search, "traversal" => traversal, "value" => api_cursor_value(record.public_send(sort)), "id" => record.id },
        expires_in: 1.hour
      )
    end

    def decode_api_cursor(token, sort:, direction:, search:)
      return nil if token.blank?

      payload = Rails.application.message_verifier(:api_pagination_cursor).verify(token)
      valid = payload.values_at("sort", "direction", "search") == [ sort, direction.to_s, search ]
      raise InvalidCursor unless valid && payload["traversal"].in?(%w[next previous]) && payload["id"].present?

      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise InvalidCursor
    end

    def apply_api_cursor(scope, cursor, sort:, direction:)
      table = scope.klass.arel_table
      attribute = table[sort]
      id_attribute = table[:id]
      value = scope.klass.type_for_attribute(sort).deserialize(cursor["value"])
      traversal = cursor.fetch("traversal")
      ascending = traversal == "previous" ? direction != :asc : direction == :asc
      id_predicate = ascending ? id_attribute.gt(cursor.fetch("id")) : id_attribute.lt(cursor.fetch("id"))

      if value.nil?
        if traversal == "previous"
          scope.where(attribute.not_eq(nil).or(attribute.eq(nil).and(id_predicate)))
        else
          scope.where(attribute.eq(nil).and(id_predicate))
        end
      else
        value_predicate = ascending ? attribute.gt(value) : attribute.lt(value)
        predicate = value_predicate.or(attribute.eq(value).and(id_predicate))
        predicate = predicate.or(attribute.eq(nil)) unless traversal == "previous"
        scope.where(predicate)
      end
    end

    def opposite_direction(direction)
      direction == :asc ? :desc : :asc
    end

    def cached_api_total(scope)
      key = "api-pagination-total:v1:#{Digest::SHA256.hexdigest(scope.to_sql)}"
      Rails.cache.fetch(key, expires_in: 30.seconds) { scope.count }
    end

    def api_cursor_value(value)
      value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.iso8601(6) : value
    end
end
