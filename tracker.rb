#!/usr/local/bin/ruby
require 'ruby-pivotal-tracker/pivotal_tracker'
require 'net/smtp' #for outgoing response

TRACKER_PROJECT_ID = 123
TRACKER_API_TOKEN = ''

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

def parse_name(email)
  email.scan(/From: \"(.*)\"/).flatten.first
end
def parse_from(email)
  email.scan(/From: (.*)/).flatten.first
end

def get_story_type_from_email_address(address)
  case address
  when /feature/ then :feature
  when /bug/     then :bug
  when /chore/   then :chore
  else                :feature
  end
end

def send_confirmation_email(from, to, subject, message)

  msg = <<END_OF_MESSAGE
From: #{from} <#{from}>
To: #{to} <#{to}>
Subject: #{subject}

#{message}
END_OF_MESSAGE

  Net::SMTP.start('localhost') do |smtp|
    smtp.send_message msg, from, to
  end
  
end

email = read_email_from_sdtin

subject = parse_subject(email)
to      = parse_to(email)
body    = parse_body(email)
from    = parse_from(email)
from_name = parse_name(email)

tracker = Tracker.new(TRACKER_PROJECT_ID, TRACKER_API_TOKEN)
story   = {
  :story_type   => get_story_type_from_email_address(to),
  :description  => body,
  :name         => subject,
  :requested_by => from_name
}
created_story = tracker.create_story(story)

puts "Created story #{created_story[:id]}"

send_confirmation_email(to, from, "Successfully Created Story #{created_story[:id]}!", created_story.inspect) 
