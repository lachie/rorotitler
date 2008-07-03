class WizzardController < OSX::NSWindowController
	ib_outlet :wizzard_view
	
	
	#preview
	ib_outlet :preview_image, :preview_line1, :preview_line2
	ib_outlet :preview_button
	ib_action :preview
	
	#render
	ib_outlet :render_image
	ib_action :render
	ib_outlet :render_progress
	ib_outlet :render_status
	ib_outlet :render_button
	
	#build
	ib_outlet :master_movie
	ib_outlet :output_movie
	ib_outlet :movie
	
	ib_action :find_master_movie
	ib_action :find_output_movie
	ib_action :build
	ib_action :render_build
	
	ib_action :setMovieSelection
	
	# do all
	ib_action :doall
	ib_outlet :doall_progress, :doall_button
	
	ib_action :test_reader
	
	
	def applicationShouldTerminateAfterLastWindowClosed(app)
		true
	end
	
	def applicationWillTerminate(app)
		puts "application is terminating"
		renderer.terminate
	end
	
	
	def awakeFromNib
		until File.exist? Render::DEFAULT_BLENDER and File.directory? Render::DEFAULT_YAFRAY
		
			message = %{You dont have blender and/or yafray installed :(
Please download Blender from http://www.blender.org/download/get-blender and put it in /Applications.
Please download Yafray http://www.yafray.org/index.php?s=2 and run the installer.

mkay?}
		
			case rv = OSX::NSRunAlertPanel("No blender!", message, 'Go to blender.org', 'Quit', 'Check Again')
			when 1
				OSX::NSWorkspace.sharedWorkspace.openURL(OSX::NSURL.URLWithString("http://www.blender.org/download/get-blender/"))
			when 0
				OSX::NSApp.terminate(nil)
			end
		end
		
		@wizzard_view.delegate = self

		
		@doall_button.enabled = false unless master_movie?
		
		OSX::NSApp.delegate = self
		
		if output_movie = get_output_movie and File.exist?(output_movie)
			@movie.setMovie(OSX::QTMovie.movieWithFile_error(output_movie,nil))
			@movie.movie.setAttribute_forKey(true,OSX::QTMovieEditableAttribute)
		end
		
		test_reader(nil)
	end
	
	def message
		[@preview_line1.stringValue,@preview_line2.stringValue].join('\n')
	end
	
	def renderer
		@renderer ||= Render.alloc.init
	end
	
	def preview(sender)
		@preview_button.enabled = false
		renderer.render(message,true) do |progress,status|
			puts "pc: #{progress} ... #{status}"
			
			if progress == 100
				@preview_image.setImage(OSX::NSImage.alloc.initWithContentsOfFile( renderer.preview_file ))
				@preview_button.enabled = true
			end
		end
	end
	
	def render(sender)
		@render_status.setStringValue('')
		@render_button.enabled = false
		renderer.render(message) do |progress,status|
			puts "render pc: #{progress} ... #{status}"
			@render_progress.setDoubleValue(progress.to_f)
			@render_status.setStringValue(status)
			
			if progress == 100
				@render_image.setImage(OSX::NSImage.alloc.initWithContentsOfFile(renderer.final_file))
				@render_button.enabled = true
			end
		end
	end
	
	def get_master_movie
		OSX::NSUserDefaultsController.sharedUserDefaultsController.values.valueForKey("master_movie")
	end
	
	def master_movie?
		mm = get_master_movie
		mm and !mm.to_s.strip.empty?
	end

	def get_output_movie
		OSX::NSUserDefaultsController.sharedUserDefaultsController.values.valueForKey("output_movie")
	end
	
	def build(sender)
		master_movie = get_master_movie
		output_movie = get_output_movie
		
		render(sender) unless renderer.final?
		
		puts "master_movie: #{master_movie}"
		puts "output_movie: #{output_movie}"
		
		if renderer.build(output_movie,master_movie)
			@movie.setMovie(OSX::QTMovie.movieWithFile_error(output_movie,nil))
			renderer.cleanup!
			@renderer = nil
		end
	end
	
	def render_build(sender)
		raise "There's no master movie set" unless master_movie?
	
		find_output_movie(sender)
		
		@wizzard_view.selectTabViewItemWithIdentifier('render')
		render(sender)
		
		window.displayIfNeeded

		@wizzard_view.selectTabViewItemWithIdentifier('build')
		build(sender)
		
		window.displayIfNeeded

		@doall_progress.stringValue = ""
		
	rescue
		NSRunAlertPanel("There was a problem running the expert render.", "#{$!.to_s}.\nYou need to follow the slow route first.", 'Awww!', nil, nil)
		@wizzard_view.selectTabViewItemWithIdentifier('preview')
	end
	
	def find_master_movie(sender)
		op = OSX::NSOpenPanel.openPanel
		if OSX::NSOKButton == op.runModalForDirectory_file_types(ENV['HOME'],'',['mov'])
			OSX::NSUserDefaultsController.sharedUserDefaultsController.values.setValue_forKey(op.filename,"master_movie")
			
			#@master_movie.setValue_forKey(op.filename,"stringValue")
		end
	end
	
	def find_output_movie(sender)
		sp = OSX::NSSavePanel.savePanel
		if OSX::NSOKButton == sp.runModalForDirectory_file(ENV['HOME'],'')
			OSX::NSUserDefaultsController.sharedUserDefaultsController.values.setValue_forKey(sp.filename,"output_movie")
			#@output_movie.setValue_forKey(sp.filename,"stringValue")
		end
	end
	
	def test_reader(s)
		#puts "testing open"
		#o = AsyncTask.alloc.init
		#o.run("/Users/lachie/bin/sleep.rb") do |kind,info|
		#	puts "k: #{kind} ... #{info}"
		#end
	end
	
	# delegate
	def tabView_willSelectTabViewItem(tv,tvItem)
		case tvItem.identifier
		when 'preview'
		when 'render'
		when 'build'
		end
	end
	
end