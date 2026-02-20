class Rephrase < ApplicationRecord
  belongs_to :category
  has_many :search_logs

  validates :content, presence: true
end
