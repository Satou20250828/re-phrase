require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it 'has many rephrases' do
      association = described_class.reflect_on_association(:rephrases)
      expect(association.macro).to eq(:has_many)
    end

    it 'has many search_logs' do
      association = described_class.reflect_on_association(:search_logs)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it 'is valid with a name' do
      expect(FactoryBot.build(:category)).to be_valid
    end

    it 'is invalid without a name' do
      category = FactoryBot.build(:category, name: nil)
      expect(category).to be_invalid
    end

    it "adds a can't be blank error when name is missing" do
      category = FactoryBot.build(:category, name: nil)
      category.valid?
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with a duplicate name' do
      FactoryBot.create(:category, name: 'business')
      duplicate = FactoryBot.build(:category, name: 'business')
      expect(duplicate).to be_invalid
    end

    it 'adds a has already been taken error when name is duplicated' do
      FactoryBot.create(:category, name: 'business')
      duplicate = FactoryBot.build(:category, name: 'business')
      duplicate.valid?
      expect(duplicate.errors[:name]).to include('has already been taken')
    end
  end

  describe 'dependent destroy' do
    it 'deletes associated rephrases when category is destroyed' do
      category = FactoryBot.create(:category)
      FactoryBot.create(:rephrase, category: category)

      expect { category.destroy }.to change(Rephrase, :count).by(-1)
    end

    it 'deletes associated search_logs when category is destroyed' do
      category = FactoryBot.create(:category)
      FactoryBot.create(:search_log, category: category)

      expect { category.destroy }.to change(SearchLog, :count).by(-1)
    end
  end
end
