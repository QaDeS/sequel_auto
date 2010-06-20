require 'sequel'

URL = case ENV['DB']
when 'oracle'
  'oracle://test:test@localhost/XE'
when 'postgres'
  'postgres://test:test@localhost:5433/postgres'
when 'sqlite'
  'sqlite://test.db'
when 'mysql'
  'mysql://test:test@localhost/test'
else
  STDERR.puts 'No/wrong DB given. valid: oracle, postgres, sqlite, mysql'
  exit
end
DB = Sequel.connect URL

Sequel::Model.plugin :auto
DB.default_schema!
