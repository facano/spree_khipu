module Spree
    Payment.class_eval do
        scope :from_khipu, -> { joins(:payment_method).where(spree_payment_methods: {type: Spree::Gateway::KhipuGateway.to_s}) }
    end
end