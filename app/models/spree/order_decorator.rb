module Spree
    Order.class_eval do
        # Add khipu state after  payment
        insert_checkout_step Spree::Gateway::KhipuGateway::STATE.to_sym, :after => :payment, if: Proc.new {|order| order.has_khipu_payment_method? }
        remove_transition from: :payment, to: :complete,  if: Proc.new {|order| order.has_khipu_payment_method? || order.state == Spree::Gateway::KhipuGateway::STATE}

        def has_khipu_payment_method?
          payments.valid.from_khipu.any?
        end

        def khipu_state?
          state.eql? Spree::Gateway::KhipuGateway::STATE
        end

    end
end