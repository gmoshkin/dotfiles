-- The macos side of nvim-open: lets the GUI -- Finder's "Open With", a drag
-- onto the dock icon, a hotkey launcher -- reach the neovim already running in
-- tmux, instead of starting a second editor that knows nothing about the first.
--
-- All the thinking lives in jai/nvim-open.jai. This only turns an Apple Event
-- into a command line, because an "open documents" event is the one thing a
-- plain shell script in a bundle cannot receive.
--
-- Built by build.sh; edit this file rather than the compiled applet.

-- --gui means: look in every tmux session (we are not inside one), move the
-- tmux cursor to the editor's pane, and bring the terminal to the front
property flags : " --gui "

on nvimOpenPath()
	return (POSIX path of (path to home folder)) & "dotfiles/jai/nvim-open"
end nvimOpenPath

-- Finder hands us the files here, one event for however many were opened. They
-- go in a single command so that they share one connection and the first stays
-- on screen, the same as `nvim-open a.rs b.rs` from a shell.
on open theFiles
	set theCommand to quoted form of nvimOpenPath() & flags

	repeat with theFile in theFiles
		set theCommand to theCommand & " " & quoted form of (POSIX path of (theFile as text))
	end repeat

	try
		do shell script theCommand
	on error errorMessage
		-- There is no terminal to print to, so say it where it will be seen;
		-- nvim-open's own message is already the useful part.
		--
		-- It gives up on its own because an applet sitting on a modal dialog
		-- stops answering "open document" events: leave one up and the next
		-- file you open from Finder silently does nothing.
		display alert "Could not open in neovim" message errorMessage as warning giving up after 20
	end try
end open

-- Launched with no file at all: take me back to my editor
on run
	do shell script "open -a Alacritty"
end run
