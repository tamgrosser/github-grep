require 'cgi'
require 'json'

def usage
  puts <<-TEXT.gsub(/^    /, "")
    Setup
    -----
    # create a new token at https://github.com/settings/tokens/new with repo access
    git config github.token NEW_TOKEN --local

    Usage
    -----
    #{$0} 'something to search for'
  TEXT
  exit 1
end

def code_items_to_lines(items)
  items.flat_map do |item|
    file = item.fetch('repository').fetch('name') + ":" + item.fetch('path')
    lines(item).map { |l| "#{file}: #{l}" }
  end
end

def issue_items_to_lines(items)
  items.flat_map do |item|
    number = item.fetch("number")
    lines(item).map { |l| "##{number}: #{l}" }
  end
end

def lines(item)
  item.fetch("text_matches").flat_map { |match| match.fetch('fragment').split("\n") }
end

def search(q, type)
  per_page = 100
  page = 1

  loop do
    response = page(q, type, page, per_page)
    if page == 1
      $stderr.puts "Found #{response.fetch("total_count")}"
    else
      $stderr.puts "Page #{page}"
    end

    items = response.fetch('items')
    yield items

    break if items.size < per_page
    page += 1
  end
end

def page(q, type, page, per_page)
  github_token = `git config github.token`.strip
  usage if github_token.empty?

  url = "https://api.github.com/search/#{type}?per_page=#{per_page}&page=#{page}&q=#{CGI.escape(q)}"
  command = "curl --silent --fail -H 'Authorization: token #{github_token}' -H 'Accept: application/vnd.github.v3.text-match+json' '#{url}'"
  response = `#{command}`
  raise "ERROR Request failed, reply was: #{response.inspect}" unless $?.success?

  JSON.load(response)
end

type = (ARGV.delete('--issues') ? :issues : :code)

q = ARGV.shift
usage if ARGV.size != 0

search(q, type) do |items|
  if type == :issues
    puts issue_items_to_lines(items)
  else
    puts code_items_to_lines(items)
  end
end
