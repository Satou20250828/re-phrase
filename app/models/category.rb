class Category < ApplicationRecord
  has_many :rephrases

  validates :name, presence: true, uniqueness: true
end
