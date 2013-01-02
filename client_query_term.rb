#!/usr/bin/env ruby

require 'typhoeus'
require 'json'
require 'logger'
require 'cgi'
require 'mongo'

#parsing command line

if ARGV.first.nil?
	p "usage: insert_term_list.rb config_file_path"
	exit
else
	config_file_path = ARGV.first
	config = JSON.parse(File.open(config_file_path).read)
end

# make mongodb connection

include Mongo

mongo_client = MongoClient.new(config["server"], config["port"], :pool_size => config["numThread"])
mongo_client.add_auth(config["db"], config["username"], config["password"])
db = mongo_client.db(config["db"])

# helper function

def get_search_video_url(args)
	url = "http://gdata.youtube.com/feeds/api/videos?"
	args.each_pair { |k, v| url += "&#{k.to_s}=#{CGI::escape(v.to_s)}" }

		return url
end

def parse_json(data)
	# mongodb key 不能 '$' 開頭，換成 '_'
	data.gsub!("\"$t\"", "\"_t\"")
	JSON.parse(data)
end

def	query_by_term(term) 
	entries = []
	need_sleep = false

	url = get_search_video_url("q" => term, "max-results" => 50, "alt" => "json")
	data = Typhoeus::Request.new(url, :method => :get).run.body
	json = parse_json(data)
	entries += json['feed']['entry'] if json['feed']['entry']

	num_entries = json["feed"]["openSearch$totalResults"]["_t"]
	num_entries = 1000 if num_entries > 1000
	if num_entries > 50
		num_entries -= 1
		num_entries_pages = num_entries / 50
		(1..num_entries_pages).each do |i|
			url = get_search_video_url("q" => term, "max-results" => 50, "alt" => "json", "start-index" => 50 * i + 1)
			req = Typhoeus::Request.new(url, :method => :get)
			req.on_complete do |res|
				data = res.body
				if data.index("too_many_recent_calls")
					need_sleep = true
				elsif data.index("Internal Error")
				else
					json = parse_json(data)
					entries += json['feed']['entry'] if json['feed']['entry']
				end
			end
			req.run
		end
	end

	return need_sleep, entries
end

# main code
	
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
threads = []
entry_file = File.open(config["entryFilePath"], "a+")

config["numThread"].times do
	threads << Thread.new do
		while true	
			term = db["terms"].find_one({"isQueried" => false}, {:skip => Random.rand(10000), :fields => "term"})
			break if term.nil?

			need_sleep, entries = query_by_term(term["term"])

			entries.each do |e|
				video_id = e['id']['_t'].split('/')[-1]
				e['video_id'] = video_id
				entry_file.puts e.to_json
			end

			logger.info "query key = #{term['term']}, total_results = #{entries.size}"

			if need_sleep
				logger.info "sleep..."
				sleep(120)
			else
				db['terms'].update({"_id" => term["_id"]}, {"$set" => {"isQueried" => true}}).inspect
			end
		end
	end
end

threads.each do |t|
	t.join
end
