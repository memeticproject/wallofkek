class ZeroBoard extends ZeroFrame
	init: ->
		@loadMessages()
		@avatars_added = {}
		@avatars_queue = []
		@avatars_thread = null
		
		$(".submit").on "click", (=> @submitMessage() )
		$(".message-new input").on "keydown", (e) =>
			if e.keyCode == 13 then @submitMessage() 

		@log "inited!"


	# Wrapper websocket connection ready
	onOpenWebsocket: (e) =>
		@cmd "channelJoin", {"channel": "siteChanged"} # Sign up to site changes
		@cmd "siteInfo", {}, (ret) => # Get site info
			@site_info = ret
			@setAvatar($(".message-new .avatar"), @site_info["auth_key_sha512"], "priority")

		@cmd "serverInfo", {}, (ret) => # Get server info
			@server_info = ret
			if not @server_info.ip_external
				$("#passive_error").css("display", "inline-block") # Display passive port error
				$("#passive_error a").on "click", @updateSite # Manual update on click



	submitMessage: ->
		body = $(".message-new input").val()
		if body
			$(".message-new").addClass("submitting")
			$(".message-new input").attr("disabled", "disabled")
			hash = "sha512"
			auth_key = @site_info["auth_key"]
			$.post("http://demo.zeronet.io/ZeroBoard/add.php", {"body": body, "auth_key": auth_key, "hash": hash}).always(@submittedMessage)
		else
			$(".message-new input").val("I'm so lazy that I'm using the default message.").select()


	# Message submitted
	submittedMessage: (ret, status, error) =>
		@log "Message submitted", ret, status, error
		$(".message-new").removeClass("submitting")
		$(".message-new input").removeAttr("disabled")
		if status == "success"
			$(".message-new input").val("")
			@cmd "wrapperNotification", ["done", "Message submitted successfuly!<br>It could take some minutes to appear.", 10000]
		else
			@cmd "wrapperNotification", ["error", "Message submit failed!<br>#{ret.responseText}"]



	# Set identicon background to elem based on hash
	setAvatar: (elem=null, hash, priority=false) ->
		if not @avatars_added[hash] # Not loaded yet
			@avatars_added[hash] = true
			# Add to queue
			if priority
				@avatars_queue.unshift(hash)
			else
				@avatars_queue.push(hash)
		if elem then elem.addClass("identicon-#{hash}")


	# Load avatars
	loadAvatars: ->
		if @avatar_thread then return # Already running
		@avatar_thread = setInterval (=> # Dont block the UI
			for i in [1..5]
				hash = @avatars_queue.shift()
				if hash
					imagedata = new Identicon(hash, 70).toString();
					$("body").append("<style>.identicon-#{hash} { background-image: url(data:image/png;base64,#{imagedata}) }</style>")
				else
					clearInterval @avatar_thread
					@avatar_thread = null
					break
		), 20




	# Load messages from messages.json
	loadMessages: ->
		$.getJSON "messages.json", (messages) =>
			empty = $(".messages .message:not(.template").length == 0
			s = +(new Date)
			@log "Loading messages, empty:", empty
			template = $(".message.template")
			for message in messages.reverse()
				key = message.sender+"-"+message.added
				if empty or $(".message-#{key}").length == 0 # Add if not exits
					elem = template.clone().removeClass("template").addClass("message-#{key}")
					if not empty # Not first init, init for animating
						elem.css({"opacity": 0, "margin-bottom": 0})
					$(".body", elem).html(message.body)
					$(".avatar", elem).addClass("identicon-#{message.sender}")
					$(".added", elem).text(@formatSince(message.added))
					elem.prependTo($(".messages"))
					if not empty # Not first init, animate it
						@setAvatar($(".avatar", elem), message.sender) # Load avatar
						height = elem.outerHeight()
						elem.css("height", 0).cssLater({"height": height, "opacity": 1, "margin-bottom": ""})
			@log "Loaded messages in", (+(new Date)-s)
			if empty # Add all avatar to queue on clean run
				for message in messages.reverse() # Reverse back to normal order :)
					@setAvatar null, message.sender

			@loadAvatars()
			$(".messages").css("opacity", "1")



	# Format time since
	formatSince: (time) ->
		now = +(new Date)/1000
		secs = now - time
		if secs < 60
			return "Just now"
		else if secs < 60*60
			return "#{Math.round(secs/60)} minutes ago"
		else if secs < 60*60*24
			return "#{Math.round(secs/60/60)} hours ago"
		else
			return "#{Math.round(secs/60/60/24)} days ago"


	# Manual site update for passive connections
	updateSite: =>
		$("#passive_error a").addClass("loading").removeClassLater("loading", 1000)
		@log "Updating site..."
		@cmd "siteUpdate", {"address": @site_info.address}


	# Route incoming requests
	route: (cmd, message) ->
		if cmd == "setSiteInfo" # Site updated
			@actionSetSiteInfo(message)
		else
			@log "Unknown command", message


	actionSetSiteInfo: (message) ->
		@log "setSiteinfo", message
		if message.params.event?["0"] == "file_done" and message.params.event?["1"] == "messages.json" # new messages.json received
			@loadMessages()


window.zero_board = new ZeroBoard()
