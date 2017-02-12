--
-- trashfileonend
-- Author: donmaiq
--
--change settings keybind toggle in input.conf with -> KEY script-binding toggledeletefile
--send your config during runtime with a keybind in input conf with -> alt+x script-message trashfileonend true true
--where first argument is settings.deletefile variable, and second settings.deleteoneonly explained below
--set variables in settings table to your liking
--problems might occur with permissions or write protected files depending on your system

local msg = require 'mp.msg'
local utils = require 'mp.utils'
local settings = {
  --all settings values need to be true or false
  --deletefile and deleteoneonly in this variable is the default behaviour, both will change when using toggle or message
  --unix or windows toggle
  linux = true,
  --activate file removing when starting mpv, default is good to keep as false
  deletefile = false,
  --remove only one file(next closed file), changes deletefile to false after deleting one
  deleteoneonly = true,
  --display osd messages for toggles
  osd_message = true,
  --https://mpv.io/manual/stable/#lua-scripting-end-file
  --accepted EOF reasons to delete a file, change to false to disallow file deletion.
  --if a eof reason is not allowed and deleteoneonly is true it will trigger without deleting the file
  accepted_reasons = {
    ['eof']=true,     --The file has ended. This can (but doesn't have to) include incomplete files or broken network connections under circumstances.
    ['stop']=true,    --Playback was ended by a command.
    ['quit']=true,    --Playback was ended by sending the quit command.
    ['error']=true,   --An error happened. In this case, an error field is present with the error string.
    ['redirect']=true,--Happens with playlists and similar. Details see MPV_END_FILE_REASON_REDIRECT in the C API.
    ['unknown']=true, --Unknown. Normally doesn't happen, unless the Lua API is out of sync with the C API.
  }
}

--run when any file is opened
function on_load()
  local p = mp.get_property("path")
  --get always absolute path to file
  path = utils.join_path(utils.getcwd(), p)
  --ignore protocols with more than one character(non windows file systems) ex http://
  if p:match("^%a%a+:%/%/") then path = nil end
end

--run when any file is closed
function on_close(reason)
  if settings.deletefile and path then
    if settings.deleteoneonly then
      settings.deletefile = false
      output(true)
    end
    if settings.accepted_reasons[reason.reason] then
      local rm = 'rm'
      if not settings.linux then rm = 'del' end
      local response = utils.subprocess({ cancellable=false, args = { rm, path } })
      if response.error == nil and response.status == 0 then
        msg.info('File removed: '..path)
      else
        if response.error == nil then response.error = "" end
        msg.error("There was an error deleting the file: ")
        msg.error("  Status: "..response.status)
        msg.error("  Error: "..response.error)
        msg.error("  stdout: "..response.stdout)
        msg.error("Possible errors are permissions or failure in locating file")
        msg.error("The command that produced the error was the following:")
        msg.error("  "..rm.." "..path)
      end
    else
      msg.info('Unallowed EOF: '..reason.reason)
      if settings.deletefile then output(true) end
    end
  end
end

--toggle settings to the next one. Off, Single, Multiple. Ran on keybind
function toggledelete()
  if settings.deletefile and not settings.deleteoneonly then
    settings.deletefile = false
  elseif not settings.deletefile then
    settings.deletefile = true
    settings.deleteoneonly = true
  elseif settings.deleteoneonly then
    settings.deletefile = true
    settings.deleteoneonly = false
  end
  output()
end

--print the current setting to console and osd
function output(silent)
  if not settings.deletefile then
    outputhelper('Toggled delete off', silent)
  else
    local multiple = 'multiple files'
    if settings.deleteoneonly then multiple = 'one file' end
    outputhelper('Toggled delete on: '..multiple, silent)
  end
end
function outputhelper(string, silent)
  msg.info(string)
  if settings.osd_message and not silent then mp.osd_message(string) end
end

--read settings from a script message
function trashsend(delete, single)
  settings.deletefile = ( delete:lower() == 'true' )
  settings.deleteoneonly = ( single:lower() == 'true' )
  output()
end

mp.register_script_message("trashfileonend", trashsend)
mp.add_key_binding("ctrl+alt+x", "toggledeletefile", toggledelete)
mp.register_event('file-loaded', on_load)
mp.register_event('end-file', on_close)

