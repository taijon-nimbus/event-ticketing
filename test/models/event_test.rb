require "test_helper"

class EventTest < ActiveSupport::TestCase
  def valid_attributes
    {
      name: "Rails Conf 2026",
      description: "Annual Ruby on Rails conference",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days,
      status: "upcoming"
    }
  end

  test "creates event with valid attributes" do
    event = Event.new(valid_attributes)
    assert event.valid?
    assert event.save
  end

  test "requires name" do
    event = Event.new(valid_attributes.except(:name))
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end

  test "requires location" do
    event = Event.new(valid_attributes.except(:location))
    assert_not event.valid?
    assert_includes event.errors[:location], "can't be blank"
  end

  test "requires start_time" do
    event = Event.new(valid_attributes.except(:start_time))
    assert_not event.valid?
    assert_includes event.errors[:start_time], "can't be blank"
  end

  test "requires end_time" do
    event = Event.new(valid_attributes.except(:end_time))
    assert_not event.valid?
    assert_includes event.errors[:end_time], "can't be blank"
  end

  test "end_time must be after start_time" do
    event = Event.new(valid_attributes.merge(end_time: 1.week.from_now))
    assert_not event.valid?
    assert_includes event.errors[:end_time], "must be after start time"
  end

  test "status must be a valid value" do
    event = Event.new(valid_attributes.merge(status: "invalid"))
    assert_not event.valid?
    assert_includes event.errors[:status], "is not included in the list"
  end

  test "status defaults to upcoming" do
    event = Event.new(valid_attributes.except(:status))
    assert_equal "upcoming", event.status
  end

  test "upcoming scope returns only upcoming events" do
    upcoming = Event.create!(valid_attributes)
    cancelled = Event.create!(valid_attributes.merge(name: "Cancelled Fest", status: "cancelled"))

    results = Event.upcoming
    assert_includes results, upcoming
    assert_not_includes results, cancelled
  end
end
