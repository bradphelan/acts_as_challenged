require "active_record"

$LOAD_PATH.unshift(File.dirname(__FILE__))

module ActsAsChallenged
  autoload :Base, 'acts_as_challenged/base'
  autoload :Challenge, 'acts_as_challenged/challenge'
  autoload :ImplicitChallenge, 'acts_as_challenged/implicit_challenge'
  autoload :Quest, 'acts_as_challenged/quest'
end
 
if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend ActsAsChallenged::Base
end
