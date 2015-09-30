module Spree
    Payment.class_eval do
        scope :from_khipu, -> { joins(:payment_method).where(spree_payment_methods: {type: Spree::Gateway::KhipuGateway.to_s}) }

        def khipu_payment_method?
          payment_method && payment_method.type == Spree::Gateway::KhipuGateway.to_s
        end

    end
end