module Spree
    Payment.class_eval do
        scope :from_khipu, -> { joins(:payment_method).where(spree_payment_methods: {type: Spree::Gateway::KhipuGateway.to_s}) }
        has_one :khipu_payment_receipt, foreign_key: 'transaction_id', primary_key: 'identifier'

        def khipu_payment_method?
          payment_method && payment_method.type == Spree::Gateway::KhipuGateway.to_s
        end

    end
end