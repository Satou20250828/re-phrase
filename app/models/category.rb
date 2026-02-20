class Category < ApplicationRecord
  has_many :rephrases, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
