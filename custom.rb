require 'rubygems'
require 'gosu'

TOP_COLOR = Gosu::Color.new(0xFF1EB1FA)
BOTTOM_COLOR = Gosu::Color.new(0xFF1D4DB5)

module ZOrder
	BACKGROUND, PLAYER, UI = *0..2
end

module Genre
	POP, CLASSIC, JAZZ, ROCK, Various = *1..5
end

Genre_names = ['Null', 'Pop', 'Classic', 'Jazz', 'Rock', 'Various']

class ArtWork
	attr_accessor :img
	
	def initialize (file)
		@img = Gosu::Image.new(file)
	end
end

class Album
	attr_accessor :artist, :title, :year, :genre, :artwork, :tracks
	
	def initialize (artist, title, year, genre, artwork, tracks)
		@artist = artist
		@title = title
		@year = year
		@genre = genre
		@artwork = artwork
		@tracks = tracks
	end
end

class Track
	attr_accessor :name, :location, :duration
	def initialize (name, location, duration)
		@name = name
		@location = location
		@duration = duration
	end
end

def load_albums
	filename = "./albums/albums.txt"
	music_file = File.new(filename, "r")
	count = music_file.gets.to_i
	
	albums = Array.new
	while count > 0
		artist = music_file.gets.chomp
		title = music_file.gets.chomp
		year = music_file.gets.chomp
		genre_index = music_file.gets.chomp.to_i
		genre = Genre_names[genre_index]
		artwork_file = music_file.gets.chomp
		artwork_path = File.join("albums", artwork_file)
		track_count = music_file.gets.to_i
		
		tracks = []
		while track_count > 0
			name = music_file.gets.chomp	
			song_file = music_file.gets.chomp
			location = File.join("albums", song_file)
			duration = music_file.gets.chomp 

			tracks << Track.new(name, location, duration)
			track_count -= 1
		end
		
		artwork = ArtWork.new(artwork_path)
		albums << Album.new(artist, title, year, genre, artwork, tracks)
		count -= 1
	end
	music_file.close
	puts("Albums loaded successfully.")
	return albums
end

