# frozen_string_literal: true

require 'spec_helper'

describe Spree::Api::GiftCardsController, type: :request do
  let!(:credit_type) { create(:secondary_credit_type, name: "Non-expiring") }
  let!(:gc_category) { create(:store_credit_gift_card_category) }
  let(:params) { { redemption_code: gift_card.redemption_code, format: :json } }

  describe "POST redeem" do
    let(:gift_card) { create(:redeemable_virtual_gift_card) }

    subject do
      post spree.redeem_api_gift_cards_path, params: params
      response
    end

    context "the user is not logged in" do
      before { subject }

      it "returns a 401" do
        expect(response.status).to eq 401
      end
    end

    context "the current api user is authenticated" do
      let(:current_api_user) { create(:user, :with_api_key) }
      let(:api_key) { current_api_user.spree_api_key }
      let(:parsed_response) { HashWithIndifferentAccess.new(JSON.parse(response.body)) }

      before do
        stub_authentication!
      end

      # before do
      #   allow(controller).to receive(:load_user)
      #   controller.instance_variable_set(:@current_api_user, api_user)
      # end

      context "given an invalid gift card redemption code" do
        let(:params) { { redemption_code: 'INVALID_CODE', format: :json } }

        before { subject }

        it 'does not find the gift card' do
          expect(assigns(:gift_card)).to eq nil
        end

        it 'contains an error message' do
          expect(parsed_response['error_message']).to be_present
        end

        it "returns a 404" do
          expect(subject.status).to eq 404
        end
      end

      context "there is no redemption code in the request body" do
        let(:params) { {} }

        it "returns a 404" do
          expect(subject.status).to eq 404
        end
      end

      context "given a valid gift card redemption code" do
        it 'finds the gift card' do
          subject
          expect(assigns(:gift_card)).to eq gift_card
        end

        it 'redeems the gift card' do
          allow(Spree::VirtualGiftCard).to receive(:active_by_redemption_code).and_return(gift_card)
          expect(gift_card).to receive(:redeem)#.with(api_user)
          subject
        end

        it "returns a 201" do
          subject
          expect(subject.status).to eq 201
        end
      end
    end
  end
end