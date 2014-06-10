# splitspf.rb
input_file = ARGV[0]
s = File.binread(input_file)
bits = s.unpack("B*")[0]
counting = bits.scan(/010100000110000101100111011001010010000000110001/)
counting.each.with_index(1) do |c, i|
	content = File.binread(input_file)
	contentbits = content.unpack("B*")[0]
	# select everything up to the i+1th Page 1, for all but the last statement
	unless i == counting.size
		j = i+1
		sloppystripend = /(00011011001001100110110000110001010011110000110100001010000011000000110100001010)((.*?010100000110000101100111011001010010000000110001){#{j}})/.match(contentbits).to_s
		stripend = /(00011011001001100110110000110001010011110000110100001010000011000000110100001010)(.+000011000000110100001010)/.match(sloppystripend).to_s
		subsection = /(000011000000110100001010)((.*?010100000110000101100111011001010010000000110001){#{i}})/.match(stripend).to_s
	else
	# the last statement has no following content, so adjusting accordingly
		stripend = contentbits
		subsection = /(000011000000110100001010)((.*?010100000110000101100111011001010010000000110001){#{i}})/.match(contentbits).to_s
	end
	# selects everything up to the ith Page 1
	subcounting = subsection.scan(/0010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000101000001100001011001110110010100100000/)
	# puts subcounting.length
	m = subcounting.length-1
	File.open("temp#{i}.spf", 'wb') do |output| 
		output.write [stripend.gsub(/(00011011001001100110110000110001010011110000110100001010000011000000110100001010)((.+?000011000000110100001010){#{m}})/, "00011011001001100110110000110001010011110000110100001010")].pack("B*")
	end
	# rename the files based on the statement data
	rename = File.binread("temp#{i}.spf")
	payee = /(PAYEE:\s+)(\d+)/.match(rename)[2]
	author = /(AUTHOR:\s+)(\d+)/.match(rename)[2]
	isbn = /978\d{10}/.match(rename)
	st1date = /(ROYALTY STATEMENT FOR PERIOD ENDING )(\d*\/\d*)/.match(rename)[2]
	st2date = st1date.split("/")
	sdate = st2date.join("-")
	`copy temp#{i}.spf #{author}_#{payee}_#{isbn}_#{sdate}.spf`
	`DEL temp#{i}.spf`
end
