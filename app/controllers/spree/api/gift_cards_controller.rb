# frozen_string_literal: true

module Spree
  module Api
    class GiftCardsController < Spree::Api::BaseController
      skip_before_action :load_user, only: [:show, :update, :redeem]
      skip_before_action :authenticate_user, only: [:show, :update, :redeem]

      before_action :load_gift_card, only: [:show, :update]

      def update
        if @gift_card.update_attributes(gift_card_params)
          respond_with(@gift_card, status: 201, default_template: :show)
        else
          invalid_resource!(@gift_card)
        end
      end

      def redeem
        redemption_code = Spree::RedemptionCodeGenerator.format_redemption_code_for_lookup(params[:redemption_code] || "")
        @gift_card = Spree::VirtualGiftCard.active_by_redemption_code(redemption_code)

        if !@gift_card
          render status: :not_found, json: { error_message: I18n.t(:'spree.admin.gift_cards.errors.not_found') }
        elsif @gift_card.redeem(@current_api_user)
          render status: :created, json: {}
        else
          render status: 422, json: { error_message: I18n.t(:'spree.admin.gift_cards.errors.not_found') }
        end
      end

      private

      def gift_card_params
        params.require(:gift_card).permit(:purchaser_id, :redeemer_id,
          :store_credit_id, :amount, :redemption_code, :line_item_id,
          :recipient_name, :recipient_email, :gift_message, :purchaser_name,
          :redeemable, :inventory_unit_id)
      end

      def load_gift_card
        @gift_card ||= Spree::VirtualGiftCard.find_by(id: params[:id])
      end
    end
  end
end
