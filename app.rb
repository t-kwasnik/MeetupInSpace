require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'omniauth-github'

require_relative 'config/application'

Dir['app/**/*.rb'].each { |file| require_relative file }

helpers do
  def current_user
    user_id = session[:user_id]
    @current_user ||= User.find(user_id) if user_id.present?
  end

  def signed_in?
    current_user.present?
  end
end

def set_current_user(user)
  session[:user_id] = user.id
end

def authenticate!
  unless signed_in?
    flash[:notice] = 'You need to sign in if you want to do that!'
    redirect '/'
  end
end

def registered?
  result = UsersAtMeetup.where("user_id = ? AND meetup_id = ?", session[:user_id], params[:meetup_id])
  result == [] ? false : true
end


get '/' do
  redirect  "/meetups"
end

get '/auth/github/callback' do
  auth = env['omniauth.auth']

  user = User.find_or_create_from_omniauth(auth)
  set_current_user(user)
  flash[:notice] = "You're now signed in as #{user.username}!"

  redirect '/'
end

get '/sign_out' do
  session[:user_id] = nil
  flash[:notice] = "You have been signed out."

  redirect '/'
end

get '/meetups' do

  @all_meetups = Meetup.all.order("lower(name)")
  erb :meetups
end

get '/meetups/:meetup_id' do

  signed_in? ? @registered = registered? : @registered = false

  @meetup = Meetup.find(params[:meetup_id])

  @attending = @meetup.users
  @comments = @meetup.comments

  erb :meetup
end

get '/new' do
  authenticate!
  erb :create_meetup
end

post '/new' do
  Meetup.create(name: params[:name], description: params[:description], location: params[:location])
  id = Meetup.where(name: params[:name]).first.id
  flash[:notice] = "Meetup successfully created!"
  redirect "/meetups/#{id}"
end

post '/registration' do
  if signed_in?
    if registered?
      UsersAtMeetup.where(meetup_id: params[:meetup_id], user_id: params[:user_id]).destroy_all
      flash[:notice] = "Unregistered from Meetup!"
    else
      UsersAtMeetup.create(meetup_id: params[:meetup_id], user_id: params[:user_id])
      flash[:notice] = "Meetup successfully joined!"
    end
  else
    flash[:notice] = "You must sign in to join!"
  end
  redirect "/meetups/#{params[:meetup_id]}"
end

post "/add_comment" do
  authenticate!
  Comment.create(user_id: current_user.id, meetup_id: params[:meetup_id], body: params[:body])
  redirect "/meetups/#{params[:meetup_id]}"
end


