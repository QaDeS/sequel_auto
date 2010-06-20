module Sequel
  module Oracle
    class Database

      alias schema_parse_table_without_pk schema_parse_table

      # Adds the :primary_key marker to the table schema
      def schema_parse_table(table, opts = {})
        result = schema_parse_table_without_pk(table, opts)
        schema, table = schema_and_table(table)
        schema_select = if schema
          "AND acc.owner = '#{schema.upcase}'"
        end
        sql = <<-EOF
          SELECT acc.column_name column_name
            FROM all_constraints ac,
                 all_cons_columns acc
           WHERE ac.table_name = '#{table.upcase}'
                 #{schema_select}
             AND ac.constraint_type = 'P'
             AND acc.constraint_name = ac.constraint_name
        EOF
        self[sql].each do |row|
          col = row[:column_name].downcase.to_sym
          result.assoc(col)[1][:primary_key] = true
        end
        result
      end

      alias drop_table_without_purge drop_table
      def drop_table(table)
        drop_table_without_purge(table)
        execute 'purge recyclebin'
      end

      def default_schema!
        #@default_schema = @opts[:user].to_sym
      end

      def indexes(table)
        schema, table = schema_and_table(table)
        schema_select = if schema
          "AND ai.table_owner = '#{schema.to_s.upcase}'"
        end
        sql = <<-EOF
          SELECT ai.index_name index_name,
                 aic.column_name columns,
                 ai.uniqueness "unique"
            FROM all_indexes ai,
                 all_ind_columns aic
           WHERE ai.table_name = '#{table.to_s.upcase}'
                 #{schema_select}
             AND ai.table_owner = aic.table_owner
             AND aic.index_name = ai.index_name
        EOF
        group(self[sql].all, :index_name, :columns) { |row| row[:unique] = row[:unique] == 'UNIQUE' }
      end

      def select_associations(schema, table)
        schema_select = if schema
          "AND ac.owner   = '#{schema.to_s.upcase}'"
        end
        <<-EOF
        SELECT acc.column_name src_col,
               acc.table_name src_tbl,
               aic.column_name dst_col,
               aic.table_name dst_tbl,
               ac.constraint_name cons
          FROM all_constraints ac,
               all_ind_columns aic,
               all_cons_columns acc
         WHERE ac.r_constraint_name = aic.index_name
           AND ac.constraint_name   = acc.constraint_name
           #{schema_select}
           AND aic.table_owner = ac.owner
           AND acc.owner = ac.owner
           AND (aic.table_name = '#{table.upcase}'
            OR acc.table_name = '#{table.upcase}')
        EOF
      end

    end
  end
end