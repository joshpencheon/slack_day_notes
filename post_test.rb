require 'bundler/setup'
require 'minitest/autorun'
require 'timecop'

require_relative 'post'

class PostTest < Minitest::Test
  def test_parsing_mixed_tags
    assert_parses [[1.day.ago.to_date, 'something']], "[yesterday} something"
  end

  def test_parsing_yesterday
    assert_parses [[1.day.ago.to_date, 'something']], "[yesterday] something"
  end

  def test_parsing_todays_date
    now = Time.now
    day = now.strftime('%A')

    assert_parses [[now.to_date, 'something']], "[#{day}] something"
  end

  def test_parsing_todays_date_multiline
    now = Time.now
    day = now.strftime('%A')

    assert_parses [[now.to_date, "something\nmore"]], <<~MESSAGE
      [#{day}] something
      more
    MESSAGE
  end

  def test_splitting_messages_with_just_today
    assert_parses [[Date.today, "bar\nbaz"]], <<~MESSAGE
      bar
      baz
    MESSAGE
  end

  def test_splitting_messages_with_multiple_days
    thursday = Date.new(2019, 10, 24)
    friday = Date.new(2019, 10, 25)

    Timecop.travel(friday) do
      expected = [[friday, "bar"], [thursday, "foo"]]
      assert_parses expected, <<~MESSAGE
        [thursday] foo
        [friday] bar
      MESSAGE
    end
  end

  def test_splitting_messages_with_multiple_days_and_today
    wednesday = Date.new(2019, 10, 23)
    thursday = Date.new(2019, 10, 24)
    friday = Date.new(2019, 10, 25)

    Timecop.travel(friday) do
      expected = [[friday, "quix"], [thursday, "baz"], [wednesday, "foo\nbar"]]
      assert_parses expected, <<~MESSAGE
        [wednesday] foo
        bar
        [thursday] baz
        quix
      MESSAGE
    end
  end

  private

  def assert_parses(expected_results, message)
    posts = Post.new(Time.now, 'josh', message).split_posts

    assert_equal expected_results.length, posts.length

    expected_results.each_with_index do |(date, message), index|
      assert_equal message, posts[index].message
      assert_equal date, posts[index].date
    end
  end
end
