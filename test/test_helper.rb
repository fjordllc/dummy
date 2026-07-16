# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require_relative '../app'

class Minitest::Test
  include Rack::Test::Methods

  def app
    DummyBlog
  end

  def setup
    DummyBlog.settings.articles_mutex.synchronize do
      DummyBlog.settings.articles.replace(DummyBlog::INITIAL_ARTICLES.map(&:dup))
    end
  end
end
