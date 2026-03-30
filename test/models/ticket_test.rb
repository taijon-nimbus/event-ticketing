require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(
      name: "Rails Conf 2026",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days
    )

    @ticket_type = TicketType.create!(
      event: @event,
      name: "General Admission",
      price: 50.00,
      quantity: 100
    )

    @order = Order.create!(
      customer_email: "fan@example.com",
      total_amount: 50.00
    )
  end

  def valid_attributes
    {
      order: @order,
      ticket_type: @ticket_type,
      unit_price: 50.00
    }
  end

  test "creates ticket with valid attributes" do
    ticket = Ticket.new(valid_attributes)
    assert ticket.valid?
    assert ticket.save
  end

  test "belongs to an order" do
    ticket = Ticket.create!(valid_attributes)
    assert_equal @order, ticket.order
  end

  test "belongs to a ticket type" do
    ticket = Ticket.create!(valid_attributes)
    assert_equal @ticket_type, ticket.ticket_type
  end

  test "requires unit_price" do
    ticket = Ticket.new(valid_attributes.merge(unit_price: nil))
    assert_not ticket.valid?
    assert_includes ticket.errors[:unit_price], "is not a number"
  end

  test "unit_price must be greater than or equal to zero" do
    ticket = Ticket.new(valid_attributes.merge(unit_price: -5))
    assert_not ticket.valid?
    assert_includes ticket.errors[:unit_price], "must be greater than or equal to 0"
  end

  test "ticket_type has many tickets" do
    Ticket.create!(valid_attributes)
    second_order = Order.create!(customer_email: "other@example.com", total_amount: 50.00)
    Ticket.create!(valid_attributes.merge(order: second_order))

    assert_equal 2, @ticket_type.tickets.count
  end
end
