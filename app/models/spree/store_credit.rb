class Spree::StoreCredit < ActiveRecord::Base
  acts_as_paranoid

  VOID_ACTION       = 'void'
  CREDIT_ACTION     = 'credit'
  CAPTURE_ACTION    = 'capture'
  ELIGIBLE_ACTION   = 'eligible'
  AUTHORIZE_ACTION  = 'authorize'
  ALLOCATION_ACTION = 'allocation'

  belongs_to :user
  belongs_to :category, class_name: "Spree::StoreCreditCategory"
  belongs_to :created_by, class_name: "Spree::User"
  belongs_to :credit_type, class_name: 'Spree::StoreCreditType', :foreign_key => 'type_id'
  has_many :store_credit_events

  validates_presence_of :user, :category, :created_by
  validates_numericality_of :amount, { greater_than: 0 }
  validates_numericality_of :amount_used, { greater_than_or_equal_to: 0 }
  validate :amount_used_less_than_or_equal_to_amount
  validate :amount_authorized_less_than_or_equal_to_amount
  validates_presence_of :credit_type

  delegate :name, to: :category, prefix: true
  delegate :email, to: :created_by, prefix: true

  scope :order_by_priority, -> { includes(:credit_type).order('spree_store_credit_types.priority ASC') }

  before_validation :associate_credit_type
  after_save :store_event

  attr_accessor :action, :authorization_code, :action_amount

  def display_amount
    Spree::Money.new(amount)
  end

  def display_amount_used
    Spree::Money.new(amount_used)
  end

  def amount_remaining
    amount - amount_used - amount_authorized
  end

  def authorize(amount, order_currency, authorization_code = generate_authorization_code)
    # Don't authorize again on capture
    return true if store_credit_events.find_by(action: AUTHORIZE_ACTION, authorization_code: authorization_code)

    if validate_authorization(amount, order_currency)
      self.action, self.authorization_code, self.action_amount = AUTHORIZE_ACTION, authorization_code, amount
      update_attributes!(amount_authorized: self.amount_authorized + amount)
      authorization_code
    else
      errors.add(:base, Spree.t('store_credit_payment_method.insufficient_authorized_amount'))
      false
    end
  end

  def validate_authorization(amount, order_currency)
    if amount_remaining < amount
      errors.add(:base, Spree.t('store_credit_payment_method.insufficient_funds'))
    elsif currency != order_currency
      errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
    end
    return errors.blank?
  end

  def capture(amount, authorization_code, order_currency)
    return false unless authorize(amount, order_currency, authorization_code)

    if amount <= amount_authorized
      if currency != order_currency
        errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
        false
      else
        self.action, self.authorization_code, self.action_amount = CAPTURE_ACTION, authorization_code, amount
        update_attributes!(amount_used: self.amount_used + amount, amount_authorized: self.amount_authorized - amount)
        authorization_code
      end
    else
      errors.add(:base, Spree.t('store_credit_payment_method.insufficient_authorized_amount'))
      false
    end
  end

  def void(authorization_code)
    if auth_event = store_credit_events.find_by(action: AUTHORIZE_ACTION, authorization_code: authorization_code)
      self.action, self.authorization_code, self.action_amount = VOID_ACTION, authorization_code, auth_event.amount
      self.update_attributes!(amount_authorized: amount_authorized - auth_event.amount)
      true
    else
      errors.add(:base, Spree.t('store_credit_payment_method.unable_to_void', auth_code: authorization_code))
      false
    end
  end

  def credit(amount, authorization_code, order_currency)
    # Find the amount related to this authorization_code in order to add the store credit back
    capture_event = store_credit_events.find_by(action: CAPTURE_ACTION, authorization_code: authorization_code)

    if currency != order_currency  # sanity check to make sure the order currency hasn't changed since the auth
      errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
      false
    elsif capture_event && amount <= capture_event.amount
      self.action, self.authorization_code, self.action_amount = CREDIT_ACTION, authorization_code, amount
      self.update_attributes!(amount_used: amount_used - amount)
      true
    else
      errors.add(:base, Spree.t('store_credit_payment_method.unable_to_credit', auth_code: authorization_code))
      false
    end
  end

  def actions
    [CAPTURE_ACTION, VOID_ACTION, CREDIT_ACTION]
  end

  def can_capture?(payment)
    payment.pending? || payment.checkout?
  end

  def can_void?(payment)
    payment.pending?
  end

  def can_credit?(payment)
    return false unless payment.completed?
    return false unless payment.order.payment_state == 'credit_owed'
    payment.credit_allowed > 0
  end

  def generate_authorization_code
    "#{self.id}-SC-#{Time.now.utc.strftime("%Y%m%d%H%M%S%6N")}"
  end

  private

  def store_event
    return unless amount_changed? || amount_used_changed? || amount_authorized_changed? || action == ELIGIBLE_ACTION

    event = if action
      store_credit_events.build(action: action)
    else
      store_credit_events.where(action: ALLOCATION_ACTION).first_or_initialize
    end

    event.update_attributes!(
      amount: action_amount || amount,
      authorization_code: authorization_code || event.authorization_code || generate_authorization_code,
      user_total_amount: user.total_available_store_credit
    )
  end

  def amount_used_less_than_or_equal_to_amount
    return true if amount_used.nil?

    if amount_used > amount
      errors.add(:amount_used, Spree.t('admin.store_credits.errors.amount_used_cannot_be_greater'))
    end
  end

  def amount_authorized_less_than_or_equal_to_amount
    if (amount_used + amount_authorized) > amount
      errors.add(:amount_authorized, Spree.t('admin.store_credits.errors.amount_authorized_exceeds_total_credit'))
    end
  end

  def associate_credit_type
    self.credit_type = Spree::StoreCreditType.find_by_name(Spree::StoreCreditType::DEFAULT_TYPE_NAME) unless self.credit_type
  end

end