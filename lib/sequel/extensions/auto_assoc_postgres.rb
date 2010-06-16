module Sequel
  module Postgres
    class Database
      def default_schema!
        @default_schema = begin
          schemas = DB['select nspname from pg_namespace'].select_map
          user = @opts[:user].to_s
          search_path = DB['show search_path'].get.gsub('"$user"', user).split(',')
          (search_path & schemas).first.to_sym
        end
      end

      def select_associations(schema, table)
        schema_select = if schema
          "AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = '#{schema}')"
        end
        <<-EOF
  SELECT conrelid::regclass AS src_tbl,
         array_agg(a.attname) as src_col,
         confrelid::regclass as dst_tbl,
         array_agg(af.attname) as dst_col
    FROM pg_attribute AS a,
         pg_attribute AS af,
         (SELECT conrelid,
	        confrelid, 
          conkey,
          confkey,
          connamespace,
          generate_series(1, array_upper(conkey, 1)) AS i
   FROM pg_constraint
          WHERE contype = 'f') as con
   WHERE af.attnum = confkey[i]
     AND af.attrelid = confrelid
     AND a.attnum = conkey[i]
     AND a.attrelid = conrelid
     #{schema_select}
     AND (conrelid = '#{table}'::regclass
          OR confrelid = '#{table}'::regclass)
GROUP BY src_tbl,
         dst_tbl
        EOF
      end

      private
      def translate_arrays(res)
        res.map do |r|
          r.inject({}) do |result, (k, v)|
            result.merge k => unify_identifier(translate_array(v))
          end
        end
      end

      ARRAY_RE = /,\s*/
      def translate_array(value)
        if value && value =~ /\{([^\}]*)\}/
          $1.split(ARRAY_RE)
        else
          value
        end
      end

      def unify_identifier(name)
        if name.is_a? Array
          name.map { |e| unify_identifier(e) }
        else
          name.downcase.to_sym
        end
      end

    end
  end
end