module Spree
  require 'net/http'
  require 'net/https'
  require 'json'
  require 'khipu'

  class KhipuController < StoreController
    ssl_allowed
    protect_from_forgery except: [:notify]

    def pay
      order = current_order || raise(ActiveRecord::RecordNotFound)
      Rails.logger.info "#{__FILE__}:#{__LINE__} Khipu Pay Order: #{order.number}"
      @payment = order.payments.order(:id).last

      begin
        Rails.logger.info "#{__FILE__}:#{__LINE__} Create Payment: #{payment_args(@payment)}"
        payment_params = payment_args(@payment)
        @payment.create_khipu_payment_receipt khipu_payment_receipt_permit(payment_params)
        map = provider.create_payment_url(payment_params)
        khipu_payment_url = payment_method.modify_url_by_payment_type(map['url'])

        Rails.logger.info "#{__FILE__}:#{__LINE__} Khipu Pay OK! Order: #{order.number}"
        redirect_to khipu_payment_url

      rescue Khipu::ApiError => error
        flash[:error] = 'Hubo un problema con Khipu, intente nuevamente más tarde.'
        Rails.logger.error "#{__FILE__}:#{__LINE__} Khipu Pay ERROR! Order: #{order.number}"
        Rails.logger.error error.type
        Rails.logger.error error.message
        redirect_to checkout_state_path(:payment) and return
      end
    end

    def success
      @payment = Spree::Payment.where(identifier: params[:payment]).last || raise(ActiveRecord::RecordNotFound)
      @order = @payment.order
      @khipu_receipt = @payment.khipu_payment_receipt
      Rails.logger.info "#{__FILE__}:#{__LINE__} Khipu Success Order: #{@order.number}"

      # To clean the Cart
      session[:order_id] = nil
      @current_order     = nil

      redirect_to root_path and return if @payment.blank?
      redirect_to khipu_cancel_path(params) and return  if @payment.failed?

      flash.notice = Spree.t(:order_processed_successfully)
      flash[:commerce_tracking] = "nothing special" # asume a complete payment for analytics and others callbacks in view

      redirect_to completion_route(@order)
    end

    def cancel
      Rails.logger.info "#{__FILE__}:#{__LINE__} Cancel Khipu Payment: #{params}"
      @payment = Spree::Payment.where(identifier: params[:payment]).last
      @khipu_receipt = @payment.khipu_payment_receipt

      redirect_to checkout_state_path(:payment) and return
    end

    def notify
     Rails.logger.info "#{__FILE__}:#{__LINE__} Notifying Khipu Payment: #{params}"
      begin
        payment_notification = provider.get_payment_notification(params)

        # Aceptar el pago
        @payment = Spree::Payment.where(identifier: payment_notification["transaction_id"]).last
        @order = @payment.order

        render  nothing: true, status: :ok and return if (@order.payment_state == 'paid' || @order.completed?)

        @khipu_receipt = @payment.khipu_payment_receipt
        @khipu_receipt.update(payment_notification.select{ |k,v| @khipu_receipt.attributes.keys.include? k })
        @khipu_receipt.save!

        unless payment_amount_valid?(@payment, payment_notification)
          Rails.logger.info "Fail payment #{@payment.id} notification validation: #{payment_notification} - #{@payment.amount}"
          render  nothing: true, status: :internal_server_error
          return
        end

        Rails.logger.info "#{__FILE__}:#{__LINE__} Receipt id: #{@khipu_receipt.id}"
        Rails.logger.info payment_notification
        @payment.capture!
        Rails.logger.info "#{__FILE__}:#{__LINE__} Payment: #{@payment.id} for order #{@order.number} captured!"
        @order.next!
        Rails.logger.info "#{__FILE__}:#{__LINE__} Order state #{@order.state}!"

        render  nothing: true, status: :ok

      rescue Khipu::ApiError => error
        Rails.logger.error "#{__FILE__}:#{__LINE__} Khipu Notify Error -  Payment: #{@payment.id} and Order: #{@payment.order.number}"
        Rails.logger.error error.type
        Rails.logger.error error.message
        render  nothing: true, status: :internal_server_error
      end
    end

    private

    def payment_args(payment)
      notify_url, return_url, cancel_url = get_urls(payment)
      {
        receiver_id:    payment_method.preferences[:commerce_id],
        subject:        subject,
        body:           "",
        amount:         payment.amount.to_i,
        payer_email:    payment.order.email,
        bank_id:        "",
        expires_date:   "",
        transaction_id: payment.identifier,
        custom:         "",
        notify_url:     notify_url,
        return_url:    return_url,
        cancel_url:   cancel_url,
        picture_url:    ""
      }
    end

    # Return URL in [notify_url, success_url, cancel_url] format
    def get_urls payment
      if KhipuConfig::PROTOCOL
        [ KhipuConfig::DOMAIN_URL ? "#{KhipuConfig::DOMAIN_URL}#{khipu_notify_path}" : khipu_notify_url(protocol: KhipuConfig::PROTOCOL), khipu_success_url(payment.identifier, protocol: KhipuConfig::PROTOCOL), khipu_cancel_url(payment.identifier, protocol: KhipuConfig::PROTOCOL) ]
      else # without custom config
        [KhipuConfig::DOMAIN_URL ? "#{KhipuConfig::DOMAIN_URL}#{khipu_notify_path}" : khipu_notify_url, khipu_success_url(payment.identifier), khipu_cancel_url(payment.identifier)]
      end
    end

    def add_hash(args)
      args[:hash] = calculate_hash(args)
      args
    end

    def validate_payment(payment_args)
      begin
        params = {
          api_version: payment_args[:api_version],
          notification_id: payment_args[:notification_id],
          subject: payment_args[:subject],
          amount: payment_args[:amount],
          currency: payment_args[:currency],
          transaction_id: payment_args[:transaction_id],
          payer_email: payment_args[:payer_email],
          custom: payment_args[:custom],
          notification_signature: payment_args[:notification_signature]
        }
        valid = provider.verify_payment_notification(params)
      rescue Khipu::ApiError => error
        puts error.type
        puts error.message
      end
    end

    def payment_method
      params[:payment_method_id] ? (Spree::PaymentMethod.find(params[:payment_method_id]) || Spree::Payment.where(identifier: khipu_params[:transaction_id]).last.payment_method) : Spree::PaymentMethod.where(type: "Spree::Gateway::KhipuGateway").last
    end

    def provider
      payment_method.provider
    end

    def khipu_params
        params.permit(:api_version, :receiver_id, :subject, :amount, :custom, :currency, :transaction_id, :notification_id, :payer_email)
    end

    def completion_route(order, custom_params = nil)
      spree.order_path(order, custom_params)
    end

    # Check if payment notification is OK,  if payment amount is over zero
    def payment_amount_valid? payment, payment_notification
      payment && payment.amount >0  && payment_notification["amount"].to_f == payment.order.total.to_f
    end

    def subject
      current_store ? payment_method.preferences[:subject].gsub("%current_store%", current_store.name) : payment_method.preferences[:subject]
    end

    def khipu_payment_receipt_permit payment_params
      payment_params.select{|k,v| [:receiver_id, :subject, :amount, :transaction_id, :payer_email].include? k}
    end

  end
end
