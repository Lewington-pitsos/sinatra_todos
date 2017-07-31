require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"

configure do
  set :erb, :escape_html => true
end

configure do
  enable :sessions
  set :session_secret, "secret"
  use Rack::Session::Cookie, key: 'rack.session',
                         path: '/',
                         secret: 'secret'
end

before do
  session[:lists] ||= []
  session[:ids] ||= []
end

# View all lists
get "/lists" do
  @lists = session[:lists].sort_by {|lst| complete?(lst) ? 1 : 0}


  erb :lists, layout: :layout
end

get "/" do
  redirect "/lists"
end

# renders new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

def check name
  unless session[:ids].include?(name)
    session[:error] = "That list isn't #{name}."
    redirect "/lists"
  end
end

def find_list name
  session[:lists].each do |list|
    return list if list[:id] == name
  end
end

get "/lists/:id" do

  check params[:id]

  @list = find_list params[:id]
  @name = @list[:name]
  @todos = @list[:todos]

  erb :single_list, layout: :layout
end

get "/lists/:id/edit" do
  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]

  @current_name = @list[:name]
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

def todo_error(name, list)
  if !(1..100).cover?(name.length)
    "You are terrible, choose a name that isn't dumb."
  elsif @list[:todos].any? { |pair| pair[:name] == name }
    "That name is already taken. Choose another."
  end
end

def new_id
  id = (("A".."Z").to_a.sample(3) + (0..9).to_a.sample(3)).join
  return new_id if session[:ids].include?(id)
  session[:ids] << id
  id
end

# actually creates a new list in the session
post "/lists" do
  name = params[:list_name].strip
  error = error_occured(name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = new_id
    session[:lists] << { name: name, todos: [], finished: 0, id: id }
    session[:success] = "You made a list. Whoop de doo."
    redirect "/lists"
  end
end

post "/lists/:id" do

  check params[:id]

  @list = find_list params[:id]


  name = params[:list_name].strip
  error = error_occured(name)
  @current_name = @list[:name]
  if error
    session[:error] = error

    erb :edit, layout: :layout
  else
    @list[:name] = name
    session[:success] = "You changed the list's name."
    redirect "/lists/#{params[:id]}"
  end
end

# delete a list
post "/lists/:id/delete" do

  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]


  session[:lists].delete(@list)
  session[:ids].delete(params[:id])
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "Successfully deleted"
    redirect "/lists"
  end
end

# create a new todo
post "/lists/:id/todos" do
  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]

  error = todo_error(params[:todo].strip, @list)
  @todos = @list[:todos]
  if error
    session[:error] = error
    @name = @list[:name]
    redirect "/lists/#{@id}"
  else
    @todos << {name: params[:todo], completed: false}
    session[:success] = "Todo Added"
    redirect "/lists/#{@id}"
  end
end

#delete a todo
post "/lists/:id/:name/delete" do
  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]

  todos = @list[:todos]
  todos.delete_if {|hash| params[:name] == hash[:name] }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo deleted"
    redirect "/lists/#{params[:id]}"
  end
end

#toggle a todo
post "/lists/:id/:name/toggle" do
  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]


  todos = @list[:todos]
  todos.each do |hash|
    if hash[:name] == params[:name]
      value = eval(params[:completed])
      hash[:completed] = value
      if value
        @list[:finished] += 1
      else
        @list[:finished] -= 1
      end
    end
  end
  redirect "/lists/#{params[:id]}"
end

# mark all todoes as done
post "/lists/:id/check-all" do
  check params[:id]

  @list = find_list params[:id]

  @id = params[:id]

  todos = @list[:todos]
  todos.each do |hash|
    hash[:completed] = true
  end
  @list[:finished] = todos.length
  redirect "/lists/#{params[:id]}"
end

# -----------------------------------HELPERS --------------------------------#

helpers do
  def complete? list
    list[:finished] == list[:todos].length && list[:todos].length > 0
  end

  def list_class list
    complete?(list) ? "complete" : ""
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

  def h(content)
    Rack::Utils.escape_html(content)
  end
end
