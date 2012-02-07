class SimpleChallenge < ActsAsChallenged::Challenge

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

FactoryGirl.define do
  factory :challenge, :class => ActsAsChallenged::Challenge do
    user { Factory :user }
  end

  factory :simple_challenge do
    user { Factory :user }
    status { "active" }
    begins_on {Time.zone.now}
    ends_on {Time.zone.now + 6.weeks}
  end
end
