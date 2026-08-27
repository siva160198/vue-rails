class Role < ApplicationRecord
  SYSTEM_KEYS = %w[admin member].freeze

  has_many :users, foreign_key: :role, primary_key: :key, inverse_of: :role_record

  normalizes :key, with: ->(value) { value.strip.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_]/, "") }
  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, presence: true

  before_validation :mark_system_role

  def destroyable?
    !system? && users.none?
  end

  private
    def mark_system_role
      self.system = true if SYSTEM_KEYS.include?(key)
    end
end
