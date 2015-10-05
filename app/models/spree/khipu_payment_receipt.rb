module Spree
  class KhipuPaymentReceipt < ActiveRecord::Base
    belongs_to :payment, foreign_key: 'transaction_id', primary_key: 'identifier'
  end
end