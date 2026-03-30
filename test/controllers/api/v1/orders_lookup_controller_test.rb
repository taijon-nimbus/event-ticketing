require "test_helper"

class Api::V1::OrdersLookupControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = Event.create!(
      name: "Rails Conf 2026",
      location: "Portland, OR",
      start_time: 2.weeks.from_now,
      end_time: 2.weeks.from_now + 3.days
    )

    @ga = TicketType.create!(
      event: @event, name: "General Admission", price: 50.00, quantity: 100
    )

    @vip = TicketType.create!(
      event: @event, name: "VIP", price: 150.00, quantity: 20
    )

    @alice_order = TicketPurchaseService.call(
      customer_email: "alice@example.com",
      items: [
        { ticket_type_id: @ga.id, quantity: 2 },
        { ticket_type_id: @vip.id, quantity: 1 }
      ]
    ).order

    @bob_order = TicketPurchaseService.call(
      customer_email: "bob@example.com",
      items: [{ ticket_type_id: @ga.id, quantity: 1 }]
    ).order
  end

  test "GET /api/v1/orders?email= returns orders for the given email" do
    get api_v1_orders_url, params: { email: "alice@example.com" }
    assert_response :success

    orders = JSON.parse(response.body)
    assert_equal 1, orders.length
    assert_equal "alice@example.com", orders[0]["customer_email"]
  end

  test "returned orders include ticket details" do
    get api_v1_orders_url, params: { email: "alice@example.com" }
    order = JSON.parse(response.body).first

    assert_equal 3, order["tickets"].length
    assert_equal "250.0", order["total_amount"]

    ticket_names = order["tickets"].map { |t| t["ticket_type_name"] }
    assert_includes ticket_names, "General Admission"
    assert_includes ticket_names, "VIP"
  end

  test "returned tickets include event name" do
    get api_v1_orders_url, params: { email: "alice@example.com" }
    order = JSON.parse(response.body).first
    ticket = order["tickets"].first

    assert_equal "Rails Conf 2026", ticket["event_name"]
  end

  test "does not return other customers' orders" do
    get api_v1_orders_url, params: { email: "alice@example.com" }
    orders = JSON.parse(response.body)

    order_ids = orders.map { |o| o["id"] }
    assert_includes order_ids, @alice_order.id
    assert_not_includes order_ids, @bob_order.id
  end

  test "returns empty array when no orders found for email" do
    get api_v1_orders_url, params: { email: "nobody@example.com" }
    assert_response :success

    orders = JSON.parse(response.body)
    assert_equal [], orders
  end

  test "returns 400 when email param is missing" do
    get api_v1_orders_url
    assert_response :bad_request

    body = JSON.parse(response.body)
    assert_equal "Email parameter is required", body["error"]
  end

  test "orders are returned most recent first" do
    second_order = TicketPurchaseService.call(
      customer_email: "alice@example.com",
      items: [{ ticket_type_id: @ga.id, quantity: 1 }]
    ).order

    get api_v1_orders_url, params: { email: "alice@example.com" }
    orders = JSON.parse(response.body)

    assert_equal 2, orders.length
    assert_equal second_order.id, orders[0]["id"]
    assert_equal @alice_order.id, orders[1]["id"]
  end
end
