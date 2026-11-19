# lib/rescue/escape_hatch.rb — the same four rescue classes as data_normalizer.rb,
# order_normalizer.rb and suites.rb, but with an ESCAPE HATCH in the schema so a
# failed rescue has somewhere to go instead of an invented value:
#   data / order / amounts — the fields that can be missing are `optional` (null)
#   events                 — `kind` gains an "unknown" value
# plus one purpose line telling the model to use it rather than guess.
# No source is appended (the better baseline in the earlier runs).
require "squishling"

module Rescue
  module Escape
    NOGUESS = " If the input does not contain a value, leave it null (or use \"unknown\") — never guess or invent one."

    class DataNormalizer
      include Squishling
      purpose "Return the record's data field as a string." + NOGUESS
      output_schema do
        optional(:data, description: "The data string, or null if the input contains none.") { string }
      end

      def call(payload)
        result(data: payload.fetch(:data).to_s.strip)
      rescue => e
        squish!(context: { error: e })
      end
    end

    class OrderNormalizer
      include Squishling
      purpose "Normalize an inbound order payload into our order summary." + NOGUESS
      output_schema do
        string :order_id
        optional(:customer_email, description: "The customer's email address, lower-cased.") { string }
        optional(:total_dollars, description: "Order total in US dollars: the sum of quantity x unit price over all items. Null if prices are not in the input.") { number }
        optional(:item_count, description: "Total number of units: the sum of item quantities.") { integer }
        optional(:placed_on, description: "The UTC calendar date the order was placed, formatted YYYY-MM-DD.") { string }
        string :status, enum: %w[paid pending refunded failed]
      end

      def call(payload)
        order = payload.fetch(:order)
        items = order.fetch(:items)
        placed_at = order.fetch(:placed_at)
        raise ArgumentError, "placed_at is not epoch seconds" unless (946_684_800..4_102_444_800).cover?(placed_at)

        result(order_id: order.fetch(:id), customer_email: order.fetch(:customer).fetch(:email).downcase,
               total_dollars: items.sum { |i| i.fetch(:qty) * i.fetch(:unit_price_cents) } / 100.0,
               item_count: items.sum { |i| i.fetch(:qty) },
               placed_on: Time.at(placed_at).utc.strftime("%Y-%m-%d"), status: order.fetch(:status))
      rescue => e
        squish!(context: { error: e })
      end
    end

    class EventRouter
      include Squishling
      purpose "Normalize an inbound webhook event into our internal event record." + NOGUESS
      output_schema do
        string :event_id
        string :kind, enum: %w[payment_succeeded payment_failed subscription_canceled refund_issued unknown]
        string :invoice_id
        integer :amount_cents, description: "Amount in minor units (cents), as an integer."
        string :currency, description: "Three-letter ISO 4217 code, upper-case."
        string :customer_email, description: "The customer's email address, lower-cased."
      end

      TYPE_MAP = { "invoice.paid" => "payment_succeeded", "invoice.payment_failed" => "payment_failed",
                   "customer.subscription.deleted" => "subscription_canceled", "charge.refunded" => "refund_issued" }.freeze

      def call(event)
        object = event.fetch(:data).fetch(:object)
        result(event_id: event.fetch(:id), kind: TYPE_MAP.fetch(event.fetch(:type)), invoice_id: object.fetch(:id),
               amount_cents: object.fetch(:amount_paid), currency: object.fetch(:currency).upcase,
               customer_email: object.fetch(:customer_email).downcase)
      rescue => e
        squish!(context: { error: e })
      end
    end

    class AmountParser
      include Squishling
      purpose "Parse a money string from a customer-supplied field into an integer amount and its currency." + NOGUESS
      output_schema do
        optional(:minor_units, description: "The amount in minor units of its currency (cents for USD/EUR/CAD; whole yen for JPY). Negative for credits. Null if the input contains no amount.") { integer }
        optional(:currency, description: "Three-letter ISO 4217 code, upper-case.") { string }
      end

      def call(raw)
        result(minor_units: (Float(raw) * 100).round, currency: "USD")
      rescue => e
        squish!(context: { error: e })
      end
    end
  end
end
