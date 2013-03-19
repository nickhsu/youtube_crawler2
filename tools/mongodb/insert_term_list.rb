#!/usr/bin/env ruby

require 'mongo'
require 'json'
require 'logger'

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

mongo_client = MongoClient.new(config["server"], config["port"])
mongo_client.add_auth(config["db"], config["username"], config["password"])
db = mongo_client.db(config["db"])

# main code

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
data = []
STDIN.each_line do |line|
	data << { 
		"term" => line.chomp,
		"isQueried" => false
	}
	if data.count % 10000 == 0
		db["terms"].insert(data)
		logger.info "insert terms"
		data = []
	end
end
db["terms"].insert(data)
