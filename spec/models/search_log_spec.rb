require 'rails_helper'

RSpec.describe SearchLog, type: :model do
  describe 'associations' do
    it 'belongs to rephrase' do
      association = described_class.reflect_on_association(:rephrase)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with query and rephrase' do
      expect(FactoryBot.build(:search_log)).to be_valid
    end

    it 'is invalid without query' do
      search_log = FactoryBot.build(:search_log, query: nil)
      expect(search_log).not_to be_valid
      expect(search_log.errors[:query]).to include("can't be blank")
    end
  end
end
