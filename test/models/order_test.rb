require "test_helper"

class OrderTest < ActiveSupport::TestCase
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
  end

  def valid_attributes
    {
      customer_email: "fan@example.com",
      total_amount: 100.00,
      status: "confirmed"
    }
  end

  test "creates order with valid attributes" do
    order = Order.new(valid_attributes)
    assert order.valid?
    assert order.save
  end

  test "requires customer_email" do
    order = Order.new(valid_attributes.except(:customer_email))
    assert_not order.valid?
    assert_includes order.errors[:customer_email], "can't be blank"
  end

  test "requires valid email format" do
    order = Order.new(valid_attributes.merge(customer_email: "not-an-email"))
    assert_not order.valid?
    assert_includes order.errors[:customer_email], "is invalid"
  end

  test "requires total_amount" do
    order = Order.new(valid_attributes.merge(total_amount: nil))
    assert_not order.valid?
    assert_includes order.errors[:total_amount], "is not a number"
  end

  test "total_amount must be greater than or equal to zero" do
    order = Order.new(valid_attributes.merge(total_amount: -10))
    assert_not order.valid?
    assert_includes order.errors[:total_amount], "must be greater than or equal to 0"
  end

  test "status must be valid" do
    order = Order.new(valid_attributes.merge(status: "bogus"))
    assert_not order.valid?
    assert_includes order.errors[:status], "is not included in the list"
  end

  test "status defaults to confirmed" do
    order = Order.new(valid_attributes.except(:status))
    assert_equal "confirmed", order.status
  end

  test "has many tickets" do
    order = Order.create!(valid_attributes)
    Ticket.create!(order: order, ticket_type: @ticket_type, unit_price: 50.00)
    Ticket.create!(order: order, ticket_type: @ticket_type, unit_price: 50.00)

    assert_equal 2, order.tickets.count
  end

  test "destroying order destroys associated tickets" do
    order = Order.create!(valid_attributes)
    Ticket.create!(order: order, ticket_type: @ticket_type, unit_price: 50.00)

    assert_difference "Ticket.count", -1 do
      order.destroy
    end
  end
end
