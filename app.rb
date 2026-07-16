# frozen_string_literal: true

require 'erb'
require 'sinatra/base'
require 'thread'
require 'uri'

class DummyBlog < Sinatra::Base
  MAX_BODY_SIZE = 16 * 1024
  INITIAL_ARTICLES = [
    { id: 1, title: 'HTTPを手で話してみよう', body: "このブログはHTTPの学習用です。\ntelnetでリクエストを送ってみましょう。" },
    { id: 2, title: 'GETとPOST', body: "GETで記事を読み、POSTで新しい記事を作れます。\nレスポンスのステータスとヘッダーにも注目してください。" },
    { id: 3, title: 'データについて', body: '投稿はメモリだけに保存されるため、Dynoが再起動すると初期状態に戻ります。' }
  ].freeze

  configure do
    set :articles, INITIAL_ARTICLES.map(&:dup)
    set :articles_mutex, Mutex.new
    set :show_exceptions, false
    set :raise_errors, false
  end

  helpers do
    def h(value)
      ERB::Util.html_escape(value)
    end

    def article_body(value)
      h(value).gsub("\n", '<br>')
    end

    def find_article(id)
      settings.articles_mutex.synchronize do
        settings.articles.find { |article| article[:id] == id }.then(&:dup)
      end
    end
  end

  before do
    content_type 'text/html', charset: 'utf-8'
  end

  get '/' do
    redirect '/articles'
  end

  get '/articles' do
    @articles = settings.articles_mutex.synchronize { settings.articles.map(&:dup) }
    erb :index
  end

  get '/articles/new' do
    erb :new
  end

  get '/articles/:id' do
    pass unless params[:id].match?(/\A\d+\z/)

    @article = find_article(params[:id].to_i)
    halt 404, erb(:not_found) unless @article
    erb :show
  end

  post '/articles' do
    halt 400, erb(:bad_request, locals: { message: 'Content-Type must be application/x-www-form-urlencoded.' }) unless request.media_type == 'application/x-www-form-urlencoded'

    content_length = request.content_length
    halt 413, erb(:too_large) if content_length && content_length.to_i > MAX_BODY_SIZE

    request.body.rewind
    body = request.body.read(MAX_BODY_SIZE + 1).to_s
    halt 413, erb(:too_large) if body.bytesize > MAX_BODY_SIZE

    begin
      form = URI.decode_www_form(body, Encoding::UTF_8).to_h
    rescue ArgumentError
      halt 400, erb(:bad_request, locals: { message: 'The form data is invalid.' })
    end

    title = form['title']&.strip
    article_body = form['body']&.strip
    if title.nil? || title.empty? || article_body.nil? || article_body.empty?
      halt 400, erb(:bad_request, locals: { message: 'Title and body are required.' })
    end

    @article = settings.articles_mutex.synchronize do
      article = { id: settings.articles.last[:id] + 1, title: title, body: article_body }
      settings.articles << article
      article.dup
    end

    status 201
    headers 'Location' => "/articles/#{@article[:id]}"
    erb :show
  end

  %w[delete patch put].each do |method|
    send(method, %r{/articles(?:/.*)?}) do
      headers 'Allow' => 'GET, POST'
      halt 405, erb(:method_not_allowed)
    end
  end

  post %r{/articles/.+} do
    headers 'Allow' => 'GET'
    halt 405, erb(:method_not_allowed)
  end

  not_found do
    erb :not_found
  end

  error do
    status 500
    erb :server_error
  end
end
