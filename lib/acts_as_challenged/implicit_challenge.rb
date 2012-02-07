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
  class ImplicitChallenge < Challenge

    def calc_ends_on
      begins_on
    end

    def self.challenge_folder
      "challenges/implicit"
    end

    # You can never lose an implict challenge
    # as it is always active
    def lost?
      false
    end

    def self.contest user
      challenge_classes.each do |challenge_class|
        a = challenge_class.new do |a|
          a.user_id = user.id
          a.begins_on = nil
          a.ends_on = nil
        end
        a.contest
      end
    end

  end
end
