FactoryBot.define do
  factory :template do
    account { nil }
    name { "MyString" }
    subject { "MyString" }
    body { "MyText" }
    template_type { "MyString" }
    status { "MyString" }
  end
end
