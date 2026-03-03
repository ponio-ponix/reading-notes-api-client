class AccessToken < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
end
