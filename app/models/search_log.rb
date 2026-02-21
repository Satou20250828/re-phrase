# SearchLog records search input/output and matching metadata.
class SearchLog < ApplicationRecord
  DEFAULT_CATEGORY_NAME = "default".freeze

  belongs_to :category
  alias_attribute :content, :converted_text

  # DBカラム未反映/認識遅延時でも enum の型解決を安定させる
  attribute :hit_type, :integer, default: 2
  enum :hit_type, { exact: 0, partial: 1, none: 2 }, prefix: true

  before_validation :ensure_default_category
  before_validation :normalize_hit_type

  validates :query, presence: true
  validates :content, presence: true, length: { maximum: 300 }
  validates :converted_text, presence: true, length: { maximum: 300 }
  validates :hit_type, presence: true

  private

  def ensure_default_category
    return if category.present?

    self.category = Category.find_or_create_by!(name: DEFAULT_CATEGORY_NAME)
  end

  def normalize_hit_type
    key = case self[:hit_type]
          when Integer
            self.class.hit_types.key(self[:hit_type])
          else
            hit_type_before_type_cast.to_s.strip
          end

    normalized_key = self.class.hit_types.key?(key) ? key : "none"
    self[:hit_type] = self.class.hit_types.fetch(normalized_key)
  end
end
