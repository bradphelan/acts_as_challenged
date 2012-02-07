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

  class Quest < Challenge

    def duration
      100.years
    end

    def lost?
      false
    end

    def won?
      true
    end

    # The default workflow is that this class
    # is the only challenge type
    def workflow
      []
    end

    def finished_workflow?
      cursor >= workflow.length
    end

    def contest
      if child_challenge.contest
        increment_cursor
      end

      if finished_workflow?
        super
      end

    end

    before_create do
      build_child_challenge
      true
    end

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
