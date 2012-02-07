$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'logger'

# Force loading of active record or
# acts_as_api poops itself.
require 'active_record'
ActiveRecord::Base

begin
  require "rubygems"
  require "bundler"

  if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.5")
    raise RuntimeError, "Your bundler version is too old." +
     "Run `gem install bundler` to upgrade."
  end

  # Set up load paths for all bundled gems
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run \`bundlee install\`?"
end

Bundler.require
# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.

require 'acts_as_challenged'
require 'acts_as_api'
require 'factory_girl'
require 'forgery'


db_name = ENV['DB'] || 'sqlite3'
database_yml = File.expand_path('../database.yml', __FILE__)

if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)
  
  ActiveRecord::Base.configurations = active_record_configuration
  config = ActiveRecord::Base.configurations[db_name]
  
  ActiveRecord::Base.establish_connection(db_name)
  ActiveRecord::Base.connection
    
  ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
  ActiveRecord::Base.default_timezone = :utc
  
  Migration = 
  #ActiveRecord::Base.silence do
    ActiveRecord::Migration.verbose = false
    
    load(File.dirname(__FILE__) + '/../lib/generators/acts_as_challenged/migration/templates/active_record/migration.rb')
    class UserMigration < ActiveRecord::Migration
      def self.up 
        create_table "users", :force => true do |t|
          t.string :email
        end
      end
      def self.down
      end
    end

    UserMigration.up
    ActsAsChallengedMigration.up
    
    load(File.dirname(__FILE__) + '/models.rb')
  #end  
  
else
  raise "Please create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
end

def clean_database!
  models = [ActsAsChallenged::Challenge]
  models.each do |model|
    ActiveRecord::Base.connection.execute "DELETE FROM #{model.table_name}"
  end
end


Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
Dir["#{File.dirname(__FILE__)}/factories/**/*.rb"].each {|f| require f}
clean_database!

RSpec.configure do |config|
  
end