class MusicPlayerMain < Gosu::Window
	def initialize

		super 1280, 900
		self.caption = "Music Player"
		
		@scale = 0.5
		@albums = load_albums()
		@all_tracks_album = create_all_tracks_album(@albums)
		@albums.unshift(@all_tracks_album)
		
		@selected_album = nil
		@track_positions = []
		
		@font = Gosu::Font.new(30)
		
		@albums_per_page = 4
		@current_page = 0
		@tracks_per_page = 20
		@track_page = 0

		@current_track_index = 0
		@hovered_track_index = nil
		@song = nil
		@paused = false

		@filter_genre = nil
		@genres = []
		i = 0
		while i < @albums.length
			genre = @albums[i].genre
  			@genres << genre unless @genres.include?(genre)
  			i += 1
		end
		@genres.sort!
		@genres.unshift('All')
		@filter_year = nil
		@years = []
		i = 0
		while i < @albums.length
  			year = @albums[i].year
  			@years << year unless @years.include?(year)
  			i += 1
		end
		@years.sort!
		@years.unshift('All')

		# Playlist feautre
		@create_playlist_artwork = ArtWork.new(File.join("albums", "media", "all_tracks.png"))
		@create_playlist_album = Album.new("You", "Create Playlist", "2025", "Various", @create_playlist_artwork, [])
		@albums.unshift(@create_playlist_album)
		@creating_playlist = false
  		@playlist_tracks = []
  		@finish_playlist_button_area = nil
	end 
		
	BUTTON_WIDTH = 100 
	BUTTON_HEIGHT = 40 
	BUTTON_Y = 842 
	BUTTON_SPACING = 20 
	
	TrackLeftX = 700

	def create_all_tracks_album(albums)
		all_tracks = []
		index = 0
		while index < albums.length
			album = albums[index]
			track_index = 0
			while track_index < album.tracks.length
				all_tracks << album.tracks[track_index]
				track_index += 1
			end
			index += 1
  		end

		artwork = File.join("albums", "media", "all_tracks.png")
		placeholder_artwork = ArtWork.new(artwork)

		Album.new("Various Artists", "All Tracks", "2025", "Various", placeholder_artwork, all_tracks)
	end

	def filtered_albums
		filtered = []
		i = 0
	
		while i < @albums.length
			album = @albums[i]
			if (@filter_genre.nil? || album.genre == @filter_genre) && (@filter_year.nil? || album.year == @filter_year)
				filtered << album
			end
			i += 1
		end

		filtered
	end

	def draw_albums(albums)
		if @selected_album

			x = 100
			y = 100
			album = @selected_album
			album.artwork.img.draw(x, y, ZOrder::PLAYER, @scale, @scale)
        	@font.draw_text(album.title, x, y + album.artwork.img.height * @scale + 5, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
        	@album_positions = [{
        	    x: x,
        	    y: y,
        	    width: album.artwork.img.width * @scale,
        	    height: album.artwork.img.height * @scale
        	}]
    	else

			start_index = @current_page * @albums_per_page
			end_index = [start_index + @albums_per_page, albums.length].min

			x = 20
			y = 20
			horizontal_spacing = (albums[0].artwork.img.width * @scale) + 20
			vertical_spacing = (albums[0].artwork.img.height * @scale) + 40

			@album_positions = []

			max_width = 700

			index = start_index
			while index < end_index
				album = albums[index]
				album.artwork.img.draw(x, y, ZOrder::PLAYER, @scale, @scale)
				@font.draw_text(album.title, x, y + album.artwork.img.height * @scale + 5, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			
				@album_positions << {
					x: x,
					y: y,
					width: album.artwork.img.width * @scale,
					height: album.artwork.img.height * @scale
				}

				x += horizontal_spacing
				if x + album.artwork.img.width * @scale > max_width
					x = 20
					y += vertical_spacing
				end
				index += 1
			end
		end
	end
		
	def draw_controls
		
		if @selected_album
			if @creating_playlist
    			@font.draw_text("Finish Playlist", 1080, 845, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
    			@finish_playlist_button_area = [1080, 845, 1080 + @font.text_width("Finish Playlist"), 1080 + BUTTON_HEIGHT]
			end
			
    		@font.draw_text("Back", 50, 50, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
    		@back_button_area = [50, 50, 50 + @font.text_width("Back"), 50 + BUTTON_HEIGHT]
			x = 200
			
			# Previous Button
			@font.draw_text("Previous", x, BUTTON_Y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			prev_text_width = @font.text_width("Previous")
			@prev_button_area = [x, BUTTON_Y, x + prev_text_width, BUTTON_Y + BUTTON_HEIGHT]

			# Pause/Resume Button
			x += BUTTON_WIDTH + 20 + BUTTON_SPACING
			@font.draw_text("Pause/Resume", x, BUTTON_Y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			pause_text_width = @font.text_width("Pause/Resume")
			@pause_button_area = [x, BUTTON_Y, x + pause_text_width, BUTTON_Y + BUTTON_HEIGHT]
			
			# Next Button
			x += BUTTON_WIDTH + 80 + BUTTON_SPACING
			@font.draw_text("Next", x, BUTTON_Y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			next_text_width = @font.text_width("Next")
			@next_button_area = [x, BUTTON_Y, x + next_text_width, BUTTON_Y + BUTTON_HEIGHT]

			# Previous Page of Tracks
			track_nav_y = 780
			@font.draw_text("<< Prev Tracks", 700, track_nav_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			@prev_track_page_button_area = [700, track_nav_y, 700 + @font.text_width("<< Prev Tracks"), track_nav_y + BUTTON_HEIGHT]

			# Next Page of Tracks
			@font.draw_text("Next Tracks >>", 900, track_nav_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			@next_track_page_button_area = [900, track_nav_y, 900 + @font.text_width("Next Tracks >>"), track_nav_y + BUTTON_HEIGHT]
		end
		
		if @selected_album.nil?
			# Draw Genre filter buttons
        	genre_x = 50
        	genre_y = 820
        	@genre_button_areas = []
        	i = 0
        	while i < @genres.length
        	    genre = @genres[i]
        	    @font.draw_text(genre, genre_x, genre_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
        	    width = @font.text_width(genre) + 20
        	    @genre_button_areas << [genre_x, genre_y, genre_x + width, genre_y + BUTTON_HEIGHT, genre]
        	    genre_x += width + 10
        	    i += 1
        	end

        	# Draw Year filter buttons
        	year_x = 50
        	year_y = 860
        	@year_button_areas = []
        	j = 0
        	while j < @years.length
        	    year = @years[j]
        	    @font.draw_text(year, year_x, year_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
        	    width = @font.text_width(year) + 20
        	    @year_button_areas << [year_x, year_y, year_x + width, year_y + BUTTON_HEIGHT, year]
        	    year_x += width + 10
        	    j += 1
        	end

			# Page Navigation Buttons
			page_nav_y = 780
    		@font.draw_text("<< Prev", 270, page_nav_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			text_width = @font.text_width("<< Prev")
    		@prev_page_button_area = [270, page_nav_y, 270 + text_width, page_nav_y + BUTTON_HEIGHT]

    		@font.draw_text("Next >>", 380, page_nav_y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
			text_width = @font.text_width("Next >>")
    		@next_page_button_area = [380, page_nav_y, 380 + text_width, page_nav_y + BUTTON_HEIGHT]
		end
	end
		
	def draw_tracks
		return unless @selected_album
		@current_track_index == nil

		tracks = @selected_album.tracks
		start_index = @track_page * @tracks_per_page
		end_index = [start_index + @tracks_per_page, tracks.length].min

    	index = start_index
    	y = 20
    	while index < end_index

        	track = tracks[index]
			track_text = " #{index + 1}. #{track.name} (#{track.duration})"
			text_width = @font.text_width(track_text)
			if @creating_playlist && @selected_album.title == "All Tracks" && @playlist_tracks.include?(index)
            	Gosu.draw_rect(TrackLeftX - 10, y - 5, text_width + 20, 30, Gosu::Color::GREEN, ZOrder::BACKGROUND)
            	@font.draw_text(track_text, TrackLeftX, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::RED)
			elsif index == @current_track_index
            	Gosu.draw_rect(TrackLeftX - 10, y - 5, text_width + 20, 30, Gosu::Color::GREEN, ZOrder::BACKGROUND)
            	@font.draw_text("#{track_text}", TrackLeftX, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::RED)
        	elsif index == @hovered_track_index
            	Gosu.draw_rect(TrackLeftX - 10, y - 5, text_width + 20, 30, Gosu::Color::YELLOW, ZOrder::BACKGROUND)
            	@font.draw_text("#{track_text}", TrackLeftX, y, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
        	else
            	@font.draw_text(track_text, TrackLeftX, y, ZOrder::PLAYER, 1.0, 1.0, Gosu::Color::BLACK)
        	end
         y += 30
        	index += 1
    	end
	end
	
	def mouse_over_button(mouse_x, mouse_y)
		mouse_x.between?(50, 150) && mouse_y.between?(50, 100)
	end
	
	def area_clicked(leftX, topY, rightX, bottomY, mouse_x, mouse_y)
		mouse_x >= leftX && mouse_x <= rightX && mouse_y >= topY && mouse_y <= bottomY
	end

	def playTrack(track_index, album)
		return if album.tracks.empty?
		
		@current_track_index = track_index
		
		@song = Gosu::Song.new(album.tracks[track_index].location)
		@song.play(false)
	end
	
	def draw_background
		draw_quad(0, 0, TOP_COLOR, 1280, 0, TOP_COLOR, 0, 820, BOTTOM_COLOR, 1280, 820, BOTTOM_COLOR, ZOrder::BACKGROUND)
		draw_quad(0, 900, Gosu::Color::GREEN, 1280, 900, Gosu::Color::GREEN, 0, 820, Gosu::Color::GREEN, 1280, 820, Gosu::Color::GREEN, ZOrder::BACKGROUND)
	end
	
	def draw_border(x, y, width, height)
		border_color = Gosu::Color::WHITE
		thickness = 4
		
		# Top
		draw_rect(x, y, width, thickness, border_color, ZOrder::UI)
		# Bottom
		draw_rect(x, y + height - thickness, width, thickness, border_color, ZOrder::UI)
		# Left
		draw_rect(x, y, thickness, height, border_color, ZOrder::UI)
		# Right
		draw_rect(x + width - thickness, y, thickness, height, border_color, ZOrder::UI)
	end
	
	def update
		if @selected_album
			@track_positions = []
			tracks = @selected_album.tracks
			start_index = @track_page * @tracks_per_page
			end_index = [start_index + @tracks_per_page, tracks.length].min

			y = 20
			while start_index < end_index
				@track_positions << {
					index: start_index,
					x1: TrackLeftX,
					y1: y,
					x2: TrackLeftX + 300,
					y2: y + 25		
				}	
				y += 30
				start_index += 1
			end

			@hovered_track_index = nil
			index = 0
			while index < @track_positions.length
				position = @track_positions[index]
				if mouse_x >= position[:x1] && mouse_x <= position[:x2] && mouse_y >= position[:y1] && mouse_y <= position[:y2]
					@hovered_track_index = position[:index]
					break
				end
				index += 1
			end
		end
	end
	
	def draw
		draw_background
		draw_controls
		draw_albums(filtered_albums) if @albums

		return unless @album_positions
		album_index = 0
		while album_index < @album_positions.length
			position = @album_positions[album_index]
			if mouse_x.between?(position[:x], position[:x] + position[:width]) &&
				mouse_y.between?(position[:y], position[:y] + position[:height])
				draw_border(position[:x], position[:y], position[:width], position[:height])
			end
			album_index += 1
		end
		draw_tracks	
	end
	
	def needs_cursor?; true; end

	def button_down(id)
		case id
		when Gosu::MsLeft

			if @selected_album && @finish_playlist_button_area && area_clicked(*@finish_playlist_button_area, mouse_x, mouse_y)
				puts("button clicked")
    			tracks = @playlist_tracks.map { |i| @all_tracks_album.tracks[i] }
    			new_artwork = ArtWork.new(File.join("albums", "media", "created_playlist.png"))
    			new_album = Album.new("You", "My Playlist", "2025", "Playlist", new_artwork, tracks)
    			@albums << new_album
    			@creating_playlist = false
    			@playlist_tracks = []
    			@selected_album = nil
				return
			end

			if @back_button_area && area_clicked(*@back_button_area, mouse_x, mouse_y)
				@selected_album = nil
				return
			end

			# Genre filter buttons
			i = 0
			while i < @genre_button_areas.length
				x1, y1, x2, y2, genre = @genre_button_areas[i]
				if area_clicked(x1, y1, x2, y2, mouse_x, mouse_y)
					@filter_genre = (genre == 'All' ? nil : genre)
					@filter_year = nil
					@current_page = 0
				end
			i += 1
			end

			# Year filter buttons
			j = 0
			while j < @year_button_areas.length
				x1, y1, x2, y2, year = @year_button_areas[j]
				if area_clicked(x1, y1, x2, y2, mouse_x, mouse_y)
					@filter_year = (year == 'All' ? nil : year)
					@filter_genre = nil
					@current_page = 0
				end
  				j += 1
			end

			if @selected_album.nil?
				x = 20
				y = 20
				scale = @scale
				horizontal_spacing = (@albums[0].artwork.img.width * scale) + 20
				vertical_spacing = (@albums[0].artwork.img.height * scale) + 40
				max_width = 700
			
				filtered = filtered_albums
        		start_index = @current_page * @albums_per_page
        		end_index = [start_index + @albums_per_page, filtered.length].min

        		index = start_index
        		while index < end_index
        		    album = filtered[index]
        		    rightX = x + album.artwork.img.width * scale
        		    bottomY = y + album.artwork.img.height * scale

					if area_clicked(x, y, rightX, bottomY, mouse_x, mouse_y)
						if album == @create_playlist_album
       						@creating_playlist = true
        					@playlist_tracks = []
        					@selected_album = @all_tracks_album
        					@current_track_index = nil
        					@track_page = 0
        					return
    					end
						puts "Clicked on album: #{album.title} by #{album.artist}"
						@selected_album = album
						@current_track_index = nil
						@track_page = 0
						break
					end

        		    x += horizontal_spacing
        		    if x + album.artwork.img.width * scale > max_width
        		        x = 20
        		        y += vertical_spacing
        		    end
        		    index += 1
        		end
			end

			if @selected_album && @track_positions
				if @prev_button_area && area_clicked(*@prev_button_area, mouse_x, mouse_y)
					puts("Previous track clicked")
					if @selected_album.tracks.any?
						@current_track_index = (@current_track_index - 1) % @selected_album.tracks.length
						playTrack(@current_track_index, @selected_album)
					end
				elsif @next_button_area && area_clicked(*@next_button_area, mouse_x, mouse_y)
					puts("Next track clicked")
					if @selected_album.tracks.any?
						@current_track_index = (@current_track_index + 1) % @selected_album.tracks.length
						playTrack(@current_track_index, @selected_album)
					end
				elsif @pause_button_area && area_clicked(*@pause_button_area, mouse_x, mouse_y)
					if @song
						if @song.playing?
							@song.pause
							@paused = true
						elsif @paused
							@song.play(false)
							@paused = false
						end
					end
				end
			end

			# Now do track selection if needed
			if @selected_album && @track_positions
				index = 0
				while index < @track_positions.length
					position = @track_positions[index]
					if mouse_x >= position[:x1] && mouse_x <= position[:x2] &&
						mouse_y >= position[:y1] && mouse_y <= position[:y2]
						if @creating_playlist && @selected_album.title == "All Tracks"
							if !@playlist_tracks.include?(position[:index])
								@playlist_tracks << position[:index]
							else
								@playlist_tracks.delete(position[:index])
							end
							return
						end
						puts "Playing track: #{@selected_album.tracks[position[:index]].name}"
						playTrack(position[:index], @selected_album)
						return
					end
					index += 1
				end
			end

			if @prev_page_button_area && area_clicked(*@prev_page_button_area, mouse_x, mouse_y)
				if @current_page > 0
					@current_page -= 1
				end

			elsif @next_page_button_area && area_clicked(*@next_page_button_area, mouse_x, mouse_y)
				max_page = (filtered_albums.length - 1) / @albums_per_page
				if @current_page < max_page
					@current_page += 1
				end
			end

			if @prev_track_page_button_area && area_clicked(*@prev_track_page_button_area, mouse_x, mouse_y)
				if @track_page > 0
					@track_page -= 1
				end
			end

			if @next_track_page_button_area && area_clicked(*@next_track_page_button_area, mouse_x, mouse_y)
				max_track_page = (@selected_album.tracks.length - 1) / @tracks_per_page
				if @track_page < max_track_page
					@track_page += 1
				end
			end
		end
	end
end
MusicPlayerMain.new.show if __FILE__ == $0