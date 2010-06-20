require 'logger'
require 'sequel'

URL = case db_type = ENV['DB']
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

l = Logger.new(File.open("#{db_type}_sql.log", 'w'))
class << l
  def format_message(severity, datetime, progname, msg)
    msg + "\n"
  end
end
DB.loggers << l

Sequel::Model.plugin :auto
DB.default_schema!
