class AvatarProcessor
  MAX_INPUT_BYTES = 10.megabytes
  MAX_OUTPUT_BYTES = 50.kilobytes
  MAX_PIXELS = 25_000_000
  MAX_DIMENSION = 512
  QUALITY_STEPS = [ 65, 55, 45, 35, 25 ].freeze

  class InvalidImage < StandardError; end

  Result = Data.define(:io, :filename, :content_type, :byte_size)

  def self.call(upload)
    new(upload).call
  end

  def initialize(upload)
    @upload = upload
  end

  def call
    raise InvalidImage, "avatar_missing" unless @upload.respond_to?(:tempfile)
    raise InvalidImage, "avatar_too_large" if @upload.size > MAX_INPUT_BYTES
    MalwareScanner.scan!(@upload.tempfile.path)

    Timeout.timeout(Integer(ENV.fetch("AVATAR_PROCESSING_TIMEOUT_SECONDS", "10"), 10).clamp(1, 30)) do
      require "vips"
      image = Vips::Image.new_from_file(@upload.tempfile.path, access: :sequential, fail_on: :warning).autorot
      raise InvalidImage, "avatar_dimensions_too_large" if image.width * image.height > MAX_PIXELS

      square = [ image.width, image.height ].min
      image = image.crop((image.width - square) / 2, (image.height - square) / 2, square, square)
      image = image.resize(MAX_DIMENSION.fdiv(square)) if square > MAX_DIMENSION
      image = image.colourspace(:srgb) unless image.interpretation == :srgb

      encoded = QUALITY_STEPS.lazy.map do |quality|
        image.heifsave_buffer(Q: quality, compression: :av1, strip: true, effort: 4)
      end.find { |buffer| buffer.bytesize <= MAX_OUTPUT_BYTES }
      raise InvalidImage, "avatar_cannot_fit" unless encoded

      return Result.new(io: StringIO.new(encoded), filename: "avatar.avif", content_type: "image/avif", byte_size: encoded.bytesize)
    end
  rescue MalwareScanner::ThreatDetected, MalwareScanner::ScanFailed => error
    Rails.logger.warn("Avatar security scan failed: #{error.class}")
    raise InvalidImage, error.message
  rescue Vips::Error, LoadError, Timeout::Error => error
    Rails.logger.warn("Avatar processing failed: #{error.class}: #{error.message}")
    raise InvalidImage, "avatar_invalid"
  end
end
