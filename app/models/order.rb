class Order < ApplicationRecord
  STATUSES = %w[confirmed cancelled].freeze

  has_many :tickets, dependent: :destroy

  validates :customer_email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
end
