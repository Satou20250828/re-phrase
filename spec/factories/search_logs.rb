FactoryBot.define do
  factory :search_log do
    query { "検索キーワード" }
    association :rephrase
  end
end
