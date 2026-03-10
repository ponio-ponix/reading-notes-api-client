class Book < ApplicationRecord
  has_many :notes, dependent: :destroy
  belongs_to :user

  scope :alive, -> { where(deleted_at: nil) }

  validates :title, presence: true
end
