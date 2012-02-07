# == Schema Information
#
# Table name: challenges
#
#  id                 :integer         not null, primary key
#  type               :string(255)
#  points             :integer         default(0)
#  data               :text
#  user_id            :integer
#  created_at         :datetime
#  updated_at         :datetime
#  child_challenge_id :integer
#  ends_on            :datetime
#  cursor             :integer         default(0)
#  begins_on          :datetime
#  locked_out_till    :datetime
#  status             :string(255)     default("active"), not null
#

module ActsAsChallenged 
  class Challenge < ActiveRecord::Base
    belongs_to :user

    Categories = %w[
      blood
      grub
      sweat
      needles
      social
    ]
    acts_as_api

    # Call this method to disable a class from
    # being available to users.
    #
    # class FooChallenge
    #   disable
    # end
    def self.disable
      @disabled = true
    end

    def self.disabled?
      @disabled
    end

    def self.duration d=nil
      @duration = d if d
      @duration || 24.hours
    end

    api_accessible :show do |t|
      t.add :id
      t.add lambda {|challenge| challenge.type }, :as => :type
      t.add :points
      t.add :message
      t.add :begins_on
      t.add :ends_on
      t.add :status
    end

    def self.i18n_scope
      [:challenges, self.to_s.to_sym]
    end

    def self.challenge_name
      I18n.t :name, :scope => i18n_scope
    end

    def challenge_name
      self.class.challenge_name
    end


    def self.description
      I18n.t :description, :scope => i18n_scope
    end

    def message
      case status
      when 'active'
        ""
      when 'won'
        self.class.success_message
      when 'lost'
        self.class.fail_message
      when 'canceled'
        self.class.abandon_message
      end
    end

    def self.success_message
      I18n.t :success, :scope => i18n_scope
    end

    def self.fail_message
      I18n.t :fail, :scope => i18n_scope
    end

    def self.abandon_message
      I18n.t :abandon, :scope => i18n_scope
    end

    STATUS_LIST = %w[active won lost canceled]
    validates_inclusion_of :status, :in => STATUS_LIST

    class NotFoundException < StandardError; end
    class ForbiddenException < StandardError; end


    # This builds the challenge heirarchy
    belongs_to :child_challenge, 
      :class_name  => "Challenge",
      :foreign_key => :child_challenge_id,
      :dependent => :destroy


    has_one :parent_challenge, 
      :class_name  => "Challenge",
      :foreign_key => :child_challenge_id,
      :inverse_of  => :child_challenge


    def expired?
      Time.zone.now > read_attribute(:ends_on)
    end

    def owned_by? user
      user.id == user_id
    end


    validates :user, :presence => true
    validates_numericality_of :points, :allow_nil => true

    validates_numericality_of :points

    def cancel
      if self.status == "active"
        self.status = "canceled"
        self.ends_on = Time.zone.now
      else
        raise Challenge::ForbiddenException.new("It is only possible to cancel a challenge in the 'active' state")
      end
    end


    def finished_workflow?
      cursor >= workflow.length
    end

    def contest

      _won  = won?
      _lost = lost?

      if _won and _lost
        raise "LogicError: An challenge cannot be simultaneously WON and LOST"
      end

      if _won or _lost
        self.ends_on = Time.zone.now
      end

      if _lost
        self.status = "lost"
        self.locked_out_till = ends_on
      end

      if _won
        self.status = "won"
        self.points=self.success_points
        self.locked_out_till = calc_locked_out_till
      end

      if _won or _lost
        self.save!
      end

    end


    # Return the previous challenges of this type that has been won in ends_on DESC order
    def previous_won_challenges
      previous_contested.won
    end

    # Return the previous challenges of this type that has been contested in ends_on DESC order
    def previous_contested_challenges
      user.challenges.where{id!=my{id}}.where{type==my{self.class.name}}.order("ends_on DESC")
    end

    # Return all logs that may be of interest that
    # were made during the challenge's active period
    def logs
      user.logs.in_challenge_period(self)
    end

    # Returns challenges that have no parent. It does
    # not return child challenges as we will wish to
    # traverse the challenge tree from the root down
    def self.root
      # The select at the end is just to trick ActiveRecord into
      # not marking the record as readonly ???? WTF
      Challenge.joins{parent_challenge.outer}.where{parent_challenge.id == nil}.select("challenges.*")
    end

    # -------------------------
    # QUERIES
    # -------------------------
    def self.ago seconds
      from = Time.zone.now.ago seconds
      where{ends_on > my{from}}
    end

    def self.expired
      where{(challenges.ends_on < Time.zone.now) & (challenges.status == "active") }
    end

    def self.active
      where{(challenges.ends_on > Time.zone.now) & (challenges.status == "active")}
    end

    def self.won
      where{challenges.status == "won"}
    end

    def self.lost
      where{challenges.status == "lost"}
    end

    def self.canceled
      where{challenges.status == "canceled"}
    end

    # --------------------------
    # AWARD LOOKUP HELPERS
    # --------------------------

    def self.challenge_glob
      File.join challenge_folder, "*.rb"
    end

    if defined? Rails
      DefaultChallengeFolder = Rails.root.join("app/models/challenges")
    end

    def self.challenge_folder
      @challenge_folder || DefaultChallengeFolder
    end

    def self.challenge_folder=folder
      @challenge_folder = folder
    end

    def self.challenge_class_names
      Dir[challenge_glob].collect do |file|
        file.split(".")[0].split("/").last.classify
      end
    end

    def self.challenge_classes
      challenge_class_names.map do |name|
        name.constantize
      end.reject(&:disabled?)
    end

    # This is a security feature so injected challenge names cannot
    # instantiate classes that are not challenges.
    def self.validate_challenge_name challenge_class_name
      challenge_class_names.include? challenge_class_name.to_s
    end

    MaxActiveChallenges = 3
    # Factory method for creating challenges for a user
    #
    # @param challenge_class_name name of the challenge class
    def self.create_from_challenge_name user, challenge_class_name
      if not validate_challenge_name challenge_class_name
        raise Challenge::NotFoundException.new("#{challenge_class_name} is not a valid challenge name")
      end

      if user.challenges.active.count == MaxActiveChallenges
        raise Challenge::ForbiddenException.new("User is not allowed to have more then #{MaxActiveChallenges} active Challenges")      
      end

      if user.challenge_locked_out? challenge_class_name
        raise Challenge::ForbiddenException.new("#{challenge_class_name} is locked")
      end

      challenge = challenge_class_name.to_s.constantize.create! do |challenge|
        challenge.begins_on = challenge.calc_begins_on
        challenge.ends_on = challenge.calc_ends_on
        challenge.user = user
        challenge.status = "active"
      end
      challenge.reload
    end

    # Evaluate the user across all pending challenges
    # @param user the user
    # @param log the last log entry to trigger a contest
    def self.contest user
      user.challenges.active.root.all.each do |challenge|
        challenge.contest
      end
    end

    # --------------------------
    # DSL METHODS
    # --------------------------

    def won?
      raise "please implement this method you daft monkey"
    end

    def lost?
      raise "please implement this method you faded rock star"
    end

    def success_points
      0
    end

    # Returns a time until this challenge is unlocked. Default == 0 hours
    def calc_locked_out_till
       ends_on.since locked_out_duration
    end

    # The default workflow is that this class
    # is the only challenge type
    def workflow
      []
    end

    def duration
      24.hours
    end

    def locked_out_duration
      24.hours
    end

    # Default expiry is 24 hours in the future
    def calc_ends_on
      begins_on.since duration
    end

    def calc_begins_on
      Time.zone.now
    end 

    #-----------------------------------------
    # END DSL METHODS
    #-----------------------------------------

    private

    def build_child_challenge
      if not finished_workflow?
        self.child_challenge = workflow[cursor].create! do |challenge|
          challenge.user = user
        end
        true
      else
        false
      end
    end
    def increment_cursor
      self.cursor += 1
      build_child_challenge
      save!
    end

  end
end
