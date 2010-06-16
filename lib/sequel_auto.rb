require 'waiting_hash'

module Sequel
  module Plugins
    module Auto

      TABLE_MODELS = ::WaitingHash.new

      def self.apply(model, opts = {})
        require 'sequel/extensions/auto_assoc'
        if model == Sequel::Model
          # applied on model base class -> auto_assoc subclasses
        else
        end
      end

      module ClassMethods
        def inherited(cls)
          super
          TABLE_MODELS[cls.table_name] = cls
        end

        # Takes the following options:
        # * :except : an array of field names to exclude
        def auto_assoc(opts = {})
          except = opts[:except] || []

          relations = process_join_tables(db.schema_parse_associations(table_name))

          relations.each do |row|
            src_tbl = row[:src_tbl]
            src_col = row[:src_col]
            if src_tbl == table_name && ! (src_col & except).empty?
              # TODO enable except for *_to_many
              next
            end
            src_uniq = row[:src_uniq]
            src_cardinality = cardinality(src_uniq)

            join_tbl = row[:join_tbl]

            dst_tbl = row[:dst_tbl]
            dst_col = row[:dst_col]
            dst_uniq = row[:dst_uniq]
            dst_cardinality = cardinality(dst_uniq)

            TABLE_MODELS.wait_all(src_tbl, dst_tbl) do |src_cls, dst_cls|
              self_ref = src_cls == dst_cls

              src = self_ref ? :child : underscore(src_cls.name).to_sym
              src = src_uniq ? singularize(src).to_sym : pluralize(src).to_sym

              dst = self_ref ? :parent : underscore(dst_cls.name).to_sym
              dst = dst_uniq ? singularize(dst).to_sym : pluralize(dst).to_sym

              if join_tbl
                left_col = row[:left_col]
                right_col = row[:right_col]
                send :many_to_many, src, :class => src_cls, :join_table => join_tbl,
                  :left_key => left_col, :left_primary_key => dst_col,
                  :right_key => right_col, :right_primary_key => src_col
              else
                # TODO name overrides

                if self == dst_cls
                  # dst holds the foreign key -> one_to_*
                  meth = dst_cardinality + '_to_' + src_cardinality
                  send meth, src, :class => src_cls, :key => src_col, :primary_key => dst_col
                end

                if self == src_cls
                  # src holds the foreign key -> *_to_one
                  meth = src_cardinality + '_to_' + dst_cardinality

                  # one_to_one requires to swap pk and fk
                  src_col, dst_col = dst_col, src_col if src_uniq
                  send meth, dst, :class => dst_cls, :key => src_col, :primary_key => dst_col
                end
              end

            end
          end
        end

        def auto_models(opts = {})
          db.tables.map do |t|
            unless join_table_assoc(t)
              name = camelize(singularize(t))
              Object.class_eval <<-EOF
                class #{name} < Sequel::Model
                  auto_assoc #{opts.inspect}
                end
              EOF
              Object.const_get name
            end
          end.compact
        end

        private
        def is_unique(table, fields)
          cols = fields.dup
          sch = db.schema(table).inject({}) { |result, (k, v)| result.merge k => v }
          fields.each do |name|
            cols.delete name if sch[name][:primary_key]
          end
          return true if cols.empty?

          db.indexes(table).each_pair do |_, idx|
            next unless idx[:unique]
            cols -= idx[:columns]
            return true if cols.empty?
          end
          false
        end

        def process_join_tables(relations)
          joins = {}
          relations.dup.each do |row|
            src_tbl = row[:src_tbl]
            if join = (joins[src_tbl] ||= join_table_assoc(src_tbl))
              relations.delete(row)
              row[:src_uniq] = row[:dest_uniq] = false
              relations += create_join_rows(row, join)
            else
              row[:src_uniq] = is_unique(src_tbl, row[:src_col])
              row[:dst_uniq] = is_unique(row[:dst_tbl], row[:dst_col])
            end
          end
          relations
        end

        def create_join_rows(row, join)
          others = join.select{ |r| r[:dst_tbl] != row[:dst_tbl] || r[:dst_col] != row[:dst_col]}
          row[:join_tbl] = row[:src_tbl]
          row[:left_col] = row[:src_col]
          others.map do |other|
            r = row.dup
            r[:src_tbl] = other[:dst_tbl]
            r[:src_col] = other[:dst_col]
            r[:right_col] = other[:src_cols]
            r
          end
        end

        def join_table_assoc(table)
          non_ind = db.schema(table).map { |(name, d)| name unless d[:primary_key] }.compact
          assoc = db.schema_parse_associations(table)
          assoc.each do |row|
            if row[:src_tbl] == table &&
                row[:dst_tbl] != table  # self reference can't occur in link table
              non_ind -= row[:src_col]
            end
          end
          non_ind.empty? ? assoc : nil
        end

        def cardinality(uniq)
          uniq ? 'one' : 'many'
        end
      end

      module Unsupported
        def self.included(cls)
          Sequel.logger.info("AutoAssociations are not supported on #{cls.name.split('::')[-2]}")
        end
        def schema_parse_associations(table, opts={})
          {}
        end
      end


    end
  end
end
