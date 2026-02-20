# SearchLog records a search query and its selected rephrase.
class SearchLog < ApplicationRecord
  belongs_to :rephrase

  validates :query, presence: true
end
