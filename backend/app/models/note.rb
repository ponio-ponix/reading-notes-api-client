class Note < ApplicationRecord
  belongs_to :book

  validates :quote, presence: true
  validates :page,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true
end
