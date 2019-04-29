# frozen_string_literal: true

module Spree
  class GiftCardMailer < Spree::BaseMailer
    def gift_card_email(gift_card)
      @gift_card = gift_card.respond_to?(:id) ? gift_card : Spree::VirtualGiftCard.find(gift_card)
      @order = @gift_card.line_item.order
      send_to_address = @gift_card.recipient_email.presence || @order.email
      subject = "#{Spree::Store.default.name} #{I18n.t(:'spree.gift_card_mailer.gift_card_email.subject')}"
      mail(to: send_to_address, from: from_address(Spree::Store.default), subject: subject)
    end
  end
end
