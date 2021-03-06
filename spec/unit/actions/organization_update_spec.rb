require 'spec_helper'
require 'actions/organization_update'

module VCAP::CloudController
  RSpec.describe OrganizationUpdate do
    describe 'update' do
      let(:org) { VCAP::CloudController::Organization.make(name: 'old-org-name') }

      context 'when a name is requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({
            name: 'new-org-name'
          })
        end

        it 'updates a organization' do
          updated_org = OrganizationUpdate.new.update(org, message)
          expect(updated_org.reload.name).to eq 'new-org-name'
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(org).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              OrganizationUpdate.new.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'blork is busted')
          end
        end

        context 'when the org name is not unique' do
          it 'errors usefully' do
            VCAP::CloudController::Organization.make(name: 'new-org-name')

            expect {
              OrganizationUpdate.new.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'Name must be unique')
          end
        end
      end

      context 'when a name is not requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({})
        end

        it 'does not change the organization name' do
          updated_org = OrganizationUpdate.new.update(org, message)
          expect(updated_org.reload.name).to eq 'old-org-name'
        end
      end
    end
  end
end
