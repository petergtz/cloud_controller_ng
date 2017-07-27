module VCAP::CloudController
  class DropletUpdate
    class InvalidDroplet < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.droplet_update')
    end

    def update(droplet, message)
      validate_droplet_state!(droplet)
      @logger.info("Updating droplet #{droplet.guid}")

      droplet.db.transaction do
        droplet.lock!

        droplet.state             = message.state if message.requested?(:state)
        droplet.droplet_hash      = message.sha1 if message.requested?(:checksums)
        droplet.sha256_checksum   = message.sha256 if message.requested?(:checksums)
        droplet.error_description = message.error if message.requested?(:error)

        droplet.save
      end

      @logger.info("Finished updating droplet #{droplet.guid}")
      droplet
    rescue Sequel::ValidationFailed => e
      raise InvalidDroplet.new(e.message)
    end

    private

    def validate_droplet_state!(droplet)
      if [DropletModel::STAGED_STATE, DropletModel::FAILED_STATE].include?(droplet.state)
        raise InvalidDroplet.new('Invalid state. State is already final and cannot be modified.')
      end
    end
  end
end
