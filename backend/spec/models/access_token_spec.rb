require 'rails_helper'
require 'digest'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe AccessToken, type: :model do

  let(:user1) { User.create!(email: "access_email-#{SecureRandom.hex(10)}@gmail.com", password: "password", password_confirmation: "password", name: '太郎') }
  digest = Digest::SHA256.hexdigest(SecureRandom.hex(10))
  let(:access1) { AccessToken.create!(user: user1, token_digest: digest, expires_at: 30.days.from_now)}

  let(:user2) { User.create!(email: "access_email-#{SecureRandom.hex(10)}@gmail.com", password: "password", password_confirmation: "password", name: '太郎2') }
  digest2 = Digest::SHA256.hexdigest(SecureRandom.hex(10))
  let(:access2) { AccessToken.create!(user: user2, token_digest: digest2, expires_at: 30.days.from_now)}

  let(:user3) { User.create!(email: "access_email-#{SecureRandom.hex(10)}@gmail.com", password: "password", password_confirmation: "password", name: '太郎3') }
  digest3 = Digest::SHA256.hexdigest(SecureRandom.hex(10))
  let(:access3) { AccessToken.create!(user: user3, token_digest: digest3, expires_at: 30.days.from_now)}


  describe ".active" do
    context "有効なトークンの場合" do
      it "対象のアクセストークンが取得できること" do
        answer = AccessToken.active
        expect(answer).to include(access1)
      end
    end
  
    context "失効済みトークンの場合" do
      it "対象のアクセストークンが取得されないこと" do
        access1.update(revoked_at: Time.now)
        answer = AccessToken.active
        expect(answer).not_to include(access1)
      end
    end
  
    context "期限切れトークンの場合" do
      it "対象のアクセストークンが取得されないこと" do
        access1.update(expires_at: 1.second.ago)
        answer = AccessToken.active
        expect(answer).not_to include(access1)
      end
    end

    context "複数のアクセストークンが存在する場合" do
      it "有効なトークンだけが取得されること" do
        access2.update(revoked_at: Time.now)
        access3.update(expires_at: 1.second.ago)

        answer = AccessToken.active

        expect(answer).to include(access1)
        expect(answer).not_to include(access2)
        expect(answer).not_to include(access3)

      end
    end

    context "expires_atが現在時刻の境界にある場合" do
      it "境界の前後で有効・無効の判定が変わること" do
        travel_to(Time.now) do
          access1.update!(expires_at: Time.current + 1.second)
          # ここで有効判定
          answer = AccessToken.active
          expect(answer).to include(access1)
        
          access1.update!(expires_at: Time.current - 1.second)
          # ここで無効判定
          answer = AccessToken.active
          expect(answer).not_to include(access1)
          # 
        end
      end
    end
  end
end
