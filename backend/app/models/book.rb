class Book < ApplicationRecord
  has_many :notes
  belongs_to :user

  scope :alive, -> { where(deleted_at: nil) }

  validates :title, presence: true
end
