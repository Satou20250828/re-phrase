require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it 'has many rephrases' do
      association = described_class.reflect_on_association(:rephrases)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it 'is valid with a name' do
      expect(FactoryBot.build(:category)).to be_valid
    end

    it 'is invalid without a name' do
      category = FactoryBot.build(:category, name: nil)
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with a duplicate name' do
      FactoryBot.create(:category, name: 'business')
      duplicate = FactoryBot.build(:category, name: 'business')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end
  end

  describe 'dependent destroy' do
    it 'deletes associated rephrases when category is destroyed' do
      category = FactoryBot.create(:category)
      FactoryBot.create(:rephrase, category: category)

      expect { category.destroy }.to change(Rephrase, :count).by(-1)
    end
  end
end
