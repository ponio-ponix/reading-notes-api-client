require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "メールアドレスがない場合は無効である" do
      user = described_class.new(
        name: "Test User",
        email: nil,
        password: "password"
      )

      expect(user).not_to be_valid
    end
    it "パスワードがない場合は無効である" do
      user = described_class.new(
        name: "Test User",
        email: "test@example.com",
        password: nil
      )
    
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end
end