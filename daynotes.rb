#!/usr/bin/env ruby

require 'bundler/setup'
require 'highline'
require 'slack'

require_relative 'post'

Slack.configure do |config|
  # Use Slack's legacy API token for now, rather than full OAuth worflow:
  config.token = ENV.fetch('SLACK_API_TOKEN') { HighLine.new.ask('Slack API token:') }
end

module Daynotes
  extend self

  def posts
    messages.map { |message| message_to_post(message) }.
      compact.flat_map { |post| post.split_by_day }
  end

  private

  def client
    @client ||= Slack::Web::Client.new
  end

  def messages
    channels = client.channels_list.channels
    daynotes = channels.detect { |c| c.name == 'daynotes' }
    messages = client.channels_history(channel: daynotes.id, count: 1000).messages
  end

  def user_map
    @user_map ||= client.users_list.members.each_with_object({}) do |user, hash|
      hash[user.id] = user.real_name
    end
  end

  def message_to_post(message)
    return if message.thread_ts # Skip threaded messages
    return unless message.type == 'message' && message.subtype.nil? # Skip other events

    Post.new(
      Time.at(message.ts.to_f),
      user_map[message.user],
      message.text
    )
  end
end

posts = Daynotes.posts

binding.irb
