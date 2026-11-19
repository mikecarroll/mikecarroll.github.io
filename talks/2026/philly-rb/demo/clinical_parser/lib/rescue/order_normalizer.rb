# lib/rescue/order_normalizer.rb — a harder "the upstream shape changed" rescue test.
#
# The Ruby below is written for ONE inbound order shape (see bin/run_rescue_order
# for the original payload): nested keys, price in integer CENTS, placed_at as
# epoch SECONDS, and logic along the way (downcase the email, sum quantities,
# convert cents to dollars, format a UTC date). When the vendor changes the
# payload, this raises and `squish!` hands the call to the LLM.
#
# The schema carries every unit/format rule in `description:` (squishling's
# documented best practice), identically for both classes, so the only
# difference between them is whether the method's own source is in the prompt:
#   OrderNormalizer          — append_to_purpose "...", self
#   OrderNormalizerNoSource  — no source appended
require "squishling"

module Rescue
  ORDER_SCHEMA = proc do
    string :order_id
    string :customer_email, description: "The customer's email address, lower-cased."
    number :total_dollars, description: "Order total in US dollars: the sum of quantity x unit price over all items."
    integer :item_count, description: "Total number of units: the sum of item quantities."
    string :placed_on, description: "The UTC calendar date the order was placed, formatted YYYY-MM-DD."
    string :status, enum: %w[paid pending refunded failed]
  end

  class OrderNormalizer
    include Squishling

    purpose "Normalize an inbound order payload into our order summary."
    append_to_purpose "The Ruby that handles the payload shape this vendor used to send, for context on the intent:", self
    output_schema(&ORDER_SCHEMA)

    def call(payload)
      order = payload.fetch(:order)
      items = order.fetch(:items)
      placed_at = order.fetch(:placed_at)
      raise ArgumentError, "placed_at is not epoch seconds" unless (946_684_800..4_102_444_800).cover?(placed_at)

      result(
        order_id: order.fetch(:id),
        customer_email: order.fetch(:customer).fetch(:email).downcase,
        total_dollars: items.sum { |i| i.fetch(:qty) * i.fetch(:unit_price_cents) } / 100.0,
        item_count: items.sum { |i| i.fetch(:qty) },
        placed_on: Time.at(placed_at).utc.strftime("%Y-%m-%d"),
        status: order.fetch(:status)
      )
    rescue => e
      squish!(context: { error: e })
    end
  end

  class OrderNormalizerNoSource
    include Squishling

    purpose "Normalize an inbound order payload into our order summary."
    output_schema(&ORDER_SCHEMA)

    def call(payload)
      order = payload.fetch(:order)
      items = order.fetch(:items)
      placed_at = order.fetch(:placed_at)
      raise ArgumentError, "placed_at is not epoch seconds" unless (946_684_800..4_102_444_800).cover?(placed_at)

      result(
        order_id: order.fetch(:id),
        customer_email: order.fetch(:customer).fetch(:email).downcase,
        total_dollars: items.sum { |i| i.fetch(:qty) * i.fetch(:unit_price_cents) } / 100.0,
        item_count: items.sum { |i| i.fetch(:qty) },
        placed_on: Time.at(placed_at).utc.strftime("%Y-%m-%d"),
        status: order.fetch(:status)
      )
    rescue => e
      squish!(context: { error: e })
    end
  end
end
