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

require 'spec_helper'

ActsAsChallenged::Challenge.challenge_folder = File.dirname(__FILE__) + '/challenges'

class A < ActsAsChallenged::Challenge ; category :blood; end
class B < ActsAsChallenged::Challenge ; category :blood; end
class C < ActsAsChallenged::Challenge ; category :blood; end
class D < ActsAsChallenged::Challenge ; category :blood; end

class SimpleChallenge < ActsAsChallenged::Challenge

  category :blood

  def duration
    6.weeks
  end

  def won?
    true
  end

  def lost?
    false
  end

  def locked_out_duration
    71.hours
  end

  def success_points
    5
  end

end


class SimpleChallenge2 < SimpleChallenge
  category :grub
end

class SimpleChallenge3 < SimpleChallenge
  category :blood
end

class ToLoseChallenge < SimpleChallenge
  category :blood
  def won?
    false
  end
  def lost?
    true
  end
end

class ComplexChallenge < ActsAsChallenged::Challenge

  category :blood
  def duration
    100.years
  end

  def won?
    false
  end

  def lost?
    false
  end

  def success_points
    10
  end
end

class OutOfDateChallenge < ActsAsChallenged::Challenge
  category :blood
  def calc_begins_on
    Time.zone.now.ago(3.weeks)
  end

  def calc_ends_on
    begins_on.since(1.weeks) 
  end
end


class QuestTest0 < ActsAsChallenged::Quest

  category :blood

  def workflow
    [SimpleChallenge,  SimpleChallenge2, SimpleChallenge3]
  end

  def success_points
    101
  end

end

