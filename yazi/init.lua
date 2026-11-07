-- Persistent bookmarks managed by h-hg/yamb.
-- All paths below were checked against this user's Windows special folders.
local home = os.getenv("USERPROFILE")
local config = os.getenv("YAZI_CONFIG_HOME") or (home .. "\\.config\\yazi")

require("yamb"):setup {
  jump_notify = true,
  cli = "fzf",
  keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
  path = config .. "\\bookmark",
}
