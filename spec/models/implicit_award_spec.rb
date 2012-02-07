# == Schema Information
#
# Table name: challenges
#
#  id              :integer         not null, primary key
#  type            :string(255)
#  points          :integer         default(0)
#  data            :text
#  message         :string(255)
#  user_id         :integer
#  created_at      :datetime
#  updated_at      :datetime
#  child_challenge_id  :integer
#  ends_on         :datetime
#  cursor          :integer         default(0)
#  begins_on       :datetime
#  locked_out_till :datetime
#  status          :string(255)     default("active"), not null
#

require 'spec_helper'

class TestImplicitChallenge0 < ActsAsChallenged::ImplicitChallenge

  class << self
    attr_accessor :count
    def count
      @count || 0
    end
  end

  def won?
    TestImplicitChallenge0.count+=1
    TestImplicitChallenge0.count > 2
  end

  def success_points
    20
  end
end


describe ActsAsChallenged::ImplicitChallenge do
  before :each do 
    @user = Factory :user

    ActsAsChallenged::ImplicitChallenge.stub(:challenge_class_names) do
      %w[TestImplicitChallenge0]
    end

    # We need to set an explicit time zone or Time.zone.now poops
    # itself in the challenge class
    Time.zone = "Melbourne"

  end

  it "should contest all the challenges" do
    ActsAsChallenged::ImplicitChallenge.contest @user
    TestImplicitChallenge0.count.should == 1
    @user.challenges.won.count.should == 0
    @user.challenge_points.should == 0

    ActsAsChallenged::ImplicitChallenge.contest @user
    TestImplicitChallenge0.count.should == 2
    @user.challenges.won.count.should == 0
    @user.challenge_points.should == 0

    ActsAsChallenged::ImplicitChallenge.contest @user
    TestImplicitChallenge0.count.should == 3
    @user.challenges.won.count.should == 1
    @user.challenge_points.should == 20
  end
   
  it "active implicit challenges should not be listed by User.active_challenges" do
    @user.active_challenges.count.should == 0
  end

end

class ImplicitToBeRemoved < ActsAsChallenged::ImplicitChallenge ; end
class ImplicitNotToBeRemoved < ActsAsChallenged::ImplicitChallenge ; end

describe "disabling an implicit challenge class so that users cannot accept them" do
  before :each do
    ActsAsChallenged::ImplicitChallenge.stub(:challenge_class_names)do
      %w[ImplicitToBeRemoved ImplicitNotToBeRemoved] 
    end
    @user = Factory :user
  end

  begin
    describe "before disabling" do
      it "should be available" do 
        @ct = ActsAsChallenged::ImplicitChallenge.challenge_classes.should include ImplicitToBeRemoved
      end
    end
  end

  describe "after disabling" do
    before do
      class ImplicitToBeRemoved
        disable
      end
    end
    it "should be marked as disabled" do
      ImplicitToBeRemoved.should be_disabled
    end
    it "should not be available" do 
      @ct = ActsAsChallenged::ImplicitChallenge.challenge_classes.should_not include ImplicitToBeRemoved
    end
  end
end

