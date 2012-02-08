# acts_as_challenged

This is a challenge engine that can be used to add challenge / achievement functionality
easily to your ActiveRecord models.

## Installation

In your gemfile

    gem 'acts_as_challenged'
    
Generate models

    rails generate acts_as_challenged

In your :user model

    class User < ActiveRecord::Base
      
      acts_as_challenged

    end

In an config/initializers/acts_as_challenged.rb

    ActsAsChallenged::Challenge.challenge_folder = File.join Rails.root 'app/models/challenges'

or specify an alternate directory in which to create your challenge models. 

There are two types of challenges

  * implicit challenges
  * explicit challenges

### ActsAsChallenged::ImplicitChallenge

subclasses are always active. You place them in the challenge folder as described above and they can
be written as below. ( Assuming an ActiveRecord scope actions_in_the_last_week on the User class )

    class BusyUserChallenge < ActsAsChallenged::ImplicitChallenge
      def won?
        user.actions_in_the_last_week.count > 10 and previous_won_challenges.count == 0
      end

      def success_points
        30
      end
      
    end

Then every time you need to test the implicit challenges you just need to do

    # Load the user and perform an activity that might count
    # towards an achievement
    @user = User.find(params[:user][:id])
    @user.perform_some_activity

    # Run all the challenge rules
    ImplicitChallenge.contest @user 

    # Print out the current points the user has
    puts @user.challenge_points

    # Find all the won challenges
    pp @user.challenges.won

### ActsAsChallenged::Challenge

You may not want challenges to be active until either the user accepts a challenge. For
example

    class RunningChallenge < ActsAsChallenged::Challenged

      # Set the duration of the challenge. After the duration
      # is expired and not won then the challenge is lost.
      def duration
        1.week
      end

      # The class provides begins_on and ends_on timestamps based
      # on the duration to use in your custom predicates.
      def won?
        user.distance_run_in_period(begins_on, ends_on) > 100
      end

      def success_points
        50
      end

      # You can't take the challenge again for 71 hours if you win it.
      # You can take the challenge again immediately if you lost it
      def locked_out_duration
        71.hours
      end

    end

User workflow in a controller method might be

First accept the challenge by calling the create_from_challenge_name factory method which
accepts the class name of the challenge as a string. There are security meaures in place
to stop abitrary class instantiation.

    @user = User.find(params[:user][:id])
    @challenge_class_name = params[:challenge_class_name] # RunningChallenge in this case
    ActsAsChallenged::Challenge.create_from_challenge_name @user, @challenge_class_name

Next run the challenges as before

    # Run all the challenge rules that have been accepted
    Challenge.contest @user

    # Print out the current points the user has
    puts @user.challenge_points

    # Find all the won challenges
    pp @user.challenges.won
    
There are more options and methods. See the rdoc and the specs for more information.

## Contributing to acts_as_challenged
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

== Copyright

Copyright (c) 2012 MySugr AG
Copyright (c) 2012 Brad Phelan

See LICENSE.txt for further details

