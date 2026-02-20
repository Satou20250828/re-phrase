require "rails_helper"

RSpec.describe "RephrasesController", type: :request do
  describe "GET /search" do
    subject(:perform_request) { get search_path, params: params }

    let(:category) { create(:category) }
    let(:query) { "ごめん" }
    let(:params) { { q: query, category_id: category.id } }

    context "when SearchLog is saved" do
      before do
        create(:rephrase, category: category, content: "ごめん→「失礼いたしました」")
        perform_request
      end

      it "returns OK" do
        expect(response).to have_http_status(:ok)
      end

      it "shows converted text" do
        expect(response.body).to include("失礼いたしました")
      end

      it "stores the query" do
        expect(SearchLog.last&.query).to eq(query)
      end

      it "stores converted text" do
        expect(SearchLog.last&.converted_text).to eq("失礼いたしました")
      end

      it "stores category id" do
        expect(SearchLog.last&.category_id).to eq(category.id)
      end

      it "stores hit type" do
        expect(SearchLog.last&.hit_type).to eq("partial")
      end

      it "stores safety mode flag" do
        expect(SearchLog.last&.safety_mode_applied).to be(false)
      end
    end

    context "when SearchLog save fails" do
      before do
        create(:rephrase, category: category, content: "ごめん→「失礼いたしました」")
        allow(SearchLog).to receive(:create).and_return(SearchLog.new)
        perform_request
      end

      it "still returns OK" do
        expect(response).to have_http_status(:ok)
      end

      it "still shows converted text" do
        expect(response.body).to include("失礼いたしました")
      end
    end
  end
end
