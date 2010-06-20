module Sequel
  class Database

    def default_schema!
      #do nothing per default
    end
    
    def schema_parse_associations(table, opts={})
      ds = dataset
      ds.identifier_output_method = :downcase
      schema, table = schema_and_table(table)
      sql = select_associations(schema, table)
      translate_arrays(self[sql].all)
    end

    private
    def translate_arrays(res)
      group(res, :cons, :src_col, :dst_col).values
    end

    def group(res, group_key, *agg_keys)
      result = {}
      res.each do |r|
        yield r if block_given?
        h=Hash[r.map do |k, val|
            v = val.is_a?(String) ? val.downcase.to_sym : val
            agg_keys.member?(k) ? [k,[v]] : [k, v]
          end]
        if r = result[g = h.delete(group_key)]
          agg_keys.each do |key|
            r[key] = Array(r[key]) << h[key]
          end
        else
          result[g] = h
        end
      end
      result
    end

  end
end

%w[Oracle Postgres MySQL].each do |name|
  require "sequel/extensions/auto_assoc_#{name.downcase}" if Sequel.const_defined?(name)
end

