require 'spec_helper'
require 'messages/organization_update_message'

module VCAP::CloudController
  RSpec.describe OrganizationUpdateMessage do
    let(:body) do
      {
        'name' => 'my-org',
      }
    end

    describe 'validations' do
      it 'validates that there are not excess fields' do
        body['bogus'] = 'field'
        message = OrganizationUpdateMessage.new(body)

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'name' do
        it 'validates that it is a string' do
          body = { name: 1 }
          message = OrganizationUpdateMessage.new(body)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include('Name must be a string')
        end

        describe 'allowed special characters' do
          it 'allows standard ascii characters' do
            body = { name: "A -_- word 2!?()\'\"&+." }
            message = OrganizationUpdateMessage.new(body)
            expect(message).to be_valid
          end

          it 'allows backslash characters' do
            body = { name: 'a\\word' }
            message = OrganizationUpdateMessage.new(body)
            expect(message).to be_valid
          end

          it 'allows unicode characters' do
            body = { name: '防御力¡' }
            message = OrganizationUpdateMessage.new(body)
            expect(message).to be_valid
          end

          it 'does NOT allow newline characters' do
            body = { name: "one\ntwo" }
            message = OrganizationUpdateMessage.new(body)
            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Name must not contain escaped characters')
          end

          it 'does NOT allow escape characters' do
            body = { name: "a\e word" }
            message = OrganizationUpdateMessage.new(body)
            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Name must not contain escaped characters')
          end
        end

        it 'must be >= 1 characters long' do
          body = { name: '' }
          message = OrganizationUpdateMessage.new(body)
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include('Name is too short (minimum is 1 character)')

          body = { name: 'a' * 255 }
          message = OrganizationUpdateMessage.new(body)
          expect(message).to be_valid
        end

        it 'must be <= 255 characters long' do
          body = { name: 'a' * 256 }
          message = OrganizationUpdateMessage.new(body)
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include('Name is too long (maximum is 255 characters)')

          body = { name: 'a' * 255 }
          message = OrganizationUpdateMessage.new(body)
          expect(message).to be_valid
        end
      end

      describe 'metadata' do
        it 'can parse labels' do
          params =
            {
                "name": 'brad',
                "metadata": {
                    "labels": {
                        "potato": 'mashed'
                    }
                }
            }
          message = OrganizationUpdateMessage.new(params)
          expect(message).to be_valid
          expect(message.labels).to include("potato": 'mashed')
        end

        it 'validates labels' do
          params = {
              "name": 'chuck',
              "metadata": {
                  "labels": 'potato',
              }
          }
          message = OrganizationUpdateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:metadata)).to include("'labels' is not a hash")
        end
      end
    end
  end
end
