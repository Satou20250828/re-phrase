# Category is a phrase grouping used to classify rephrases.
class Category < ApplicationRecord
  has_many :rephrases, dependent: :destroy
  has_many :search_logs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
