#! /usr/bin/env ruby

require 'yajl/json_gem'
require 'leveldb'

if ARGV.count != 1
	puts "./import.rb db_path"
	exit
else
	db_path = ARGV.first
end

db = LevelDB::DB.new(db_path)

STDIN.each_line do |line|
	data = JSON.parse(line)
	data.delete("_id") if data['_id']
	db[data['video_id']] = data.to_json
end
