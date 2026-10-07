require "csv"

module DataPipelines
  class CsvDocument
    MAX_BYTES = 1.megabyte
    MAX_ROWS = 2_000
    MAX_COLUMNS = 30
    MAX_CELL_BYTES = 4_000
    class Invalid < StandardError
      attr_reader :code
      def initialize(code)
        @code = code
        super(code)
      end
    end

    def self.read(io)
      source = io.read(MAX_BYTES + 1).to_s
      raise Invalid, "CSV_TOO_LARGE" if source.bytesize > MAX_BYTES
      source = source.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
      raise Invalid, "CSV_INVALID_ENCODING" unless source.valid_encoding? && !source.include?("\0")
      source
    end

    def self.rows(source, headers:)
      # Parse both candidate delimiters with the real CSV parser (including quoted separators).
      document = [ ",", ";" ].filter_map do |separator|
        parsed = CSV.parse(source, headers: true, col_sep: separator, field_size_limit: MAX_CELL_BYTES)
        parsed if parsed.headers == headers
      rescue CSV::MalformedCSVError, ArgumentError
        nil
      end.first
      raise Invalid, "CSV_INVALID_HEADERS" unless document && headers.uniq.size == headers.size && headers.size.between?(1, MAX_COLUMNS)
      raise Invalid, "CSV_TOO_MANY_ROWS" if document.size > MAX_ROWS
      raise Invalid, "CSV_EMPTY" if document.empty?
      document.map do |row|
        values = row.fields
        raise Invalid, "CSV_INVALID_ROW" if values.size != headers.size || values.any? { |value| value.to_s.bytesize > MAX_CELL_BYTES }
        row.to_h
      end
    end

    def self.export(headers, rows)
      CSV.generate do |csv|
        csv << headers.map { |value| safe_cell(value) }
        rows.each { |row| csv << row.map { |value| safe_cell(value) } }
      end
    end

    def self.safe_cell(value)
      text = value.to_s
      # Quoting CSV alone does not protect spreadsheet consumers from formulas.
      text.match?(/\A[\p{Space}\uFEFF]*[=+\-@\uFF1D\uFF0B\uFF0D\uFF20]/) || text.match?(/\A[\t\r\n]/) ? "'#{text}" : text
    end
  end
end
