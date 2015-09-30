module Spree
    CheckoutController.class_eval do
        before_filter :check_khipu, only: :edit

        private
        def check_khipu
            redirect_to khipu_path(params) and return if  params[:state] == Spree::Gateway::KhipuGateway::STATE && @order.state == Spree::Gateway::KhipuGateway::STATE
        end
    end
end