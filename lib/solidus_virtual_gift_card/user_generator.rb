require 'securerandom'

module SolidusVirtualGiftCard

  # For some operations (e.g. creating a subscription, purchasing /
  # redeeming a gift card) a Spree::User is required in order to
  # tie it to the record being created. We need to generate a User
  # record based on what's already on the order in some of those
  # cases, so this class holds the logic for doing so.
  #
  # TODO: use this class to replace SolidusSubscriptions::UserGenerator
  class UserGenerator
    attr_reader :order

    def initialize(order)
      @order = order
    end

    def user
      existing_user || create_stub_user
    end

    def existing_user
      base = Spree.user_class.where("LOWER(email)=?", order.email.downcase)
      if Spree.user_class.new.respond_to?(:team)
        base = base.where(team_id: order.team.id)
      else
        base
      end

      base.first
    end

    def create_stub_user
      initial_password = friendly_token
      user_attrs = {
        email: order.email,
        password: initial_password,
      }
      if Spree.user_class.new.respond_to?(:team)
        user_attrs[:team] = order.team
      end
      Spree.user_class.create!(user_attrs)
    end

    def friendly_token(length = 20)
      SecureRandom.base64(length).tr('+/=', '-_').strip.delete("\n")
    end

  end
end
