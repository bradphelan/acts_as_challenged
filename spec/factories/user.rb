FactoryGirl.define do
  factory :user do
    email { Forgery::Internet.email_address }
  end
end
