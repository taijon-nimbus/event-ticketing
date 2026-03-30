class Event < ApplicationRecord
  STATUSES = %w[upcoming active completed cancelled].freeze

  validates :name, presence: true
  validates :location, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_time_after_start_time

  scope :upcoming, -> { where(status: "upcoming") }

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
