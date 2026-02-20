class SearchLog < ApplicationRecord
  belongs_to :rephrase

  validates :rephrase, presence: true
  validates :query, presence: true
end
