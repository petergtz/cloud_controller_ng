require 'spec_helper'
require 'actions/droplet_update'

module VCAP::CloudController
  RSpec.describe DropletUpdate do
    subject(:droplet_update) { DropletUpdate.new }

    describe '#update' do
      let(:body) do
        {
          'state'     => 'STAGED',
          'checksums' => [
            {
              'type'  => 'sha1',
              'value' => 'potato'
            },
            {
              'type'  => 'sha256',
              'value' => 'potatoest'
            }
          ],
          'error' => 'nothing bad'
        }
      end
      let(:droplet) { DropletModel.make(state: DropletModel::STAGING_STATE) }
      let(:message) { InternalDropletUpdateMessage.create_from_http_request(body) }

      it 'updates the droplet' do
        droplet_update.update(droplet, message)

        droplet.reload
        expect(droplet.state).to eq(DropletModel::STAGED_STATE)
        expect(droplet.droplet_hash).to eq('potato')
        expect(droplet.sha256_checksum).to eq('potatoest')
        expect(droplet.error).to eq('nothing bad')
      end

      context 'when the droplet is already in STAGED_STATE' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE) }

        it 'raises InvalidDroplet' do
          expect {
            droplet_update.update(droplet, message)
          }.to raise_error(DropletUpdate::InvalidDroplet)
        end
      end

      context 'when the droplet is already in FAILED_STATE' do
        let(:droplet) { DropletModel.make(state: DropletModel::FAILED_STATE) }

        it 'raises InvalidDroplet' do
          expect {
            droplet_update.update(droplet, message)
          }.to raise_error(DropletUpdate::InvalidDroplet)
        end
      end

      context 'when the droplet is invalid' do
        before do
          allow(droplet).to receive(:save).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidDroplet' do
          expect {
            droplet_update.update(droplet, message)
          }.to raise_error(DropletUpdate::InvalidDroplet)
        end
      end
    end
  end
end
