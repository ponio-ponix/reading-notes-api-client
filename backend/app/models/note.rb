class Note < ApplicationRecord
  belongs_to :book

  validates :quote, presence: true, length: { maximum: 1000 }
  validates :memo,  length: { maximum: 2000 }, allow_nil: true
  validates :page,  numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true

  before_validation :strip_text

  private

  def strip_text
    self.quote = quote&.strip
    self.memo  = memo&.strip
  end
end