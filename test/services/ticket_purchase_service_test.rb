require "test_helper"

class TicketPurchaseServiceTest < ActiveSupport::TestCase
  setup do
    @event = Event.create!(
      name: "Rails Conf 2026",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days
    )

    @ga = TicketType.create!(
      event: @event, name: "General Admission", price: 50.00, quantity: 10
    )

    @vip = TicketType.create!(
      event: @event, name: "VIP", price: 150.00, quantity: 2
    )
  end

  # === HAPPY PATH ===

  test "successfully purchases a single ticket type" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [ { ticket_type_id: @ga.id, quantity: 2 } ]
    )

    assert result.success?
    order = result.order

    assert_equal "fan@example.com", order.customer_email
    assert_equal "confirmed", order.status
    assert_equal 100.00, order.total_amount
    assert_equal 2, order.tickets.count
    assert order.tickets.all? { |t| t.unit_price == 50.00 }
  end

  test "successfully purchases multiple ticket types" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [
        { ticket_type_id: @ga.id, quantity: 2 },
        { ticket_type_id: @vip.id, quantity: 1 }
      ]
    )

    assert result.success?
    order = result.order

    assert_equal 250.00, order.total_amount
    assert_equal 3, order.tickets.count
  end

  # === PRICE LOCKING ===

  test "captures price at time of purchase, not current price" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [ { ticket_type_id: @ga.id, quantity: 1 } ]
    )

    assert result.success?
    original_ticket = result.order.tickets.first
    assert_equal 50.00, original_ticket.unit_price

    @ga.update!(price: 75.00)

    result2 = TicketPurchaseService.call(
      customer_email: "other@example.com",
      items: [ { ticket_type_id: @ga.id, quantity: 1 } ]
    )

    assert result2.success?
    new_ticket = result2.order.tickets.first
    assert_equal 75.00, new_ticket.unit_price

    original_ticket.reload
    assert_equal 50.00, original_ticket.unit_price
  end

  # === SOLD OUT ===

  test "fails when not enough tickets available" do
    TicketPurchaseService.call(
      customer_email: "first@example.com",
      items: [ { ticket_type_id: @vip.id, quantity: 2 } ]
    )

    result = TicketPurchaseService.call(
      customer_email: "second@example.com",
      items: [ { ticket_type_id: @vip.id, quantity: 1 } ]
    )

    assert_not result.success?
    assert_match(/VIP/i, result.error)
    assert_nil result.order
  end

  test "fails entire order if any item is unavailable (atomic)" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [
        { ticket_type_id: @ga.id, quantity: 2 },
        { ticket_type_id: @vip.id, quantity: 5 }
      ]
    )

    assert_not result.success?
    assert_equal 0, Order.count, "No order should be created on failure"
    assert_equal 0, Ticket.count, "No tickets should be created on failure"
  end

  # === VALIDATION ERRORS ===

  test "fails with invalid email" do
    result = TicketPurchaseService.call(
      customer_email: "",
      items: [ { ticket_type_id: @ga.id, quantity: 1 } ]
    )

    assert_not result.success?
    assert_match(/email/i, result.error)
  end

  test "fails with empty items" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: []
    )

    assert_not result.success?
    assert_match(/items/i, result.error)
  end

  test "fails with zero quantity" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [ { ticket_type_id: @ga.id, quantity: 0 } ]
    )

    assert_not result.success?
    assert_match(/quantity/i, result.error)
  end

  test "fails with nonexistent ticket type" do
    result = TicketPurchaseService.call(
      customer_email: "fan@example.com",
      items: [ { ticket_type_id: 999999, quantity: 1 } ]
    )

    assert_not result.success?
  end

  # === CONCURRENCY (the tricky part) ===
  # Uses self.use_transactional_tests = false so each thread gets its own
  # real DB connection/transaction — otherwise Rails' test transaction wrapper
  # serializes everything and the test wouldn't actually prove anything.

  class ConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @event = Event.create!(
        name: "Concurrency Conf",
        location: "Portland, OR",
        start_time: 2.weeks.from_now,
        end_time: 2.weeks.from_now + 3.days
      )
    end

    teardown do
      Ticket.delete_all
      Order.delete_all
      TicketType.delete_all
      Event.delete_all
    end

    test "prevents overselling under concurrent purchases" do
      ticket_type = TicketType.create!(
        event: @event, name: "Limited", price: 25.00, quantity: 1
      )

      barrier = Concurrent::CyclicBarrier.new(5)

      threads = 5.times.map do |i|
        Thread.new do
          barrier.wait
          TicketPurchaseService.call(
            customer_email: "buyer#{i}@example.com",
            items: [ { ticket_type_id: ticket_type.id, quantity: 1 } ]
          )
        end
      end

      results = threads.map(&:value)
      successes = results.select(&:success?)
      failures = results.reject(&:success?)

      assert_equal 1, successes.count, "Exactly one purchase should succeed"
      assert_equal 4, failures.count, "Four purchases should fail"

      sold = Ticket.where(ticket_type: ticket_type).count
      assert_equal 1, sold, "Only 1 ticket should exist in the database"
    end

    test "prevents overselling when multiple tickets are requested" do
      ticket_type = TicketType.create!(
        event: @event, name: "Scarce", price: 30.00, quantity: 5
      )

      barrier = Concurrent::CyclicBarrier.new(3)

      threads = 3.times.map do |i|
        Thread.new do
          barrier.wait
          TicketPurchaseService.call(
            customer_email: "buyer#{i}@example.com",
            items: [ { ticket_type_id: ticket_type.id, quantity: 3 } ]
          )
        end
      end

      results = threads.map(&:value)
      successes = results.select(&:success?)

      sold = Ticket.where(ticket_type: ticket_type).count
      assert_operator sold, :<=, 5, "Should never exceed ticket quantity"
      assert_equal 1, successes.count, "Only one buyer can get 3 of 5 tickets"
    end
  end
end
