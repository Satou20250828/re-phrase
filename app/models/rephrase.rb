# Rephrase stores a rewritten phrase and belongs to one category.
class Rephrase < ApplicationRecord
  belongs_to :category

  validates :content, presence: true, length: { maximum: 300 }
end
