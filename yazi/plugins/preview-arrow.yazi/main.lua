--- @since 26.8.15
--- @sync entry

return {
  entry = function(_, job)
    local step = tonumber(job.args[1]) or 1
    if rt.mgr.ratio[3] == 9999 then
      ya.emit("seek", { step })
    else
      ya.emit("arrow", { step })
    end
  end,
}
