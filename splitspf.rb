require 'fileutils'
require 'date'
require 'json'

# ---------------------- LOGGING SETUP

thisscript = File.basename($0)

#hash from json log
def jsonlog_hash()
	json_hash = {}
	return json_hash
end

def logtoJson(log_hash, logkey, logstring)
  #if the logkey is empty we skip writing to the log
  unless logkey.empty?
    #if the logstring is nil or undefined, set logstring to true
    if !defined?(logstring) || logstring.nil?
      logstring = true
    end
    log_hash[logkey] = logstring
  end
rescue => e
  log_hash[logkey] = "LOGGING_ERROR: #{e}"
end

def nameLogFile(dir)
	todaysdate = Date.today
	logdir = File.join(dir, "logs")
	filename = File.join(logdir, "#{todaysdate}_1.json")
	if File.exist?(filename)
		newestfile = Dir.glob("#{logdir}/*.json").max_by {|f| File.mtime(f)}
		counter = newestfile.split('.').first.split('_').last
		counter = counter.to_i + 1
		filename = File.join(dir, "logs", "#{todaysdate}_#{counter}.json")
	end
end

def write_json(hash, file)
  unless ARGV.empty?
    finaljson = JSON.pretty_generate(hash)
    File.open(file, 'w+:UTF-8') { |f| f.puts finaljson }
  end
end

# ---------------------- METHODS

def clearDir(dir, archivedir, logkey='')
	FileUtils.cp Dir["#{dir}/*"].select {|f| test ?f, f}, archivedir
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def splitSPF(file, outputdir, logkey='')
	logstring = file
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

		payee = /(PAYEE:\s+)(\d+)/.match(rename)
		unless payee.nil?
			payee = payee[2]
		else
			payee = "NOPAYEEFOUND"
		end

		author = /(AUTHOR:\s+)(\d+)/.match(rename)
		unless author.nil?
			author = author[2]
		else
			author = "NOAUTHORFOUND"
		end

		isbn = /978\d{10}/.match(rename)
		if isbn.nil?
			isbn = "NOISBNFOUND"
		end

		st1date = /(ROYALTY STATEMENT FOR PERIOD ENDING )(\d*\/\d*)/.match(rename)
		unless st1date.nil?
			st1date = st1date[2]
			st2date = st1date.split("/")
			sdate = st2date.join("-")
		else
			st1date = "NODATEFOUND"
		end

		finalfilename = File.join(outputdir, "#{author}_#{payee}_#{isbn}_#{sdate}.spf")
		FileUtils.mv(tempfile, finalfilename)
	end
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def getSPFArray(dir, logkey='')
	arr = Dir.glob("#{dir}/*.spf")
	logstring = arr.count
	return arr
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def runSwiftConvert(command, inputfile, outputfile, logkey='')
	logstring = inputfile
	`"#{command}" -c"ldoc ""#{inputfile}"" | printer number 1 type MS_WIN command F
	ILE alias ""pdfFactory Pro"" | set filename #{outputfile} | plot 1 all"`
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def applyWatermark(file, watermark, logkey='')
	logstring = file
	`pdftk #{file} multistamp #{watermark} output #{finalfilename} verbose`
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def moveFile(file, dest, logkey='')
	FileUtils.mv(file, dest)
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def convertSPF(arr, cmd, pdfdir, watermark, finaldir, logfile, logkey='')
	arr.each do |c|
		outputfilename = c.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.rpartition('.').first
		outputfilename = "#{outputfilename}.pdf"
		swiftconvert = runSwiftConvert(cmd, c, outputfilename, 'converting_file_to_spf')
		fullpdfpath = File.join(pdfdir, outputfilename, 'converting_file_to_pdf')
		watermarks = applyWatermark(fullpdfpath, watermark, 'watermarking_pdf')
	  moveFile(fullpdfpath, finaldir, 'moving_file_to_finaldir')
	end
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- VARIABLES

input_file = ARGV[0]

stage = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop

royaltiesdir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-3].join(File::SEPARATOR)

spfdir = File.join(royaltiesdir, "temp", stage)

swiftconvcmd = File.join("C:", "Program Files (x86)", "SwiftView", "sview.exe")

pdfdir = File.join("C:", "Users", "padwoadmin", "Documents", "PDF files", "Autosave")

assetsdir = File.join(royaltiesdir, "assets")

if stage == "Final"
	watermark = File.join(assetsdir, "images", "watermark-final.pdf")
else
	watermark = File.join(assetsdir, "images", "watermark-draft.pdf")
end

finaldir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].join(File::SEPARATOR)

finaldir = File.join(finaldir, "done")

archivedir = File.join(royaltiesdir, "archive", stage)

# ---------------------- PROCESSES

logfile = nameLogFile(royaltiesdir)

@log_hash = {}

# remove old files from temp dir
clearDir(spfdir, archivedir, 'archiving_previous_tempfiles')

# remove old files from final dir
clearDir(finaldir, archivedir, 'archiving_previous_finalfiles')

splitSPF(input_file, spfdir, 'splitting_master_spf_file')

spfarr = getSPFArray(spfdir, 'number_of_individual_statements')

convertSPF(spfarr, swiftconvcmd, pdfdir, watermark, finaldir, logfile, 'convert_statements_to_pdf')

# ---------------------- LOGGING

# Write json log:
write_json(@log_hash, logfile)