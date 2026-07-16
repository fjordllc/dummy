# frozen_string_literal: true

require_relative 'test_helper'

class DummyBlogTest < Minitest::Test
  def test_articles_index
    get '/articles'

    assert_equal 200, last_response.status
    assert_includes last_response.content_type, 'text/html'
    assert_includes last_response.body, 'HTTPを手で話してみよう'
    assert_equal last_response.body.bytesize.to_s, last_response.headers['Content-Length']
  end

  def test_new_article_form
    get '/articles/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'application/x-www-form-urlencoded'
    assert_includes last_response.body, 'name="title"'
  end

  def test_article_show
    get '/articles/1'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'HTTPを手で話してみよう'
  end

  def test_create_article
    post '/articles', 'title=Hello&body=HTTP', 'CONTENT_TYPE' => 'application/x-www-form-urlencoded'

    assert_equal 201, last_response.status
    assert_equal '/articles/4', last_response.headers['Location']
    assert_includes last_response.body, 'Hello'
    assert_includes last_response.body, 'HTTP'

    get '/articles/4'
    assert_equal 200, last_response.status
  end

  def test_escapes_posted_html
    post '/articles', 'title=%3Cscript%3Ealert%281%29%3C%2Fscript%3E&body=%3Cb%3Eunsafe%3C%2Fb%3E',
         'CONTENT_TYPE' => 'application/x-www-form-urlencoded'

    assert_equal 201, last_response.status
    refute_includes last_response.body, '<script>'
    refute_includes last_response.body, '<b>unsafe</b>'
    assert_includes last_response.body, '&lt;script&gt;'
    assert_includes last_response.body, '&lt;b&gt;unsafe&lt;/b&gt;'
  end

  def test_rejects_blank_fields
    post '/articles', 'title=&body=HTTP', 'CONTENT_TYPE' => 'application/x-www-form-urlencoded'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'Title and body are required.'
  end

  def test_rejects_wrong_content_type
    post '/articles', '{"title":"Hello","body":"HTTP"}', 'CONTENT_TYPE' => 'application/json'

    assert_equal 400, last_response.status
  end

  def test_rejects_oversized_body
    post '/articles', "title=Hello&body=#{'a' * DummyBlog::MAX_BODY_SIZE}",
         'CONTENT_TYPE' => 'application/x-www-form-urlencoded'

    assert_equal 413, last_response.status
  end

  def test_not_found
    get '/articles/999'

    assert_equal 404, last_response.status
  end

  def test_method_not_allowed
    delete '/articles/1'

    assert_equal 405, last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end
end
