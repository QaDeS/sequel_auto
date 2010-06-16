module Sequel
  module Oracle
    class Database
      SELECT_ASSOCIATIONS = proc do |schema, table|
        schema_select = if schema
          "AND ac.owner   = '#{schema.upcase}'"
        end
        <<-EOF
        SELECT acc.column_name src_col,
               acc.table_name src_tbl,
               aic.column_name dst_col,
               aic.table_name dst_tbl
          FROM all_constraints ac,
               all_ind_columns aic,
               all_cons_columns acc
         WHERE ac.r_constraint_name = aic.index_name
           AND ac.constraint_name   = acc.constraint_name
           #{schema_select}
           AND (aic.table_name = '#{table.upcase}'
           OR  acc.table_name = '#{table.upcase}')
        EOF
      end

      def translate_arrays(res)
        res.map do |r|
          Hash[r.map do |k, v|
              k =~ /_col/ ? [k,[v]] : [k, v]
            end]
        end
      end
      
    end
  end
end