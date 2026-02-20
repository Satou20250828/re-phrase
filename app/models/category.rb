# Category is a phrase grouping used to classify rephrases.
class Category < ApplicationRecord
  has_many :rephrases, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
