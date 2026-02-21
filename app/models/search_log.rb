# SearchLog records search input/output and matching metadata.
class SearchLog < ApplicationRecord
  belongs_to :category

  # DB接続が不安定な開発環境でも enum の型解決を安定させる
  attribute :hit_type, :integer
  enum :hit_type, { exact: 0, partial: 1, none: 2 }, prefix: true

  validates :query, presence: true
  validates :converted_text, presence: true
  validates :hit_type, presence: true
end
