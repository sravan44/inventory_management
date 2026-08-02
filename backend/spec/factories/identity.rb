# Factories for the Identity domain. Prefer `build_stubbed(:x)` in specs that
# don't need persistence (fastest — no DB), `build(:x)` for unsaved records, and
# `create(:x)` only when a row must exist (uniqueness, associations, queries).
FactoryBot.define do
  factory :user, class: "Identity::User" do
    sequence(:email) { |n| "user#{n}@acme.io" }
    password { "hunter2pw" }
    first_name { "Sam" }
    last_name { "Rivera" }
  end

  factory :tenant, class: "Identity::Tenant" do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:subdomain) { |n| "tenant#{n}" }
    status { :active }
  end

  factory :membership, class: "Identity::Membership" do
    association :user
    association :tenant
    role { :admin }
    status { :active }
  end

  factory :refresh_token, class: "Identity::RefreshToken" do
    association :user
    token_digest { Identity::RefreshToken.digest(SecureRandom.hex(16)) }
    expires_at { 30.days.from_now }
  end

  factory :api_key, class: "Identity::ApiKey" do
    association :tenant
    sequence(:name) { |n| "Key #{n}" }
    role { :staff }
    token_digest { Identity::ApiKey.digest(SecureRandom.hex(16)) }
  end
end
