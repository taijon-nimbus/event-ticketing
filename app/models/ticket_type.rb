class TicketType < ApplicationRecord
  belongs_to :event
  has_many :tickets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :event_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
