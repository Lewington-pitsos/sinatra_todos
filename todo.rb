require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, "secret"
  use Rack::Session::Cookie, key: 'rack.session',
                         path: '/',
                         secret: 'secret'
end

before do
  session[:lists] ||= []
end

# View all lists
get "/lists" do
  @lists = session[:lists]


  erb :lists, layout: :layout
end

get "/" do
  redirect "/lists"
end

# renders new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

get "/lists/:number" do
  @list = session[:lists][params[:number].to_i]
  @name = @list[:name]
  @todos = @list[:todos]

  erb :single_list, layout: :layout
end

get "/lists/:number/edit" do
  @current_name = session[:lists][params[:number].to_i][:name]
  erb :edit, layout: :layout
end

# ---------------------------------POST ------------------------------------- #

def error_occured(name)
  if !(1..100).cover?(name.length)
    "You are terrible, choose a name that isn't dumb."
  elsif session[:lists].any? { |lst| lst[:name] == name }
    "That name is already taken. Choose another."
  end
end

def todo_error(name, id)
  if !(1..100).cover?(name.length)
    "You are terrible, choose a name that isn't dumb."
  elsif session[:lists][id][:todos].any? { |pair| pair[:name] == name }
    "That name is already taken. Choose another."
  end
end

# actually creates a new list in the session
post "/lists" do
  name = params[:list_name].strip
  error = error_occured(name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: name, todos: [], finished: 0 }
    session[:success] = "You made a list. Whoop de doo."
    redirect "/lists"
  end
end

post "/lists/:number" do
  name = params[:list_name].strip
  error = error_occured(name)
  @current_name = session[:lists][params[:number].to_i][:name]
  if error
    session[:error] = error

    erb :edit, layout: :layout
  else
    session[:lists][params[:number].to_i][:name] = name
    session[:success] = "You changed the list's name."
    redirect "/lists/#{params[:number]}"
  end
end

# delete a list
post "/lists/:number/delete" do
  session[:lists].delete_at(params[:number].to_i)
  session[:success] = "Successfully deleted"
  redirect "/lists"
end

# create a new todo
post "/lists/:number/todos" do
  error = todo_error(params[:todo].strip, params[:number].to_i)
  @todos = session[:lists][params[:number].to_i][:todos]
  if error
    session[:error] = error
    @name = session[:lists][params[:number].to_i][:name]
    redirect "/lists/#{params[:number]}"
  else
    @todos << {name: params[:todo], completed: false}
    session[:success] = "Todo Added"
    redirect "/lists/#{params[:number]}"
  end
end

#delete a todo
post "/lists/:number/:name/delete" do
  list = session[:lists][params[:number].to_i][:todos]
  list.delete_if {|hash| params[:name] == hash[:name] }
  session[:success] = "Todo deleted"
  redirect "/lists/#{params[:number]}"
end

#toggle a todo
post "/lists/:number/:name/toggle" do
  list = session[:lists][params[:number].to_i][:todos]
  list.each do |hash|
    if hash[:name] == params[:name]
      value = eval(params[:completed])
      hash[:completed] = value
      if value
        session[:lists][params[:number].to_i][:finished] += 1
      else
        session[:lists][params[:number].to_i][:finished] -= 1
      end
    end
  end
  redirect "/lists/#{params[:number]}"
end

# mark all todoes as done
post "/lists/:number/check-all" do
  list = session[:lists][params[:number].to_i][:todos]
  list.each do |hash|
    hash[:completed] = true
  end
  session[:lists][params[:number].to_i][:finished] = list.length
  redirect "/lists/#{params[:number]}"
end

# -----------------------------------HELPERS --------------------------------#

helpers do
  def complete? list
    list[:finished] == list[:todos].length && list[:todos].length > 0
  end

  def list_class list
    if complete?(list)
      "complete"
    else
      nil
    end
  end

  def sort_lists list
    nlist = list.sort_by {|lst| complete?(lst) ? 1 : 0}
    nlist.each do |entry|
      ind = list.index(entry)
      yield(entry, ind)
    end

  end

  def sort_todos todos
    todos = todos.sort_by{ |item| item[:completed] ? 1 : 0 }

    todos.each_with_index do |i, ind|
      yield i, ind
    end

  end
end
