class Rephrase < ApplicationRecord
  belongs_to :category
  has_many :search_logs, dependent: :destroy

  validates :category, presence: true
  validates :content, presence: true
end
