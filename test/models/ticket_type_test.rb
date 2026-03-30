require "test_helper"

class TicketTypeTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(
      name: "Rails Conf 2026",
      description: "Annual Ruby on Rails conference",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days
    )
  end

  def valid_attributes
    {
      event: @event,
      name: "General Admission",
      price: 50.00,
      quantity: 100
    }
  end

  test "creates ticket type with valid attributes" do
    ticket_type = TicketType.new(valid_attributes)
    assert ticket_type.valid?
    assert ticket_type.save
  end

  test "belongs to an event" do
    ticket_type = TicketType.create!(valid_attributes)
    assert_equal @event, ticket_type.event
  end

  test "requires name" do
    ticket_type = TicketType.new(valid_attributes.except(:name))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:name], "can't be blank"
  end

  test "requires price" do
    ticket_type = TicketType.new(valid_attributes.except(:price))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:price], "is not a number"
  end

  test "price must be greater than or equal to zero" do
    ticket_type = TicketType.new(valid_attributes.merge(price: -5))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:price], "must be greater than or equal to 0"
  end

  test "requires quantity" do
    ticket_type = TicketType.new(valid_attributes.merge(quantity: nil))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:quantity], "is not a number"
  end

  test "quantity must be greater than or equal to zero" do
    ticket_type = TicketType.new(valid_attributes.merge(quantity: -1))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:quantity], "must be greater than or equal to 0"
  end

  test "quantity must be an integer" do
    ticket_type = TicketType.new(valid_attributes.merge(quantity: 1.5))
    assert_not ticket_type.valid?
    assert_includes ticket_type.errors[:quantity], "must be an integer"
  end

  test "name must be unique within an event" do
    TicketType.create!(valid_attributes)
    duplicate = TicketType.new(valid_attributes)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "same name allowed on different events" do
    other_event = Event.create!(
      name: "RubyKaigi 2026",
      location: "Tokyo, JP",
      start_time: 3.weeks.from_now,
      end_time: 3.weeks.from_now + 2.days
    )

    TicketType.create!(valid_attributes)
    other_ticket = TicketType.new(valid_attributes.merge(event: other_event))
    assert other_ticket.valid?
  end

  test "event has many ticket types" do
    TicketType.create!(valid_attributes)
    TicketType.create!(valid_attributes.merge(name: "VIP", price: 150.00, quantity: 20))

    assert_equal 2, @event.ticket_types.count
  end
end
