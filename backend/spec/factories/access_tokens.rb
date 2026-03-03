FactoryBot.define do
  factory :access_token do
    user { nil }
    token_digest { "MyString" }
    expires_at { "2026-03-03 06:52:57" }
    revoked_at { "2026-03-03 06:52:57" }
    last_used_at { "2026-03-03 06:52:57" }
  end
end
