class Ticket < ApplicationRecord
  belongs_to :order
  belongs_to :ticket_type

  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
end
