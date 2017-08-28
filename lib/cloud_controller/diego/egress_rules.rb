module VCAP::CloudController
  module Diego
    class EgressRules
      def staging(app_guid:)
        space = VCAP::CloudController::AppModel.find(guid: app_guid).space
        group_rules(space.staging_security_groups)
      end

      def running(process)
        group_rules(process.space.security_groups)
      end

      private

      def group_rules(security_groups)
        rules_hash = {}
        security_groups.each do |security_group|
          security_group.rules.each do |rule|
            rules_hash[rule] ||= []
            rules_hash[rule] << security_group.guid
          end
        end

        rules = rules_hash.map do |rule, security_group_guids|
          transform_rule(rule, security_group_guids)
        end
        order_rules(rules)
      end

      def order_rules(rules)
        logging_rules = rules.select{|rule| rule['log']}
        normal_rules = rules.select{|rule| !rule['log']}

        normal_rules | logging_rules
      end

      def transform_rule(rule, security_group_guids)
        protocol = rule['protocol']
        template = {
          'protocol' => protocol,
          'destinations' => [rule['destination']],
          'annotations' => security_group_guids.map {|guid| "security_group_id:#{guid}"},
        }

        case protocol
        when 'icmp'
          template['icmp_info'] = { 'type' => rule['type'], 'code' => rule['code'] }
        when 'tcp', 'udp'
          range = rule['ports'].split('-')
          if range.size == 1
            template['ports'] = range[0].split(',').collect(&:to_i)
          else
            template['port_range'] = { 'start' => range[0].to_i, 'end' => range[1].to_i }
          end
        end

        template['log'] = rule['log'] if rule['log']

        template
      end
    end
  end
end
