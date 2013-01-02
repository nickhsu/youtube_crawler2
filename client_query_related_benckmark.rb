#!/usr/bin/env ruby

require 'typhoeus'
require 'json'
require 'logger'
require 'cgi'
require 'mongo'
require 'benchmark'
require "leveldb"

#parsing command line

if ARGV.first.nil?
	p "usage: client_query_related.rb config_file_path"
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

def get_related_video_url(video_id, args)
	url = "http://gdata.youtube.com/feeds/api/videos/#{video_id}/related?"
	args.each_pair { |k, v| url += "&#{k.to_s}=#{CGI::escape(v.to_s)}" }
	
	return url
end

# main code

logger = Logger.new(STDOUT)
logger.level = Logger::INFO
threads = []
entry_file = File.open(config["entryFilePath"], "a+")
leveldb = LevelDB::DB.new "./data/cache"

config["numThread"].times do
	threads << Thread.new do 
		hydra = Typhoeus::Hydra.new(:max_concurrency => 50)
		while true
			entries = []
			need_sleep = false
			
			video_id_need_query = db["entries"].find({"isQueriedRelated" => false}, {:skip => Random.rand(1000000), :limit => 10, :fields => "video_id"}).map{ |e| e["video_id"]}
			video_id_need_query.each do |video_id|
				url = get_related_video_url(video_id, {"max-results" => 50, "alt" => "json"})
				req = Typhoeus::Request.new(url, :method => :get)
				req.on_complete do |res|
					data = res.body
					if data.index("too_many_recent_calls") or data.index("Internal Error")
						need_sleep = true
					elsif data.index("Parent Video not found")
					else
						# mongodb key 不能 '$' 開頭，換成 '_'
						data.gsub!("\"$t\"", "\"_t\"")
						json = JSON.parse(data)
						entries += json['feed']['entry'] if json['feed']['entry']
					end
				end
				hydra.queue req
			end

			logger.info "query related video_id = #{video_id_need_query}"
			
			puts Benchmark.measure { hydra.run }

			video_id_list = entries.map { |e| e['id']['_t'].split('/')[-1] }
			puts "--"
			#puts Benchmark.measure { db['entries'].find({"video_id" => {"$in" => video_id_list}}, {:fields => "video_id"}).map{|e| e["video_id"]} }
			video_id_exist = db['entries'].find({"video_id" => {"$in" => video_id_list}}, {:fields => "video_id"}).map{|e| e["video_id"]}
			puts Benchmark.measure {
				list = []
				video_id_list.each do |video_id|
					list << video_id if leveldb.includes? video_id
				end

				puts video_id_exist.count
				puts list.count
			}
			exit
			video_id_exist = db['entries'].find({"video_id" => {"$in" => video_id_list}}, {:fields => "video_id"}).map{|e| e["video_id"]}
			
			
			video_id_need_insert = video_id_list - video_id_exist
			puts Benchmark.measure {
			entries.each do |e|
				video_id = e['id']['_t'].split('/')[-1]
				e['video_id'] = video_id
				e['isQueriedRelated'] = false
				entry_file.puts e.to_json if video_id_need_insert.include? video_id
			end
			}


			#db['entries'].update({"video_id" => {"$in" => video_id_need_query}}, {"$set" => {"isQueriedRelated" => true}})

			if need_sleep
				logger.info "sleep..."
				sleep(120)
			end
		end
	end
end

threads.each do |t|
	t.join
end
