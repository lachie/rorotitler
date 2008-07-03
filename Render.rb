require 'pp'
require 'fileutils'
require 'open3'

class Render < OSX::NSObject
	include FileUtils
	include OSX
	
	DEFAULT_BLENDER = '/Applications/Blender.app/Contents/MacOS/blender'
	DEFAULT_YAFRAY = '/usr/local/lib/yafray'
	
	def render(message,preview=false,blender=DEFAULT_BLENDER,&block)
	
		if @task
			puts "already rendering"
			return
		end
		
		@preview = preview
	
		ENV['RORO_TITLE'] = message
		ENV['RORO_PREVIEW'] = preview ? '1' : '0'
		
		blend  = NSBundle.mainBundle.pathForResource_ofType("roro_title","blend")
		script = NSBundle.mainBundle.pathForResource_ofType("render","py")
		
		
		args = ["-b", blend, "-P", script]
		
		# Fake   pass: [
		
		fake_hashes = 0
		render_hashes = 0
		buffer = ""
		
		parse_state = :initial
		@task = AsyncTask.alloc.init.run(blender,args) do |kind,data|
			buffer << data if data
			
			case kind
			when :out,:err
				puts data
				
				case parse_state
				when :initial
					yield(2,'setup')
					if buffer.sub!(/.*?Fake\s+pass: \[/m,'')
						fake_hashes = buffer.scan(/#/).size
						parse_state = :fake
					end
				when :fake
					fake_hashes = buffer.scan(/#/).size 
					yield(10,"rendering fakes (#{fake_hashes})")

					if m = buffer.match(/(#+)\].*?Render pass: \[/m)
						fake_hashes = $1.size
						puts "fake_hashes: #{fake_hashes}"
						parse_state = :rendering
						buffer[0,m[0].length] = ''
					end
				when :rendering
					render_hashes = buffer.scan(/#/).size
					puts "render hashes: #{render_hashes}"
					
					frac = render_hashes / fake_hashes.to_f
					done = 20 + 80 * frac
					yield(done,'rendering %d%%' % (frac*100))
				end
				
				
			when :finished
				mv '0001.png', "#{@preview ? 'preview' : 'original'}.png"
				yield(100,'done')
				@task = nil
			end
		end
		
		puts "after async task"
		
		
		#system("#{blender} -b #{blend} -P #{script}")
	end
	
	def terminate
		@task.terminate if @task
	end
	
	def final?  ; File.exist? 'original.png' end
	def preview?; File.exist? 'preview.png'  end
	
	def final_file; 'original.png' end
	def preview_file; 'preview.png' end
	
	def init
		return self unless super_init
		
		@work_dir = "/tmp/roro_titler"
		
		unless File.directory? @work_dir
			puts "[renderer] making a work dir at #{@work_dir}"
			mkdir_p @work_dir
		end
		Dir.chdir @work_dir
		
		self
	end
	
	
	def build(output_mov, master_mov)
		@output_mov = output_mov
		@master_mov = master_mov
	
		@original = "original.png"
		@source = NSBundle.mainBundle.resourcePath
		
		_setup
		_setup_qt
		_composite
		_write_output
		
		puts "[build] done"
		true
	rescue
		NSRunAlertPanel("I couldn't build the movie", $!.to_s, "That is teh suck.", nil, nil)
		false
	end
	
	def cleanup!
		#rm_rf @work_dir
	end
	
	def _setup
		puts "[build] setting up"
		#cp File.join(@original_dir,'0001.png'), "#{@work_dir}/#{@original}"

		#@fade_to = "#{@work_dir}/overlay_#{@original}"
		
		@fade_from = "#{@source}/blank.png"
		@logo      = "#{@source}/logo_overlay.png"
	end
	
	def _setup_qt
		puts "[build] setting up qt"
		@one_frame = QTTime.new(1,25,0)

		data = NSMutableData.data
		@movie = QTMovie.alloc.initToWritableData_error(data,nil)
		raise "Couldn't create fade movie" unless @movie
		
		@movie.setAttribute_forKey(true,QTMovieEditableAttribute)

		range = QTTimeRange.new(QTZeroTime,@movie.duration)
		@movie.scaleSegment_newDuration(range,@one_frame)
		
	
	end


	def add_frame(file)
	  @import_attrs ||= {QTAddImageCodecType => 'png '}.to_ns
	  
	  puts "adding #{file} to QT"
	  image = NSImage.alloc.initWithContentsOfFile(file)
	  @movie.addImage_forDuration_withAttributes(image,@one_frame,@import_attrs)
	end
	
	
	def _add_image(image)
		@import_attrs ||= {QTAddImageCodecType => 'png '}.to_ns
		@movie.addImage_forDuration_withAttributes(image,@one_frame,@import_attrs)
	end

	def _composite
		puts "[build] compositing"
		original_ci   = CIImage.from("#{@work_dir}/#{@original}")
		logo_ci       = CIImage.from(@logo)
		fade_from_ci  = CIImage.from(@fade_from)
		
		@cicontext = original_ci.cicontext
		
		# CIFilter.filterNamesInCategories(nil).each {|f| p f}
		source_over = logo_ci.filternamed('SourceOverCompositing', :inputBackgroundImage => original_ci)

		fade_to_ci = source_over.outputImage		
		fade_filter = fade_from_ci.filternamed('DissolveTransition', :inputTargetImage => fade_to_ci)
		
		# fade in
		frames = 24
		0.upto(frames) do |i|
			fade_filter[:inputTime] = i / frames.to_f
			_add_image(fade_filter.outputimage.nsimage)
		end

		# stick around for a bit
		fade_to_ns = fade_to_ci.nsimage
		(25 * 4).times do
			_add_image(fade_to_ns)
		end
		
		# fade out
		0.upto(frames) do |i|
			fade_filter[:inputTime] = 1.0 - i / frames.to_f
			_add_image(fade_filter.outputimage.nsimage)
		end
		
	ensure
		original_ci = nil
		logo_ci = nil
		fade_from_ci = nil
		fade_to_ci = nil
		fade_to_ns = nil
		fade_filter = nil
		source_over = nil
		
		@cicontext = nil
	end
	
	
	def _write_output
		puts "[build] writing output"
		# write the master movie
		masterMovie = QTMovie.movieWithFile_error(@master_mov,nil)
		
		raise "Couldn't load master movie from #{@master_mov}" unless masterMovie
		
		masterMovie.setAttribute_forKey(true,QTMovieEditableAttribute)

		length = 7823 - 4223

		duration = QTTime.new(length,600,0)

		destStart = QTTime.new(4223,600,0)
		srcStart  = QTTime.new(0,600,0)

		destRange = QTTimeRange.new(destStart,duration)
		srcRange  = QTTimeRange.new(QTZeroTime,@movie.duration)

		masterMovie.insertSegmentOfMovie_fromRange_scaledToRange(@movie,srcRange,destRange)

		masterMovie.writeToFile_withAttributes(@output_mov,nil)
	end

end