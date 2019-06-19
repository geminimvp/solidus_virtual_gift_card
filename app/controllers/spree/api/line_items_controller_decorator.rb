# frozen_string_literal: true

module LineItemsControllerDecorator
  def permitted_line_item_attributes
    super + [
      gift_card_details: [
        :recipient_name, :recipient_email, :gift_message, :purchaser_name,
        :send_email_at
      ]
    ]
  end

  Spree::Api::LineItemsController.prepend(self)
end
