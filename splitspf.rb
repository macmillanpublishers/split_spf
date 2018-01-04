require 'fileutils'
require 'date'
require 'json'

# ENHANCEMENTS: once we are given an I/O method for this we may want to add an Outfolder with the inputfilename,
# with maybe a txtfile that shows how many statements were found, and how many pdfs output.
# May also want to add a cleanup for outfolders, archive folder, etc
# also, looks like we may no longer need pdffactory since we are generating pdfs direct from spfviewer-Convert

# ---------------------- LOGGING SETUP

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
	return filename
end

def write_json(json, file)
  finaljson = JSON.pretty_generate(json)
  File.open(file, 'w+:UTF-8') { |f| f.puts finaljson }
end

# ---------------------- METHODS

def clearDir(dir, logkey='')
	FileUtils.rm Dir["#{dir}/*"].select {|f| test ?f, f}
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def archiveDir(dir, archivedir, logkey='')
	FileUtils.cp Dir["#{dir}/*"].select {|f| test ?f, f}, archivedir
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def splitSPF(file, outputdir, logkey='')
	logstring = file
	filecontents = File.binread(file)
	contentbits = filecontents.unpack("B*")[0]
	counting = contentbits.scan(/01010000011000010110011101100101001000000011000100001101/)
	# puts counting.length(), # debug
	logtoJson(@log_hash, 'breaks_detected', counting.length())

	counting.each.with_index(1) do |c, i|
		puts c, i # debug
		unless i == counting.size
			# grab first record - first bit group represents beginning of file ("\e&l1O\r\n\f\r\n"), second is end of page 1 of second record "Page 1\r"
			sloppy_firstrecord_bits = /(00011011001001100110110000110001010011110000110100001010000011000000110100001010)(..*?01010000011000010110011101100101001000000011000100001101){2}/.match(contentbits).to_s
			# from the last match, capture from beginning of 1st record to beginning of second record (bits equivalent to "\r\n\f\r\n")
			firstrecord_bits = /(0000110100001010000011000000110100001010)(.+0000110100001010000011000000110100001010)/.match(sloppy_firstrecord_bits)[2].to_s
			# update content (rm firstrecord_bits from the file)
			contentbits = contentbits.sub(/#{firstrecord_bits}/,"")
		else
			# last record, just grab from beginning of record to end of file
			firstrecord_bits = /(0000110100001010000011000000110100001010)(.*)/.match(contentbits)[2].to_s
		end
		# insert header bits and convert back to bin as we write
		firstrecord = [firstrecord_bits.gsub(/\A/,"00011011001001100110110000110001010011110000110100001010")].pack("B*")

		# write to temp file
		tempfile = File.join(outputdir, "temp#{i}.spf")
		File.open(tempfile, 'wb') do |output|
			output.write firstrecord
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
		# finalfilename = File.join(outputdir, "#{author}_#{payee}_#{isbn}_#{sdate}_#{i}.spf") # debug
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
	`"#{command}" -c"ldoc ""#{inputfile}"" | save PDF all #{outputfile} onefile"`
	# old cmd: (not necessary with updated spfviewer+convert)
	#`"#{command}" -c"ldoc ""#{inputfile}"" | printer number 1 type MS_WIN command FILE alias ""pdfFactory on GV3"" | set filename #{outputfile} | plot 1 all"`
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

def applyWatermark(input_file, out_file, watermark, logkey='')
	logstring = input_file
	`pdftk #{input_file} multistamp #{watermark} output #{out_file} verbose`
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

def convertSPF(arr, cmd, spfdir, pdfdir, watermark, finaldir, logfile, logkey='')
	arr.each do |c|
		file_basename = c.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.rpartition('.').first
		puts "converting & watermarking: #{file_basename}"

		# convert to PDF!
		file_basepath = c.rpartition('.').first
		converted_pdf_file = "#{file_basepath}_noWM.pdf"
		swiftconvert = runSwiftConvert(cmd, c, converted_pdf_file, 'converting_file_to_pdf')
		# watermark the PDF!
		watermarked_pdf = "#{file_basepath}.pdf"
		watermarks = applyWatermark(converted_pdf_file, watermarked_pdf, watermark, 'watermarking_pdf')
		# move watermarked PDF to done!
		moveFile(watermarked_pdf, finaldir, 'moving_file_to_finaldir')
	end
rescue => logstring
ensure
  logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- VARIABLES

input_file = ARGV[0]

# stage = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop
stage = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-1].pop

# royaltiesdir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-3].join(File::SEPARATOR)
royaltiesdir = File.expand_path(File.dirname(__FILE__))

spfdir = File.join(royaltiesdir, "temp", stage)

swiftconvcmd = File.join("C:", "Program Files (x86)", "SwiftView", "sview.exe")

pdfdir = File.join("C:", "Users", "royalty", "Documents", "PDF files", "Autosave")

assetsdir = File.join(royaltiesdir, "assets")

if stage == "Final"
	watermark = File.join(assetsdir, "images", "watermark-final.pdf")
else
	watermark = File.join(assetsdir, "images", "watermark-draft.pdf")
end

finaldir = input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-3].join(File::SEPARATOR)

finaldir = File.join(finaldir, "done", stage)

archivedir = File.join(royaltiesdir, "archive", stage)

# # Debug
# puts "input_file :", input_file
# puts "stage: ", stage
# puts "royaltiesdir: ", royaltiesdir
# puts "spfdir: ", spfdir
# puts "assetsdir: ", assetsdir
# puts "watermark: ", watermark
# puts "finaldir: ", finaldir
# puts "archivedir: ", archivedir


# ---------------------- PROCESSES

logfile = nameLogFile(royaltiesdir)

@log_hash = {}

# remove old files from temp dir
archiveDir(spfdir, archivedir, 'archiving_previous_tempfiles')  #debug
clearDir(spfdir, 'rm-ing_previous_tempfiles')

# remove old files from final dir
archiveDir(finaldir, archivedir, 'archiving_previous_finalfiles')

splitSPF(input_file, spfdir, 'splitting_master_spf_file')

spfarr = getSPFArray(spfdir, 'number_of_individual_statements')

convertSPF(spfarr, swiftconvcmd, spfdir, pdfdir, watermark, finaldir, logfile, 'convert_statements_to_pdf')

# ---------------------- LOGGING

# Write json log
write_json(@log_hash, logfile)
