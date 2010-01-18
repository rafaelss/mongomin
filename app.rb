require 'sinatra/base'
require 'haml'
require 'mongo'
require 'rack-flash'
require 'logger'
require 'less'

class App < Sinatra::Base
  use Rack::Flash

  enable :sessions

  before do
    if request.path != '/' and (request.path =~ /^\/stylesheets/).nil? and (session[:host].nil? or session[:host].empty?)
      redirect '/'
    end
  end

  get '/database/:name/collection/:collection/document/:id' do
    @database = params['name']
    @collection = params['collection']
    @document = connection.db(@database).collection(@collection).find_one(:_id => params['id'])

    if @document.nil?
      flash[:error] = "Document #{params['id']} does not exists"
      redirect "/database/#{@database}/collection/#{@collection}/documents"
    else
      haml :document
    end
  end

  get '/database/:name/collection/:collection/documents' do
    @database = params['name']
    @collection = params['collection']
    @documents = connection.db(@database).collection(@collection).find
    haml :documents
  end

  get '/database/:name/collections' do
    @database = params['name']
    @collections = connection.db(@database).collection_names.sort
    haml :collections
  end

  # TODO change to 'secure' method (POST or PUT)
  get '/database/:name/collection/:collection/document/:id/drop' do
    connection.db(params['name']).collection(params['collection']).remove(:_id => params['id'])
    redirect "/database/#{params['name']}/collection/#{params['collection']}/documents"
  end

  # TODO change to 'secure' method (POST or PUT)
  get '/database/:name/collection/:collection/drop' do
    connection.db(params['name']).drop_collection(params['collection'])
    redirect "/database/#{params['name']}/collections"
  end

  # TODO change to 'secure' method (POST or PUT)
  get '/database/:name/drop' do
    connection.drop_database(params['name'])
    redirect '/databases'
  end

  get '/databases' do
    @databases = connection.database_names.sort
    haml :databases
  end

  get '/' do
    session.delete(:host)
    session.delete(:port)
    haml :index
  end

  post '/' do
    begin
      conn = connection(params['host'], params['port'])
      if conn.connected?
        redirect '/databases'
      else
        redirect '/'
      end
    rescue => ex
      flash[:error] = ex.message
      redirect '/'
    end
  end

  get '/stylesheets/:name.css*' do
    content_type 'text/css'

    path = File.join(File.expand_path('.'), 'views', 'less', "#{params['name']}.less")
    Less::Engine.new(File.new(path)).to_css
  end

  private

  def stylesheet(name)
    mtime = File.mtime(File.join(File.expand_path('.'), "views", "less", "#{File.basename(name, '.css')}.less")).to_i
    "/stylesheets/#{name}?#{mtime}"
  end

  def connection(host = nil, port = nil)
    session[:host] ||= host
    session[:port] ||= port
    session[:port] = Mongo::Connection::DEFAULT_PORT.to_s if session[:port].empty?
    session[:user] ||= params['user'] if !params['user'].empty?
    session[:password] ||= params['password'] if !params['password'].empty?

    @db ||= Mongo::Connection.new(session[:host], session[:port], :logger => Logger.new(STDOUT))

    if session[:user] and !session[:user].empty?
      @db.authenticate
    end
  end
end