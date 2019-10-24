#!/usr/bin/env ruby

require 'bundler/setup'
require 'highline'
require 'slack'

require_relative 'post'

Slack.configure do |config|
  # Use Slack's legacy API token for now, rather than full OAuth worflow:
  config.token = ENV.fetch('SLACK_API_TOKEN') { HighLine.new.ask('Slack API token:') }
end

client = Slack::Web::Client.new

channels = client.channels_list.channels
daynotes = channels.detect { |c| c.name == 'daynotes' }
messages = client.channels_history(channel: daynotes.id, count: 1000).messages

user_name_map = client.users_list.members.each_with_object({}) do |m, h|
  h[m.id] = m.real_name
end

posts = messages.map do |message|
  next if message.thread_ts # Skip threaded messages
  next unless message.type == 'message' && message.subtype.nil? # Skip other events

  Post.new(
    Time.at(message.ts.to_f),
    user_name_map[message.user],
    message.text
  )
end.compact

posts = posts.flat_map { |post| post.split_posts }

binding.irb
