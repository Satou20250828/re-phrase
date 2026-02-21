require 'rails_helper'

RSpec.describe Rephrase, type: :model do
  describe 'associations' do
    it 'belongs to category' do
      association = described_class.reflect_on_association(:category)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with content and category' do
      expect(FactoryBot.build(:rephrase)).to be_valid
    end

    it 'is invalid without category' do
      rephrase = FactoryBot.build(:rephrase, category: nil)
      expect(rephrase).to be_invalid
    end

    it 'adds a must exist error when category is missing' do
      rephrase = FactoryBot.build(:rephrase, category: nil)
      rephrase.valid?
      expect(rephrase.errors[:category]).to include('must exist')
    end

    it 'is invalid without content' do
      rephrase = FactoryBot.build(:rephrase, content: nil)
      expect(rephrase).to be_invalid
    end

    it "adds a can't be blank error when content is missing" do
      rephrase = FactoryBot.build(:rephrase, content: nil)
      rephrase.valid?
      expect(rephrase.errors[:content]).to include("can't be blank")
    end

    it "is invalid when content exceeds 300 characters" do
      rephrase = FactoryBot.build(:rephrase, content: "あ" * 301)
      expect(rephrase).to be_invalid
    end

    it "adds a too long error when content exceeds 300 characters" do
      rephrase = FactoryBot.build(:rephrase, content: "あ" * 301)
      rephrase.valid?
      expect(rephrase.errors[:content]).to include("is too long (maximum is 300 characters)")
    end
  end
end
