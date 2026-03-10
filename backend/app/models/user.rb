class User < ApplicationRecord
  has_secure_password

  has_many :books, dependent: :restrict_with_exception
  has_many :access_tokens, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
end