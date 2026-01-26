class Book < ApplicationRecord
  has_many :notes

  scope :alive, -> { where(deleted_at: nil) }

  validates :title, presence: true
end
