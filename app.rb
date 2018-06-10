#require 'benchmark'
#require 'sinatra/cross_origin'
require 'json'
#require 'fuzzystringmatch'
require 'string/similarity'

class App < Sinatra::Base
  get '/home' do
    redirect '/home?page=1' unless @params["page"]
    redirect "/home?page=#{@params["page"]}" if @params["query"] == ""
    pagina = @params["page"].to_i || 1
    pagina -= 1
    lim_inf = pagina * 5
    lim_sup = (pagina + 1) * 5 - 1
    #p lim_inf, lim_sup
    threads = []
    threads << Thread.new {@authors_list = (JSON.parse(RestClient.get("https://bibliapp.herokuapp.com/api/authors").body))}
    threads << Thread.new {@books_list = JSON.parse(RestClient.get("https://bibliapp.herokuapp.com/api/books").body)}
    threads.each {|thr| thr.join}
    @authors_list ||= []
    @books_list ||= []
    @total_pages = (@authors_list.count / 5.0).ceil
    #p @total_pages
    @authors_list.sort_by! { |k| k["firstName"] } if @params["query"] == "1"
    @authors_list = @authors_list[lim_inf..lim_sup]
    @authors_list ||= []
    #p @books_list
    @grouped_books = @books_list.group_by {|d| d["authorId"]}
    #p @grouped_books
    #p @authors_list
    erb :home
  end
  get '/details/:id' do
    threads = []
    threads << Thread.new {@author = (JSON.parse(RestClient.get("https://bibliapp.herokuapp.com/api/authors/#{@params["id"]}").body))}
    threads << Thread.new {@books = JSON.parse(RestClient.get("https://bibliapp.herokuapp.com/api/authors/#{@params["id"]}/books").body)}
    threads.each {|thr| thr.join}
    #p @params["id"]
    #p @author
    #p @books
    erb :author
  end
  get '/delete_book/:i_author/:i_book' do
    RestClient.delete("https://bibliapp.herokuapp.com/api/authors/#{@params["i_author"]}/books/#{@params["i_book"]}")
    redirect "/details/#{@params["i_author"]}"
  end

  get '/delete_author/:i_author' do
    RestClient.delete("https://bibliapp.herokuapp.com/api/authors/#{@params["i_author"]}")
    redirect '/home'
  end
  get '/create_author' do
    RestClient.post("https://bibliapp.herokuapp.com/api/authors",
                    {
                            :firstName => @params["first_name"],
                            :lastName => @params["last_name"]
                    })
    redirect '/home'
  end

  get '/create_book/:id' do
    RestClient.post("https://bibliapp.herokuapp.com/api/authors/#{@params["id"]}/books",
                    {
                        :title => @params["title"],
                        :isbn => @params["isbn"],
                        :authorId => @params["id"]
                    })
    redirect "/details/#{@params["id"]}"
  end

  get '/search_author' do
    authors_list = (JSON.parse(RestClient.get("https://bibliapp.herokuapp.com/api/authors").body))
    similarity = 0
    index_found = nil
    authors_list.map {|d| [d["firstName"], d["lastName"]].join ' '}.each_with_index do |author, index|
      sim_calc = String::Similarity.cosine @params["search"], author
      if sim_calc > similarity
        similarity = sim_calc
        index_found = index
      end
    end
    #p similarity
    #p author_found
    #p index_found
    #p authors_list
    redirect '/home' unless index_found
    redirect "/details/#{authors_list[index_found]["id"]}"
  end
  get '/edit_author/:id' do
    RestClient.patch("https://bibliapp.herokuapp.com/api/authors/#{@params["id"]}",
                    {
                        :firstName => @params["name"],
                        :lastName => @params["surname"]
                    })
    redirect "/details/#{@params["id"]}"
  end
  get '/delete_author_books/:id' do
    RestClient.delete("https://bibliapp.herokuapp.com/api/authors/#{@params["id"]}/books")
    redirect "/details/#{@params["id"]}"
  end
  error do
    redirect '/home'
  end
  not_found do
    redirect '/home'
  end
end