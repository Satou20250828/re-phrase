FactoryBot.define do
  factory :search_log do
    query { "検索キーワード" }
    converted_text { "変換後テキスト" }
    category { association :category, strategy: :create }
    hit_type { :exact }
    safety_mode_applied { false }
  end
end
