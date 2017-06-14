require 'fileutils'
require 'date'

# ---------------------- METHODS

def clearDir(dir, archivedir)
	FileUtils.cp Dir["#{dir}/*"].select {|f| test ?f, f}, archivedir
end

def nameLogFile(dir)
	todaysdate = Date.today
	logdir = File.join(dir, "logs")
	filename = File.join(logdir, "#{todaysdate}_1.txt")
	if File.file? filename 
		newestfile = Dir.glob("#{logdir}/*.txt").max_by {|f| File.mtime(f)}
		counter = newestfile.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.rpartition('.').first.split('_').last
		counter = counter + 1
		filename = File.join(dir, "logs", "#{todaysdate}_#{counter}.txt")
	end
rescue
	filename = "log.txt"
ensure
	return filename
end

def splitSPF(file, outputdir)
	s = File.binread(file)
	bits = s.unpack("B*")[0]
	counting = bits.scan(/010100000110000101100111011001010010000000110001/)
	counting.each.with_index(1) do |c, i|
		content = File.binread(file)
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
		tempfile = File.join(outputdir, "temp#{i}.spf")
		File.open(tempfile, 'wb') do |output| 
			output.write [stripend.gsub(/(00011011001001100110110000110001010011110000110100001010000011000000110100001010)((.+?000011000000110100001010){#{m}})/, "00011011001001100110110000110001010011110000110100001010")].pack("B*")
		end
		# rename the files based on the statement data
		rename = File.binread(tempfile)
		payee = /(PAYEE:\s+)(\d+)/.match(rename)[2]
		author = /(AUTHOR:\s+)(\d+)/.match(rename)[2]
		isbn = /978\d{10}/.match(rename)
		st1date = /(ROYALTY STATEMENT FOR PERIOD ENDING )(\d*\/\d*)/.match(rename)[2]
		st2date = st1date.split("/")
		sdate = st2date.join("-")
		finalfilename = File.join(outputdir, "#{author}_#{payee}_#{isbn}_#{sdate}.spf")
		FileUtils.mv(tempfile, finalfilename)
	end
end

def getSPFArray(dir)
	Dir.glob("#{dir}/*.spf")
end

def runSwiftConvert(command, inputfile, outputfile)
	logoutput = `"#{command}" -c"ldoc ""#{inputfile}"" | printer number 1 type MS_WIN command F
	ILE alias ""pdfFactory Pro"" | set filename #{outputfile} | plot 1 all"`
rescue
	logoutput = "ERROR running SwiftConvert on file #{inputfile}"
ensure
	return logoutput
end

def applyWatermark(file, watermark)
	logoutput = `pdftk #{file} multistamp #{watermark} output #{finalfilename} verbose`
rescue
	logoutput = "ERROR applying watermark to file #{inputfile}"
ensure
	return logoutput
end

def logOutput(logfile, logdata)
	File.open(logfile, 'a+') do |output|
    output.write logdata
  end
end

def convertSPF(arr, watermark, finaldir, logfile)
	arr.each do |c|
		outputfilename = c
		swiftconvert = runSwiftConvert(swiftconvcmd, c, outputfilename)
		watermarks = applyWatermark(outputfilename, watermark)
		FileUtils.cp(outputfilename, finaldir)
		logOutput(logfile, "#{swiftconvert}, #{watermarks}")
	end
end

# ---------------------- VARIABLES

input_file = ARGV[0]

stage = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2]

royaltiesdir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-3].join(File::SEPARATOR)

spfdir = File.join(royaltiesdir, "temp", stage)

assetsdir = File.join(royaltiesdir, "assets")

if stage == "final"
	watermark = File.join(assetsdir, "images", "watermark-final.pdf")
else
	watermark = File.join(assetsdir, "images", "watermark-draft.pdf")
end

finaldir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].join(File::SEPARATOR)

finaldir = File.join(finaldir, "done")

# ---------------------- PROCESSES

logfile = nameLogFile(royaltiesdir)

# remove old files from temp dir
clearDir(spfdir, archivedir)

# remove old files from final dir
clearDir(finaldir, archivedir)

splitSPF(input_file)

spfarr = getSPFArray(spfdir)

convertSPF(spfarr, watermark, finaldir, logfile)