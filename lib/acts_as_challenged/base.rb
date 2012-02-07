require 'squeel'

module ActsAsChallenged

  module Base
    def acts_as_challenged
      send :include, ActsAsChallenged::InstanceMethods
      extend ActsAsChallenged::ClassMethods
      has_many :challenges, :class_name => ActsAsChallenged::Challenge
      has_many :won_challenges, :class_name => ActsAsChallenged::Challenge, :conditions => ['status = "won"']
      has_many :lost_challenges, :class_name => ActsAsChallenged::Challenge, :conditions => ['status = "lost"']
      has_many :active_challenges, :class_name => ActsAsChallenged::Challenge, :conditions => ['status = "active"']
      has_many :canceled_challenges, :class_name => ActsAsChallenged::Challenge, :conditions => ['status = "canceled"']
    end
  end

  module ClassMethods
    def is_challenge_type_available? (loaw, acaw, name)
      (not loaw.include?(name)) and (not acaw.include?(name))
    end
  end

  module InstanceMethods

    # Returns the challenge types and their availabilty as a list of hashes
    def challenge_types
      loaw = locked_out_challenge_types
      acaw = active_challenge_types

      ActsAsChallenged::Challenge.challenge_classes.map do |klass|
        { "class"       => klass.to_s ,
          "name"        => klass.challenge_name,
          "description" => klass.description,
          "available"   => User.is_challenge_type_available?(loaw, acaw, klass.to_s),
          "category"    => klass.category_i18n,
          "locked_till" => locked_out_challenge_time(klass.to_s)
        }
      end
    end

    def locked_out_challenge_types
      list = challenges.where{locked_out_till > Time.zone.now}.select{distinct(challenges.type)}
      Set.new (list.map { |l| l.type } )
    end

    def locked_out_challenge_time t
      item = challenges.where{(locked_out_till > Time.zone.now) & (challenges.type =~ t )}.select{distinct(challenges.locked_out_till)}
      if item[0]
        item[0].locked_out_till 
      else
        ""
      end    
    end

    def challenge_points
      won_challenges.sum('points')
    end

    def challenge_locked_out? challenge_type
      locked_out_challenge_types.include? challenge_type
    end

    def active_challenge_types
      Set.new challenges.active.map {|a| a.type}
    end 

  end

end
