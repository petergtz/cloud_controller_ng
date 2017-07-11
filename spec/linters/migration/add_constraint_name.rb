module RuboCop
  module Cop
    module Migration
      class AddConstraintName < RuboCop::Cop::Cop
        # Postgres and MySQL have different naming conventions, so if we need to remove them we cannot predict accurately what the constraint name would be.
        MSG = 'Please explicitly name your index or constraint.'.freeze
        CONSTRAINT_METHODS = %i{
          add_unique_constraint add_constraint add_foreign_key add_index add_primary_key add_full_text_index add_spatial_index
          unique_constraint constraint foreign_key index primary_key full_text_index spatial_index
        }.freeze
        COLUMN_ADDING_METHODS = %i{
          add_column column String Integer
        }.freeze

        def on_block(node)
          node.each_descendant(:send) do |send_node|
            method = method_name(send_node)
            next unless constraint_adding_method?(method) || column_adding_method?(method)

            opts = send_node.children.last
            has_named_constraint = false

            if opts
              if constraint_adding_method?(method)
                has_named_constraint = validate_constraint_options(opts)
              elsif column_adding_method?(method)
                has_named_constraint = validate_column_options(opts)
              end
            end

            add_offense(send_node, :expression) unless has_named_constraint
          end
        end

        private

        def constraint_adding_method?(method)
          CONSTRAINT_METHODS.include?(method)
        end

        def column_adding_method?(method)
          COLUMN_ADDING_METHODS.include?(method)
        end

        def validate_constraint_options(opts)
          return false unless opts.type == :hash

          opts.each_node(:pair) do |pair|
            if hash_key_type(pair) == :sym && hash_key_name(pair) == :name
              return true
            end
          end

          false
        end

        def validate_column_options(opts)
          needs_named_index = false
          needs_named_primary_key = false
          needs_named_unique_constraint = false
          
          opts.each_node(:pair) do |pair|
            if hash_key_type(pair) == :sym
              case hash_key_name(pair)
              when :index then  needs_named_index = true
              when :primary_key then needs_named_primary_key = true
              when :unique then needs_named_unique_constraint = true
              end
            end
          end

          opts.each_node(:pair) do |pair|
            if hash_key_type(pair) == :sym
              case hash_key_name(pair)
              when :name then needs_named_index = false
              when :primary_key_constraint_name then needs_named_primary_key = false
              when :unique_constraint_name then needs_named_unique_constraint = false
              end
            end
          end

          !(needs_named_index || needs_named_primary_key || needs_named_unique_constraint)
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
      end
    end
  end
end
