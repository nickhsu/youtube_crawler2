#!/usr/bin/env ruby

drop_patten = /[\/&$+!"'_.():,-]/

STDIN.each_line do |line|
	next if line.size > 20
	line.gsub!(drop_patten, " ")
end
