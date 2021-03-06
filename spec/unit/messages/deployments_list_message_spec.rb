require 'spec_helper'
require 'messages/deployments_list_message'

module VCAP::CloudController
  RSpec.describe DeploymentsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
          'app_guids' => 'appguid1,appguid2',
          'states' => 'DEPLOYED,CANCELED',
        }
      end

      it 'returns the correct DeploymentsListMessage' do
        message = DeploymentsListMessage.from_params(params)

        expect(message).to be_a(DeploymentsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guids).to match_array(['appguid1', 'appguid2'])
        expect(message.states).to match_array(['CANCELED', 'DEPLOYED'])
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = DeploymentsListMessage.from_params(params)

        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:app_guids)).to be true
        expect(message.requested?(:order_by)).to be true
        expect(message.requested?(:states)).to be true
      end
    end

    describe 'validations' do
      it 'accepts a set of params' do
        message = DeploymentsListMessage.new({
          app_guids: [],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
          states: [],
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = DeploymentsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a param not in this set' do
        message = DeploymentsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'reject an invalid order_by param' do
        message = DeploymentsListMessage.new({
          order_by:  'fail!',
        })
        expect(message).not_to be_valid
      end

      it 'validates app_guids is an array' do
        message = DeploymentsListMessage.new app_guids: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:app_guids].length).to eq 1
      end

      it 'validates states is an array' do
        message = DeploymentsListMessage.new states: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:states].length).to eq 1
      end
    end
  end
end
