require "test_helper"

class PurchaseFlowIntegrationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @event = Event.create!(
      name: "Integration Test Concert",
      location: "Test Arena",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.hours
    )
  end

  teardown do
    Ticket.delete_all
    Order.delete_all
    TicketType.delete_all
    Event.delete_all
  end

  test "concurrent purchases cannot oversell a single remaining ticket" do
    ticket_type = TicketType.create!(
      event: @event, name: "Last Chance", price: 50.00, quantity: 1
    )

    barrier = Concurrent::CyclicBarrier.new(5)

    threads = 5.times.map do |i|
      Thread.new do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        barrier.wait
        session.post "/api/v1/orders",
          params: {
            customer_email: "racer#{i}@example.com",
            items: [ { ticket_type_id: ticket_type.id, quantity: 1 } ]
          },
          as: :json
        { status: session.response.status, body: JSON.parse(session.response.body) }
      end
    end

    results = threads.map(&:value)
    created = results.select { |r| r[:status] == 201 }
    rejected = results.select { |r| r[:status] == 422 }

    assert_equal 1, created.count, "Exactly 1 request should succeed (HTTP 201)"
    assert_equal 4, rejected.count, "4 requests should be rejected (HTTP 422)"
    assert_equal 1, Ticket.where(ticket_type: ticket_type).count
    assert_equal 1, Order.count
  end

  test "concurrent purchases respect total quantity across multiple buyers" do
    ticket_type = TicketType.create!(
      event: @event, name: "Limited VIP", price: 100.00, quantity: 5
    )

    barrier = Concurrent::CyclicBarrier.new(5)

    threads = 5.times.map do |i|
      Thread.new do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        barrier.wait
        session.post "/api/v1/orders",
          params: {
            customer_email: "vip#{i}@example.com",
            items: [ { ticket_type_id: ticket_type.id, quantity: 3 } ]
          },
          as: :json
        { status: session.response.status, body: JSON.parse(session.response.body) }
      end
    end

    results = threads.map(&:value)
    created = results.select { |r| r[:status] == 201 }
    sold = Ticket.where(ticket_type: ticket_type).count

    assert_operator sold, :<=, 5, "Total sold must not exceed quantity of 5"
    assert_equal 1, created.count, "Only 1 buyer can get 3 of 5 tickets"
  end

  test "full purchase flow: browse, buy, and verify from API" do
    ga = TicketType.create!(event: @event, name: "GA", price: 40.00, quantity: 100)
    vip = TicketType.create!(event: @event, name: "VIP", price: 120.00, quantity: 10)

    get "/api/v1/events"
    assert_response :success
    events = JSON.parse(response.body)
    event_data = events.find { |e| e["name"] == "Integration Test Concert" }
    assert_not_nil event_data
    assert_equal 2, event_data["ticket_types"].length

    get "/api/v1/events/#{@event.id}"
    assert_response :success
    detail = JSON.parse(response.body)
    assert_equal "Integration Test Concert", detail["name"]

    post "/api/v1/orders",
      params: {
        customer_email: "fan@example.com",
        items: [
          { ticket_type_id: ga.id, quantity: 2 },
          { ticket_type_id: vip.id, quantity: 1 }
        ]
      },
      as: :json

    assert_response :created
    order = JSON.parse(response.body)
    assert_equal "fan@example.com", order["customer_email"]
    assert_equal "200.0", order["total_amount"]
    assert_equal 3, order["tickets"].length
    assert_equal "confirmed", order["status"]
  end

  test "price is locked at purchase time across the full stack" do
    ticket_type = TicketType.create!(
      event: @event, name: "Flexible Price", price: 50.00, quantity: 10
    )

    post "/api/v1/orders",
      params: {
        customer_email: "early@example.com",
        items: [ { ticket_type_id: ticket_type.id, quantity: 1 } ]
      },
      as: :json

    assert_response :created
    early_order = JSON.parse(response.body)
    assert_equal "50.0", early_order["tickets"][0]["unit_price"]

    ticket_type.update!(price: 80.00)

    post "/api/v1/orders",
      params: {
        customer_email: "late@example.com",
        items: [ { ticket_type_id: ticket_type.id, quantity: 1 } ]
      },
      as: :json

    assert_response :created
    late_order = JSON.parse(response.body)
    assert_equal "80.0", late_order["tickets"][0]["unit_price"]

    early_ticket = Ticket.find(early_order["tickets"][0]["id"])
    assert_equal BigDecimal("50.0"), early_ticket.unit_price
  end
end
