module RuboCop
  module Cop
    module Migration
      class IncludeStringSize < RuboCop::Cop::Cop
        # # Postgres and MySQL have different naming conventions, so if we need to remove them we cannot predict accurately what the constraint name would be.
        MSG = 'Please explicitly set your string size.'.freeze
        COLUMN_ADDING_METHODS = %i{
          add_column set_column_type String
        }.freeze

        def on_block(node)
          node.each_descendant(:send) do |send_node|
            method = method_name(send_node)
            next unless column_adding_method?(method)

            opts = send_node.children.last
            missing_size = true

            if opts
              if column_adding_method?(method)
                missing_size = missing_size?(opts)
              end
            end

            add_offense(send_node, :expression) if missing_size
          end
        end

        private

        def column_adding_method?(method)
          COLUMN_ADDING_METHODS.include?(method)
        end

        def missing_size?(opts)
          true
        end

        def method_name(node)
          node.children[1]
        end

        def hash_key_type(pair)
          pair.children[0].type
        end

        def hash_key_name(pair)
          pair.children[0].children[0]
        end

        def sym_opts_name(opts)
          opts.children[0]
        end
      end
    end
  end
end
