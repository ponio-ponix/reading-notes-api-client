# spec/support/auth_helpers.rb
module AuthHelpers
  def stub_authentication(user = nil)
    user ||= User.create!(
      email: "spec+#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )

    allow_any_instance_of(ApplicationController)
      .to receive(:authenticate_user!).and_return(true)

    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(user)
  end
end