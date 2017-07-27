require 'spec_helper'

module VCAP::CloudController
  module Internal
    RSpec.describe DropletsController do
      describe '#update' do
        let!(:droplet) {
          VCAP::CloudController::DropletModel.make(state: VCAP::CloudController::DropletModel::STAGING_STATE)
        }
        let(:request_body) do
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
          }.to_json
        end

        it 'returns a 204' do
          patch "/internal/v4/droplets/#{droplet.guid}", request_body

          expect(last_response.status).to eq 204
        end

        it 'updates the droplet' do
          patch "/internal/v4/droplets/#{droplet.guid}", request_body

          droplet.reload
          expect(droplet.state).to eq VCAP::CloudController::DropletModel::STAGED_STATE
          expect(droplet.droplet_hash).to eq('potato')
          expect(droplet.sha256_checksum).to eq('potatoest')
          expect(droplet.error).to eq('nothing bad')
        end

        context 'when the request is invalid' do
          let(:request_body) do
            {
              'state' => 'STAGED',
              'error' => 'nothing bad'
            }.to_json
          end

          it 'returns 422' do
            patch "/internal/v4/droplets/#{droplet.guid}", request_body

            expect(last_response.status).to eq(422)
            expect(last_response.body).to include('UnprocessableEntity')
            expect(last_response.body).to include('Checksums required when setting state to STAGED')
          end
        end

        context 'when InvalidDroplet is raised' do
          before do
            allow_any_instance_of(VCAP::CloudController::DropletUpdate).to receive(:update).
              and_raise(VCAP::CloudController::DropletUpdate::InvalidDroplet.new('ya done goofed'))
          end

          it 'returns an UnprocessableEntity error' do
            patch "/internal/v4/droplets/#{droplet.guid}", request_body

            expect(last_response.status).to eq 422
            expect(last_response.body).to include 'UnprocessableEntity'
            expect(last_response.body).to include 'ya done goofed'
          end
        end

        context 'when the request body is unparseable as JSON' do
          let(:request_body) { 'asdf' }

          it 'returns a MessageParseError error' do
            patch "/internal/v4/droplets/#{droplet.guid}", request_body

            expect(last_response.status).to eq 400
            expect(last_response.body).to include 'MessageParseError'
            expect(last_response.body).to include 'Request invalid due to parse error'
          end
        end

        context 'when the droplet does not exist' do
          it 'returns NotFound error' do
            patch '/internal/v4/droplets/idontexist', request_body

            expect(last_response.status).to eq(404)
            expect(last_response.body).to include('Droplet not found')
          end
        end
      end
    end
  end
end
