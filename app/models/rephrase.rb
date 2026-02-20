# Rephrase stores a rewritten phrase and belongs to one category.
class Rephrase < ApplicationRecord
  belongs_to :category
  has_many :search_logs, dependent: :destroy

  validates :content, presence: true
end