describe "with stopped time" do
  before :each do
    Time.stop
  end


  describe "challenges in challenge folder" do
    ActsAsChallenged::Challenge.challenge_class_names.map do |klass_name| 
      describe "#{klass_name}" do
        it "should have a category set" do
          klass_name.constantize.category.should_not be_nil
        end
      end
    end
  end


  describe "challenges with locked_out_til attribute set" do
    before :each do
      ActsAsChallenged::Challenge.stub(:challenge_class_names).and_return %w[A B C D]     
      @user = Factory :user
    end

    describe "User#challenge_types" do
      it "should return all challenge types with meta data" do
        types = @user.challenge_types
        types.each do |t|
          t.should have_key "class"      
          t.should have_key "name"       
          t.should have_key "description"
          t.should have_key "available"  
          t.should have_key "category"   
          t.should have_key "locked_till"
        end
      end
    end

    it "are marked as not available" do

      Factory.create :challenge, :user => @user, :type => "A"
      Factory.create :challenge, :user => @user, :type => "B", :locked_out_till => Time.zone.now.since(2.hours)
      Factory.create :challenge, :user => @user, :type => "C", :locked_out_till => Time.zone.now.since(72.hours)
      Factory.create :challenge, :user => @user, :type => "D", :status => "active", :ends_on => Time.zone.now.since(2.weeks)

      @user.locked_out_challenge_types.should == Set.new(["B","C"])
      
      @user.locked_out_challenge_time("B").should == Time.zone.now.since(2.hours)
      @user.locked_out_challenge_time("C").should == Time.zone.now.since(72.hours)
      
      @user.active_challenge_types.should == Set.new(["D"])

      @ct = @user.challenge_types

      # helper for looking up the array @ct and returning the
      # entry with the matching "class" entry
      challenge = ->(klass) { @ct.find{|c|c["class"]==klass} }

      challenge["A"]["available"].should == true
      challenge["B"]["available"].should == false
      challenge["C"]["available"].should == false
      challenge["D"]["available"].should == false


      Time.advance 45.hours
      @user.locked_out_challenge_types.should == Set.new(["C"])
      @user.locked_out_challenge_time("B").should == ""
      @user.locked_out_challenge_time("C").should == Time.zone.now.since(27.hours)
      @user.active_challenge_types.should == Set.new(["D"])

      @ct = @user.challenge_types

      challenge["A"]["available"].should == true
      challenge["B"]["available"].should == true
      challenge["C"]["available"].should == false
      challenge["D"]["available"].should == false


      Time.advance 100.hours
      @user.locked_out_challenge_types.should == Set.new([])
      @user.locked_out_challenge_time("B").should == ""
      @user.locked_out_challenge_time("C").should == ""
      @user.active_challenge_types.should == Set.new(["D"])

      @ct = @user.challenge_types

      challenge["A"]["available"].should == true
      challenge["B"]["available"].should == true
      challenge["C"]["available"].should == true
      challenge["D"]["available"].should == false


      Time.advance 2.weeks
      @user.locked_out_challenge_types.should == Set.new([])
      @user.active_challenge_types.should == Set.new([])

      @ct = @user.challenge_types

      challenge["A"]["available"].should == true
      challenge["B"]["available"].should == true
      challenge["C"]["available"].should == true
      challenge["D"]["available"].should == true

    end



    it "are not possible to accept" do
      user = Factory.create :user

      Factory.create :challenge, :user => user, :type => "A"
      Factory.create :challenge, :user => user, :type => "B", :locked_out_till => Time.zone.now.since(2.hours)

      ActsAsChallenged::Challenge.create_from_challenge_name user, "A"

      proc {
        ActsAsChallenged::Challenge.create_from_challenge_name user, "B"
      }.should raise_error(ActsAsChallenged::Challenge::ForbiddenException)

    end
  end

  describe "Challenge::category :category" do
    it "should set the category of the subclass" do
      SimpleChallenge.category.should == :blood
      SimpleChallenge2.category.should == :grub
    end

    it "should not accept invalid categories" do

      proc{
        class ChallengeWithBadCategory < SimpleChallenge
          category :krak
        end
      }.should raise_error
      
    end

  end

  describe "Creating challenges" do
    before :each do 

      @user = Factory :user

      ActsAsChallenged::Challenge.stub(:challenge_class_names).and_return %w[ComplexChallenge OutOfDateChallenge SimpleChallenge SimpleChallenge2 SimpleChallenge3 ToLoseChallenge]
      ActsAsChallenged::ImplicitChallenge.stub(:challenge_classes).and_return []

      @challenge1 = ActsAsChallenged::Challenge.create_from_challenge_name @user, :SimpleChallenge
      @challenge2 = ActsAsChallenged::Challenge.create_from_challenge_name @user, :ComplexChallenge
      @challenge3 = ActsAsChallenged::Challenge.create_from_challenge_name @user, :OutOfDateChallenge


    end


    describe "ActsAsChallenged::Challenge::create_from_challenge_name" do
      it "should reject invalid challenge names to prevent security breach" do
        proc {
          ActsAsChallenged::Challenge.create_from_challenge_name @user, :evil_hack_challenge
        }.should raise_exception
      end

      describe "limiting the number of active challenges" do
        before do
          @user.save!
        end
        it "should not allow to select a 4th Challenge, when having already 3 active ones" do
          proc {
            ActsAsChallenged::Challenge.create_from_challenge_name @user, :SimpleChallenge2
          }.should_not raise_exception

          proc {
            ActsAsChallenged::Challenge.create_from_challenge_name @user, :SimpleChallenge3
          }.should raise_exception ActsAsChallenged::Challenge::ForbiddenException
        end
      end


      it "captures the class name of the Challenge subclass as :type attribute" do
        @challenge1.type.should == "SimpleChallenge"
        @challenge2.type.should == "ComplexChallenge"
      end

      it "initializes belongs_to :user association" do
        @challenge1.user_id.should == @user.id
        @challenge2.user_id.should == @user.id
      end

      it "calls #calc_ends_on and sets attribute :ends_on" do
        @challenge1.ends_on.should == @challenge1.calc_ends_on
        @challenge2.ends_on.should == @challenge2.calc_ends_on
      end
    end

    describe User do

      it "#challenges.active should return all challenges that are not_expired" do
        @user.challenges.active.should     include(@challenge1) # pending
        @user.challenges.active.should     include(@challenge2) # pending
        @user.challenges.active.should_not include(@challenge3) # expired
      end

    end

    describe "ActsAsChallenged::Challenge::contest(user)" do

      describe "winning a challenge" do
        before :each do
          Time.advance 10.minutes
          @points = @user.challenge_points
        end
        describe do
          before do
            ActsAsChallenged::Challenge.contest @user
            @challenge1.reload
          end

          it "should set the :ends_on attribute to be the time the contest was won" do
            @challenge1.should be_won
            @challenge1.ends_on.should == Time.zone.now
          end

          it "should add the won challenge to the won list" do
            @user.challenges.won.should include(@challenge1) # challengeed
          end

          it "should not add any other challenges to the won list" do
            @user.challenges.won.should_not include(@challenge2) # not challengeed
          end

          it "should not be able to win expired challenges" do
            @user.challenges.won.should_not include(@challenge3) # expired
          end

          it "should increment the points for the user" do 
            (@user.challenge_points - @points).should == 5
          end
        end

        describe "#locked_out_till" do
          before do
            @user.save!
            ActsAsChallenged::Challenge.contest @user
            @challenge1.reload
          end
          it "should set the lockout time on winning the challenge" do
            @challenge1.locked_out_till.should == Time.zone.now.since(71.hours)
          end
        end
      end

      describe "losing a challenge" do
        before :each do
          @points = @user.challenge_points
          ActsAsChallenged::Challenge.destroy_all
          @challenge_to_lose = ActsAsChallenged::Challenge.create_from_challenge_name @user, :ToLoseChallenge
          @user.challenges.active.should       include(@challenge_to_lose) # pending
          ActsAsChallenged::Challenge.contest @user

          @challenge_to_lose.reload
        end

        it "should remove the challenge from the active list" do
          @user.challenges.active.should_not   include(@challenge_to_lose) # pending
        end

        it "should add the lost challenge to the lost list" do
          @user.challenges.lost.should         include(@challenge_to_lose) # pending
        end

        it "should not add the lost challenge to the won list" do
          @user.challenges.won.should_not         include(@challenge_to_lose) # pending
        end

        it "should not change the points for the user" do 
          (@user.challenge_points - @points).should == 0
        end

        it "should set the :ends_on attribute to be the time the contest was lost" do
          @challenge_to_lose.ends_on.should == Time.zone.now
        end

      end




    end

  end

  describe "API" do
    before do
      @challenge = Factory :challenge
      @api = @challenge.as_api_response :show
    end
    it "should have one" do
      @challenge.id.should == @api[:id]
      @challenge.points.should == @api[:points]
      @challenge.message.should == @api[:message]
      @challenge.begins_on.should == @api[:begins_on]
      @challenge.ends_on.should == @api[:ends_on]
      @challenge.status.should == @api[:status]
    end
  end

  describe "Canceling an active challenge" do
    before :each do
      @challenge = Factory :challenge, :status => "active"
      @challenge.cancel
    end
    it "should be canceled" do
      @challenge.status.should == "canceled"
    end

    it "should have it's ends_on time set to Time.zone.now" do
      @challenge.ends_on.should == Time.zone.now
    end
  end

  describe "Canceling a non active challenge" do
    before :each do
      @challenge = Factory :challenge, :status => "canceled"
    end
    it "should raise an error" do
      proc {
        @challenge.cancel
      }.should raise_error
    end

  end

  describe "A quest with two sub challenges" do
    before :each do 
      @user = Factory :user

      ActsAsChallenged::Challenge.stub(:challenge_class_names).and_return %w[QuestTest0]

      @challenge1 = ActsAsChallenged::Challenge.create_from_challenge_name @user, :QuestTest0
    end

    it "should have a duration of 100 years" do
      @challenge1.duration.should == 100.years
    end

    it "should have created two challenges ( itself and the active sub challenge )" do
      @user.challenges.count.should == 2
    end

    it "should have created one root challenge (itself)" do
      @user.challenges.root.count.should == 1
      @user.challenges.root.first.should be_kind_of QuestTest0
    end

    it "should step through child challenges as a contest is run and sub challenges are won" do
      @user.challenges.active.root.count.should == 1
      @user.challenges.active.root.first.should be_kind_of QuestTest0
      @user.challenges.active.root.first.child_challenge.should be_kind_of SimpleChallenge

      ActsAsChallenged::Challenge.contest @user

      @user.challenges.active.root.count.should == 1
      @user.challenges.active.root.first.should be_kind_of QuestTest0
      @user.challenges.active.root.first.child_challenge.should be_kind_of SimpleChallenge2

      ActsAsChallenged::Challenge.contest @user

      @user.challenges.active.root.count.should == 1
      @user.challenges.active.root.first.should be_kind_of QuestTest0
      @user.challenges.active.root.first.child_challenge.should be_kind_of SimpleChallenge3

      ActsAsChallenged::Challenge.contest @user

      @user.challenges.active.root.count.should == 0

      @user.challenges.won.count.should == 1 + 3
    end
  end



  describe "A challenge with translations available in two locales." do 
    before do
      I18n.backend.store_translations :en, challenges: { SimpleChallenge3: { name: "AAA", description: "BBB", success: "CCC", fail: "DDD", abandon: "EEE" } } 
      I18n.backend.store_translations :de, challenges: { SimpleChallenge3: { name: "deAAA", description: "deBBB", success: "deCCC", fail: "deDDD", abandon: "deEEE" } } 

    end

    describe "en locale" do
      before :each do
        I18n.locale="en"
      end
      it "#challenge_name should return the translated challenge name" do
        SimpleChallenge3.challenge_name.should == "AAA"
      end
      it "#description should return the translated challenge description" do
        SimpleChallenge3.description.should == "BBB"
      end
      it "#success_message should return the translated challenge success message" do
        SimpleChallenge3.success_message.should == "CCC"
      end
      it "#fail_message should return the translated challenge fail message" do
        SimpleChallenge3.fail_message.should == "DDD"
      end
      it "#abandon_message should return the translated abandon_message" do
        SimpleChallenge3.abandon_message.should == "EEE"
      end
    end

    describe "de locale" do
      before :each do
        I18n.locale="de"
      end
      it "#challenge_name should return the translated challenge name" do
        SimpleChallenge3.challenge_name.should == "deAAA"
      end
      it "#description should return the translated challenge description" do
        SimpleChallenge3.description.should == "deBBB"
      end
      it "#success_message should return the translated challenge success message" do
        SimpleChallenge3.success_message.should == "deCCC"
      end
      it "#fail_message should return the translated challenge fail message" do
        SimpleChallenge3.fail_message.should == "deDDD"
      end
      it "#abandon_message should return the translated abandon_message" do
        SimpleChallenge3.abandon_message.should == "deEEE"
      end
    end
  end


  #issue 17397853
  describe "removing a challenge class that is referenced in the database" do
    before :each do
      class ToBeRemoved < ActsAsChallenged::Challenge ; category :blood; end
      @user = Factory :user
      Factory.create :challenge, :user => @user, :type => "ToBeRemoved", :status => "won"
    end

    it "should cause an error" do
      Object.send :remove_const, :ToBeRemoved
      proc{
        @user.challenges.all
      }.should raise_error
    end
  end

  describe "disabling a challenge class so that users cannot accept them" do
    before do
      class ToBeRemoved < ActsAsChallenged::Challenge ; category :blood; end
      class NotToBeRemoved < ActsAsChallenged::Challenge ; category :blood; end
      ActsAsChallenged::Challenge.stub(:challenge_class_names).and_return %w[ToBeRemoved NotToBeRemoved]     
      @user = Factory :user
    end

    describe "before removing" do
      it "should be available" do 
        @ct = @user.challenge_types.map{|c|c["class"]}.should include("ToBeRemoved")
      end
    end

    describe "after disabling" do
      before do
        class ToBeRemoved < ActsAsChallenged::Challenge  
          disable
        end
      end
      it "should be marked as disabled" do
        ToBeRemoved.should be_disabled
      end
      it "should not be available" do 
        @ct = @user.challenge_types.map{|c|c["class"]}.should_not include("ToBeRemoved")
      end
    end
  end

end
