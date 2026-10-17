module ExternalBooks
  class Search
    def self.call(query:)
      puts query

      uri = URI("https://www.googleapis.com/books/v1/volumes")

      uri.query = URI.encode_www_form(
        q: query,
        maxResults: 5,
        key: ENV.fetch("BOOKS_API_KEY")
      )

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 2,
        read_timeout: 5
      ) do |http|
        http.get(uri.request_uri)
      end

      data = JSON.parse(response.body)

      arr = []

      data["items"].each do |item|
          title = item["volumeInfo"]["title"]
          authors = item["volumeInfo"]["authors"]

          arr << { title: title, author: authors.join("・") }

          arr.push()
      end

      arr
    end
  end
end