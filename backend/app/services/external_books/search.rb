module ExternalBooks
  class Search
    class SearchError < StandardError
    end
    def self.call(query:)

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

      if response.code == "429" || response.code == "500" || response.code == "503"
        raise ExternalBooks::Search::SearchError
      end
  
      data = JSON.parse(response.body)

      arr = []

      data["items"].each do |item|
          title = item["volumeInfo"]["title"]
          authors = item["volumeInfo"]["authors"]

          if title.present?
            arr << { title: title, author: authors.present? ? authors.join("・") : nil}
          end
      end

      arr
    end
  end
end