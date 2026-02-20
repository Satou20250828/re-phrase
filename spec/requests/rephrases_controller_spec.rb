require "rails_helper"

RSpec.describe "RephrasesController", type: :request do
  describe "GET /search" do
    let(:category) { FactoryBot.create(:category) }

    it "converts text and stores a search log" do
      FactoryBot.create(:rephrase, category: category, content: "ごめん→「失礼いたしました」")

      get search_path, params: { q: "ごめん", category_id: category.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("失礼いたしました")

      search_log = SearchLog.order(:id).last
      expect(search_log.query).to eq("ごめん")
      expect(search_log.converted_text).to eq("失礼いたしました")
      expect(search_log.category_id).to eq(category.id)
      expect(search_log.hit_type).to eq("partial")
      expect(search_log.safety_mode_applied).to be(false)
    end

    it "returns a response even when SearchLog save fails" do
      FactoryBot.create(:rephrase, category: category, content: "ごめん→「失礼いたしました」")
      allow(SearchLog).to receive(:create).and_return(SearchLog.new)

      get search_path, params: { q: "ごめん", category_id: category.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("失礼いたしました")
    end
  end
end
