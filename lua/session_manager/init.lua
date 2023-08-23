local config = require('session_manager.config')
local AutoloadMode = require('session_manager.config').AutoloadMode
local utils = require('session_manager.utils')
local Path = require('plenary.path')
local session_manager = {}

--- Apply user settings.
---@param values table
function session_manager.setup(values)
  setmetatable(config, { __index = vim.tbl_extend('force', config.defaults, values) })
end

--- Selects a session a loads it.
---@param discard_current boolean: If `true`, do not check for unsaved buffers.
function session_manager.load_session(discard_current)
  local sessions = utils.get_sessions()
  vim.ui.select(sessions, {
    prompt = 'Load Session',
    format_item = function(item) return utils.shorten_path(item.dir) end,
  }, function(item)
    if item then
      session_manager.autosave_session()
      utils.load_session(item.filename, discard_current)
    end
  end)
end

--- Loads saved used session.
---@param discard_current boolean?: If `true`, do not check for unsaved buffers.
function session_manager.load_last_session(discard_current)
  local last_session = utils.get_last_session_filename()
  if last_session then
    utils.load_session(last_session, discard_current)
  else
    vim.notify("Oops! The last session file doesn't seem to exist anymore. Try to load a specific session file.",
      vim.log.levels.WARN,
      {
        title = "Session Manager"
      }
    )
  end
end

--- Loads a session for the current working directory.
function session_manager.load_current_dir_session(discard_current)
  local cwd = vim.loop.cwd()
  if cwd then
    local session = config.dir_to_session_filename(cwd)
    if session:exists() then
      utils.load_session(session.filename, discard_current)
    end
  end
end

function session_manager.save_current_session()
  local filename = utils.active_session_file
  if filename ~= nil then
    utils.save_session(filename)
  else
    vim.notify(
      'You are not in any active session right now!\nTry other saving options instead.',
      vim.log.levels.ERROR,
      {
        title = "Session Manager"
      }
    )
  end
end

--- Saves a session to a new file for the current working directory.
function session_manager.save_current_session_to_new_file()
  vim.ui.input({
    prompt = 'Provide a Name for the New Session (Empty for a Default Name)',
  },
    function (input)
      local filename
      if input == nil or input == '' then
        filename = utils.dir_to_session_filename().filename
      else
        filename = config.sessions_dir .. input .. '.vim'
      end
      utils.save_session(filename)
    end
  )
end

--- Saves a session to a existing file for the current working directory.
function session_manager.save_current_to_existing_file()
  local sessions = utils.get_sessions()
  local display_names = {}
  for _, session in ipairs(sessions) do
    table.insert(display_names, utils.shorten_path(session.dir))
  end

  vim.ui.select(display_names, {
    prompt = 'Select the File to Be Saved to'
  }, function (choice)
      if choice ~= nil and choice ~= '' then
        local filename = config.sessions_dir .. choice
        utils.save_session(filename)
      end
  end)
end

--- Loads a session based on settings. Executed after starting the editor.
function session_manager.autoload_session()
  if config.autoload_mode ~= AutoloadMode.Disabled and vim.fn.argc() == 0 and not vim.g.started_with_stdin then
    if config.autoload_mode == AutoloadMode.CurrentDir then
      session_manager.load_current_dir_session()
    elseif config.autoload_mode == AutoloadMode.LastSession then
      session_manager.load_last_session()
    end
  end
end

function session_manager.delete_session()
  local sessions = utils.get_sessions()

  local display_names = {}
  for _, session in ipairs(sessions) do
    table.insert(display_names, utils.shorten_path(session.dir))
  end

  vim.ui.select(display_names, { prompt = 'Select and Press <Enter> to Delete a Session' }, function(_, idx)
    if idx then
      Path:new(sessions[idx].filename):rm()
      session_manager.delete_session()
    end
  end)
end

--- Saves a session based on settings. Executed before exiting the editor.
function session_manager.autosave_session()
  if not config.autosave_last_session then
    return
  end

  if config.autosave_only_in_session and not utils.is_session then
    return
  end

  if config.autosave_ignore_dirs and utils.is_dir_in_ignore_list() then
    return
  end

  if not config.autosave_ignore_not_normal or utils.is_restorable_buffer_present() then
    session_manager.save_current_session()
  end
end

return session_manager
