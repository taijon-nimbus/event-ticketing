class TicketPurchaseService
  Result = Struct.new(:success?, :order, :error, keyword_init: true)

  def self.call(customer_email:, items:)
    new(customer_email, items).call
  end

  def initialize(customer_email, items)
    @customer_email = customer_email
    @items = items
  end

  def call
    validate_inputs!

    order = nil

    ActiveRecord::Base.transaction do
      ticket_types = lock_ticket_types
      verify_availability!(ticket_types)
      order = create_order(ticket_types)
    end

    Result.new(success?: true, order: order)
  rescue PurchaseError => e
    Result.new(success?: false, order: nil, error: e.message)
  end

  private

  class PurchaseError < StandardError; end

  def validate_inputs!
    raise PurchaseError, "Customer email is required" if @customer_email.blank?
    raise PurchaseError, "Customer email is invalid" unless @customer_email.match?(URI::MailTo::EMAIL_REGEXP)
    raise PurchaseError, "Items cannot be empty" if @items.blank?

    @items.each do |item|
      qty = item[:quantity].to_i
      raise PurchaseError, "Each item quantity must be at least 1" if qty < 1
    end
  end

  def lock_ticket_types
    ids = @items.map { |item| item[:ticket_type_id] }
    locked = TicketType.lock("FOR UPDATE").where(id: ids).index_by(&:id)

    @items.each do |item|
      unless locked[item[:ticket_type_id].to_i]
        raise PurchaseError, "Ticket type #{item[:ticket_type_id]} not found"
      end
    end

    locked
  end

  def verify_availability!(ticket_types)
    sold_counts = Ticket.where(ticket_type_id: ticket_types.keys)
                        .group(:ticket_type_id)
                        .count

    @items.each do |item|
      tt = ticket_types[item[:ticket_type_id].to_i]
      requested = item[:quantity].to_i
      sold = sold_counts[tt.id] || 0
      available = tt.quantity - sold

      if requested > available
        raise PurchaseError, "Not enough #{tt.name} tickets available (requested: #{requested}, available: #{available})"
      end
    end
  end

  def create_order(ticket_types)
    total = @items.sum do |item|
      tt = ticket_types[item[:ticket_type_id].to_i]
      tt.price * item[:quantity].to_i
    end

    order = Order.create!(
      customer_email: @customer_email,
      total_amount: total
    )

    @items.each do |item|
      tt = ticket_types[item[:ticket_type_id].to_i]
      item[:quantity].to_i.times do
        order.tickets.create!(ticket_type: tt, unit_price: tt.price)
      end
    end

    order
  end
end
