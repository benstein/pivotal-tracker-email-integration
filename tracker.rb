#!/usr/local/bin/ruby
require 'ruby-pivotal-tracker/pivotal_tracker'

TRACKER_PROJECT_ID = 603
TRACKER_API_TOKEN = '3d548bed31f47199bd1bd44d766a3d51'

def read_email_from_sdtin
  email = ''
  $stdin.each_line do |line|
    email << line
  end
  email
end

def parse_subject(email)
  email.scan(/Subject: (.*)/).flatten.first
end

def parse_to(email)
  email.scan(/To: (.*)/).flatten.first
end

def parse_body(email)
  email.scan(/[\r|\n]{2}(.*)/s).join
end

def parse_from(email)
  email.scan(/From: \"(.*)\"/).flatten.first
end

def get_story_type_from_email_address(address)
  case address
  when /feature/ then :feature
  when /bug/     then :bug
  else                :feature
  end
end

email = read_email_from_sdtin

subject = parse_subject(email)
to      = parse_to(email)
body    = parse_body(email)
from    = parse_from(email)

tracker = Tracker.new(TRACKER_PROJECT_ID, TRACKER_API_TOKEN)
story   = {
  :story_type   => get_story_type_from_email_address(to),
  :description  => body,
  :name         => subject,
  :requested_by => from
}
puts tracker.create_story(story)

