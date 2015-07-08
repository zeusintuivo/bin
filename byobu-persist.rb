#!/usr/bin/env ruby

# Modified version of https://github.com/geebee/tmux-persistence to work with byobu
# and work on OSX.

require 'fileutils.rb'

# Start - Configuration Variables
sessionDir = ENV['HOME']+"/.byobu-sessions"
maxStoredSessions = 5
filesToRoll = 3
# End - Configuration Variables

FileUtils::makedirs(sessionDir) unless File.exists?(sessionDir)

files = []
Dir.entries(sessionDir).each do |e|
  if e !~ /^\./
    files << e
  end
end
files.sort! unless files.length == 0

if files.length > maxStoredSessions
  0.upto(filesToRoll - 1) do |index|
    File.delete( sessionDir+ "/" + files[index] )
  end
  puts "Rotated stored sessions"
end

#%x[rm #{sessionDir}/*-restore]

sessions = %x[tmux list-sessions -F "\#{session_name}"].split("\n")

sessions.each do |sessionName|
  rawPaneList = %x[tmux list-panes -t #{sessionName} -s -F "\#{window_index} \#{pane_index} \#{window_width} \#{window_height} \#{pane_width} \#{pane_height} \#{window_name} \#{pane_current_path} \#{pane_pid}"].split("\n")

  panes = []
  rawPaneList.each do |pane_line|
    temp_pane = pane_line.split(" ")
    panes.push({
      windowIndex: Integer(temp_pane[0]),
      paneIndex: Integer(temp_pane[1]),
      windowWidth: Integer(temp_pane[2]),
      windowHeight: Integer(temp_pane[3]),
      paneWidth: Integer(temp_pane[4]),
      paneHeight: Integer(temp_pane[5]),
      window_name: temp_pane[6],
      cwd: temp_pane[7],
      pid: temp_pane[8]
    })
  end

  sessionScript = ""
  panes.each do |pane|
    pane[:cmd] = %x[ps -o command -p #{pane[:pid]} | awk 'NR>1'].delete("\n")
    pane[:cmd] = %x[ps -o command #{pane[:pid]} | awk 'NR>1'].delete("\n").gsub(/^-/,"") unless pane[:cmd] != ""

    # Create a new session with first window properties to prevent current terminal from becoming first window
    if pane[:windowIndex] == 0 && pane[:paneIndex] == 0
      sessionScript += "  byobu new-session -d -s $SESSION -n #{pane[:window_name]} \"cd #{pane[:cwd]} && #{pane[:cmd]}\"\n"
    else
      sessionScript += "  byobu new-window -t $SESSION -a -n #{pane[:window_name]} \"cd #{pane[:cwd]} && #{pane[:cmd]}\"\n"
    end

    if pane[:paneIndex] > 0
      if pane[:paneWidth] < pane[:windowWidth]
        sessionScript += "  byobu join-pane -h -l #{pane[:paneWidth]} -s $SESSION:#{pane[:windowIndex] +1}.0 -t $SESSION:#{pane[:windowIndex]}\n"
      else
        sessionScript += "  byobu join-pane -v -l #{pane[:paneHeight]} -s $SESSION:#{pane[:windowIndex] +1}.0 -t $SESSION:#{pane[:windowIndex]}\n"
      end
    end
  end

  restore_file = sessionDir + "/" + sessionName + "-restore"

  File.open(restore_file, "w") {
    |f| f.write(%Q[#!/usr/bin/env bash
SESSION=#{sessionName}

if [ -z $TMUX ]; then

  # if session already exists, attach
  byobu has-session -t $SESSION 2>/dev/null
  if [ $? -eq 0 ]; then
    echo \"Session $SESSION already exists. Attaching...\"
    byobu attach -t $SESSION
    exit 0;
  fi

#{sessionScript}

  # attach to new session
  byobu select-window -t $SESSION:0
  byobu attach-session -t $SESSION

fi
  ])
  
    # make script executable
    f.chmod( 0744 )
  }
end
