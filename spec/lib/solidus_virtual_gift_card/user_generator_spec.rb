require 'spec_helper'

module SolidusVirtualGiftCard
  RSpec.describe UserGenerator, type: :model do
    let(:generator) { described_class.new(order) }
    let!(:order) { create(:completed_order_with_totals) }

    describe '#user' do
      subject { generator.user }

      context 'when a user exists' do
        let(:user) { order.user }

        it 'does not create a new user' do
          expect { subject }.to_not change { Spree.user_class.count }
        end

        it 'returns the existing user' do
          expect(subject).to eq(user)
        end
      end

      context 'when no user already exists' do
        before do
          user = order.user
          order.update_attributes(user_id: nil)
          user.destroy
        end

        it 'creates a new user and returns it' do
          expect { subject }.to change { Spree.user_class.count }.by(1)
        end

      end
    end
  end
end
