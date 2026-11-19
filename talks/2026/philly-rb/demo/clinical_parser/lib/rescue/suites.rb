# lib/rescue/suites.rb — two more "Ruby raised, squish! rescues it" suites, each as
# a pair of classes that differ ONLY in whether the method's own source is in the
# prompt (with_source / no_source). The Ruby is written out literally in each
# class (not class_eval'd) because `append_to_purpose ..., self` reads the class's
# source from the file. See bin/run_rescue_suite.
#
#   events  — webhook event router: enum mapping, versioned/renamed event types,
#             envelope changes. (vocabulary + envelope drift)
#   amounts — money-string parser: locale formats, accounting negatives, words,
#             and a currency whose minor-unit exponent isn't 2. (VALUE drift)
require "squishling"

module Rescue
  module Suites
    # ---------------------------------------------------------------- events
    EVENT_SCHEMA = proc do
      string :event_id
      string :kind, enum: %w[payment_succeeded payment_failed subscription_canceled refund_issued]
      string :invoice_id
      integer :amount_cents, description: "Amount in minor units (cents), as an integer."
      string :currency, description: "Three-letter ISO 4217 code, upper-case."
      string :customer_email, description: "The customer's email address, lower-cased."
    end

    class EventRouter
      include Squishling
      purpose "Normalize an inbound webhook event into our internal event record."
      append_to_purpose "The Ruby that handles the event shape this vendor used to send, for context on the intent:", self
      output_schema(&EVENT_SCHEMA)

      TYPE_MAP = {
        "invoice.paid" => "payment_succeeded",
        "invoice.payment_failed" => "payment_failed",
        "customer.subscription.deleted" => "subscription_canceled",
        "charge.refunded" => "refund_issued"
      }.freeze

      def call(event)
        object = event.fetch(:data).fetch(:object)
        result(
          event_id: event.fetch(:id),
          kind: TYPE_MAP.fetch(event.fetch(:type)),
          invoice_id: object.fetch(:id),
          amount_cents: object.fetch(:amount_paid),
          currency: object.fetch(:currency).upcase,
          customer_email: object.fetch(:customer_email).downcase
        )
      rescue => e
        squish!(context: { error: e })
      end
    end

    class EventRouterNoSource
      include Squishling
      purpose "Normalize an inbound webhook event into our internal event record."
      output_schema(&EVENT_SCHEMA)

      TYPE_MAP = {
        "invoice.paid" => "payment_succeeded",
        "invoice.payment_failed" => "payment_failed",
        "customer.subscription.deleted" => "subscription_canceled",
        "charge.refunded" => "refund_issued"
      }.freeze

      def call(event)
        object = event.fetch(:data).fetch(:object)
        result(
          event_id: event.fetch(:id),
          kind: TYPE_MAP.fetch(event.fetch(:type)),
          invoice_id: object.fetch(:id),
          amount_cents: object.fetch(:amount_paid),
          currency: object.fetch(:currency).upcase,
          customer_email: object.fetch(:customer_email).downcase
        )
      rescue => e
        squish!(context: { error: e })
      end
    end

    # --------------------------------------------------------------- amounts
    AMOUNT_SCHEMA = proc do
      integer :minor_units, description: "The amount in minor units of its currency (cents for USD/EUR/CAD; whole yen for JPY). Negative for credits."
      string :currency, description: "Three-letter ISO 4217 code, upper-case."
    end

    class AmountParser
      include Squishling
      purpose "Parse a money string from a customer-supplied field into an integer amount and its currency."
      append_to_purpose "The Ruby that handles the amount format this field used to contain, for context on the intent:", self
      output_schema(&AMOUNT_SCHEMA)

      def call(raw)
        result(minor_units: (Float(raw) * 100).round, currency: "USD")
      rescue => e
        squish!(context: { error: e })
      end
    end

    class AmountParserNoSource
      include Squishling
      purpose "Parse a money string from a customer-supplied field into an integer amount and its currency."
      output_schema(&AMOUNT_SCHEMA)

      def call(raw)
        result(minor_units: (Float(raw) * 100).round, currency: "USD")
      rescue => e
        squish!(context: { error: e })
      end
    end
  end
end
