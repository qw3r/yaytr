require 'open3'
require 'fileutils'
columns = %x[tput cols].strip.to_i
File.open('list', 'r').each_line do |line|
	begin
		next if line.strip! =~ /^$/
		f, a, t = line.split "\t\t"
		t.strip!
		STDOUT.sync = true
		Open3.popen3 "youtube-dl #{f}" do |i,o,e|
			o.sync = e.sync = true
			o.each("\r") do |line|
				#"\"[download]  15.0% of 53.16M at    9.28M/s ETA 00:04 \\r\"
		  	if line =~ /download\]\s+(\d+\..*ETA\s+\d+:\d{1,2}\s)/
		  		print "\r#{a} - #{t} [downloading: #{$1.strip}]".ljust(columns - 2)
		  	end
			end
		end unless File.exists?("#{f}.mp4") or File.exists?("#{f}.flv")
		f << (File.exist?("#{f}.mp4") ? '.mp4' : '.flv')
		if File.exists? f
			o = "done/#{Time.now.strftime('%Y-%m-%d')}/#{a} - #{t}.mp3"
			d = File.dirname o
			FileUtils.mkdir_p(d) unless Dir.exists?(d)
			unless File.exists? o
				duration = nil
				progress = 0
				Open3.popen3(%[ffmpeg -y -i #{f} -ab 128k "#{o}" 2>&1]) do |i,o,e|
					o.sync = true
    			o.each("\r") do |line|
    				# Duration: 00:03:29.70
    				if duration.nil?
      				if line.strip! =~ /duration:\s*(\d+):(\d+):(\d+)\.(\d{2}),/mi
        				duration = (($1.to_i * 60 + $2.to_i) * 60 + $3.to_i) * 10 + $4.to_i
      				end
      			end
      			if line =~ /time=(\d+).(\d+)/
        			if not duration.nil? and duration != 0
          			p = ($1.to_i * 10 + $2.to_i) * 100 / duration
        			else
          			p = 0
        			end
        			p = 100 if p > 100
        			if progress != p
          			progress = p
          			print "\r#{a} - #{t} [downloading: OK, converting: #{progress}%]".ljust(columns - 2)
        			end
      			end
    			end
    		end
    		%x|id3tag --artist="#{a}" --song="#{t}" --comment="#{f[0..-5]}" "#{o}"|
				print "\r#{a} - #{t} [downloading: OK, converting: OK   ... SAVED :)]".ljust(columns - 2)
    	else
    		print "\r#{a} - #{t} [downloading: OK, converting: FAILED, output already exists!]".ljust(columns - 2)
    	end
		else
			print "\r#{a} - #{t} [downloading: failed]"
		end
	rescue
		print " ... Houston, something wrong! :("
		next
	ensure
		puts
	end
end
