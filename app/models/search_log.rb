# SearchLog records search input/output and matching metadata.
class SearchLog < ApplicationRecord
  belongs_to :category

  enum :hit_type, { exact: 0, partial: 1, none: 2 }, prefix: true

  validates :query, presence: true
  validates :converted_text, presence: true
  validates :hit_type, presence: true
end
