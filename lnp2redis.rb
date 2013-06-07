#!/usr/bin/ruby

##
# Run it in concole like this:
# ruby lnp2redis.rb <input_file> | redis-cli --pipe
#

require 'csv'

def gen_redis_proto(*cmd)
    proto = ""
    proto << "*"+cmd.length.to_s+"\r\n"
    cmd.each{|arg|
        proto << "$"+arg.to_s.bytesize.to_s+"\r\n"
        proto << arg.to_s+"\r\n"
    }
    proto
end

ARGV.each do |file|
        if File.exists?(file)
                CSV.foreach(file, {:col_sep => '|', :headers => false, :row_sep => :auto, :skip_blanks => true, :converters => lambda {|x| x.to_i }}) do |row|
                        unless row[1] == '' || row[2] == '' || row[1].nil? || row[2].nil? || row[1] == 0 || row[2] == 0
                                STDOUT.write(gen_redis_proto("SET","#{row[1]}","#{row[2]}"))
                        end     
                end
                STDOUT.write(gen_redis_proto("SAVE"))
        end
end
