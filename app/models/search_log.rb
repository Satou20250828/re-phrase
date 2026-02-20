class SearchLog < ApplicationRecord
  belongs_to :rephrase

  validates :query, presence: true
end
