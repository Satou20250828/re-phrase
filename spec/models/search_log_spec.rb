require 'rails_helper'

RSpec.describe SearchLog, type: :model do
  describe "associations" do
    it "belongs to category" do
      association = described_class.reflect_on_association(:category)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe "enums" do
    it "defines hit_type enum" do
      expect(described_class.hit_types).to eq(
        "exact" => 0,
        "partial" => 1,
        "none" => 2
      )
    end
  end

  describe "validations" do
    it "is valid with required fields" do
      expect(FactoryBot.build(:search_log)).to be_valid
    end

    it "is invalid without query" do
      search_log = FactoryBot.build(:search_log, query: nil)
      expect(search_log).to be_invalid
    end

    it "adds a can't be blank error when query is missing" do
      search_log = FactoryBot.build(:search_log, query: nil)
      search_log.valid?
      expect(search_log.errors[:query]).to include("can't be blank")
    end

    it "is invalid without converted_text" do
      search_log = FactoryBot.build(:search_log, converted_text: nil)
      expect(search_log).to be_invalid
    end

    it "adds a can't be blank error when converted_text is missing" do
      search_log = FactoryBot.build(:search_log, converted_text: nil)
      search_log.valid?
      expect(search_log.errors[:converted_text]).to include("can't be blank")
    end

    it "is invalid without category_id" do
      search_log = FactoryBot.build(:search_log, category_id: nil)
      expect(search_log).to be_invalid
    end

    it "adds a can't be blank error when category_id is missing" do
      search_log = FactoryBot.build(:search_log, category_id: nil)
      search_log.valid?
      expect(search_log.errors[:category_id]).to include("can't be blank")
    end
  end
end
