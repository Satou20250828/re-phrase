require 'rails_helper'

RSpec.describe Rephrase, type: :model do
  describe 'associations' do
    it 'belongs to category' do
      association = described_class.reflect_on_association(:category)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many search_logs' do
      association = described_class.reflect_on_association(:search_logs)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it 'is valid with content and category' do
      expect(FactoryBot.build(:rephrase)).to be_valid
    end

    it 'is invalid without content' do
      rephrase = FactoryBot.build(:rephrase, content: nil)
      expect(rephrase).not_to be_valid
      expect(rephrase.errors[:content]).to include("can't be blank")
    end
  end
end
