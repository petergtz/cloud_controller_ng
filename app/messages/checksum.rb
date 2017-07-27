require 'messages/base_message'

module VCAP::CloudController
  class Checksum < ::VCAP::CloudController::BaseMessage
    ALLOWED_KEYS = [:type, :value].freeze
    SHA1         = 'sha1'.freeze
    SHA256       = 'sha256'.freeze

    attr_accessor(*ALLOWED_KEYS)

    def allowed_keys
      ALLOWED_KEYS
    end

    validates_with NoAdditionalKeysValidator

    validates :type, inclusion: { in: [SHA1, SHA256], message: 'must be one of sha1, sha256' }
    validates :value, length: { in: 1..500, message: 'must be between 1 and 500 characters' }
  end
end
