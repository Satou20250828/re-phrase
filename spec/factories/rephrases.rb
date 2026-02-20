FactoryBot.define do
  factory :rephrase do
    content { "言い換えテキスト" }
    association :category
  end
end
