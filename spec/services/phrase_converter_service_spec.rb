require "rails_helper"

RSpec.describe PhraseConverterService do
  describe "#call" do
    subject(:result) { described_class.new(query: query, category_id: category_id).call }

    context "when an exact match exists" do
      let(:category) { FactoryBot.create(:category) }
      let(:category_id) { category.id }
      let(:query) { "「わかりました」→「承知いたしました」" }

      before do
        FactoryBot.create(:rephrase, category: category, content: query)
      end

      it "returns :exact as hit_type" do
        expect(result[:hit_type]).to eq(:exact)
      end

      it "returns false for safety_mode_applied" do
        expect(result[:safety_mode_applied]).to be(false)
      end

      it "returns converted text as result_text" do
        expect(result[:result_text]).to eq("承知いたしました")
      end
    end

    context "when only a partial match exists" do
      let(:category) { FactoryBot.create(:category) }
      let(:category_id) { category.id }
      let(:query) { "すみません" }

      before do
        FactoryBot.create(
          :rephrase,
          category: category,
          content: "「すみません」→「失礼いたしました」"
        )
      end

      it "returns :partial as hit_type" do
        expect(result[:hit_type]).to eq(:partial)
      end

      it "returns false for safety_mode_applied" do
        expect(result[:safety_mode_applied]).to be(false)
      end

      it "returns converted text as result_text" do
        expect(result[:result_text]).to eq("失礼いたしました")
      end
    end

    context "when no match exists in the target category" do
      let(:category) { FactoryBot.create(:category) }
      let(:other_category) { FactoryBot.create(:category) }
      let(:category_id) { category.id }
      let(:query) { "未登録フレーズ" }

      before do
        FactoryBot.create(
          :rephrase,
          category: other_category,
          content: "未登録フレーズ"
        )
      end

      it "returns :none as hit_type" do
        expect(result[:hit_type]).to eq(:none)
      end

      it "returns true for safety_mode_applied" do
        expect(result[:safety_mode_applied]).to be(true)
      end

      it "returns the original query as result_text" do
        expect(result[:result_text]).to eq(query)
      end
    end

    context "when query is nil" do
      let(:category) { FactoryBot.create(:category) }
      let(:category_id) { category.id }
      let(:query) { nil }

      it "returns :none as hit_type" do
        expect(result[:hit_type]).to eq(:none)
      end

      it "returns true for safety_mode_applied" do
        expect(result[:safety_mode_applied]).to be(true)
      end

      it "returns an empty string as result_text" do
        expect(result[:result_text]).to eq("")
      end
    end

    context "when query is an empty string" do
      let(:category) { FactoryBot.create(:category) }
      let(:category_id) { category.id }
      let(:query) { "" }

      it "returns :none as hit_type" do
        expect(result[:hit_type]).to eq(:none)
      end

      it "returns true for safety_mode_applied" do
        expect(result[:safety_mode_applied]).to be(true)
      end

      it "returns an empty string as result_text" do
        expect(result[:result_text]).to eq("")
      end
    end
  end
end
