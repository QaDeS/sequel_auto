%w[oracle postgres].each do |name|
  require "sequel/extensions/auto_assoc_#{name}" if Sequel.const_defined?(name.capitalize)
end

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
  end

end