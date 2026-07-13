local h2o = require "h2odin"

local config = h2o.config()
config.package = "member_action_precedence"
config.type_mode = "idiomatic"
config.foreign.import_lib = "member_action_precedence"
config.output_folder = "generated"

config.procs.params = {
  ["BorrowOrSpell.value"] = { by_ptr = true },
  ["MultiOrSpell.values"] = { pointer = "multi" },
}

config.procs.param = function(param)
  if param.proc_name == "BorrowOrSpell" and param.name == "value" then
    return { type = "^c.int" }
  end
  if param.proc_name == "MultiOrSpell" and param.name == "values" then
    return { type = "[^]c.int" }
  end
  return nil
end

config.inputs = { "../member_action_precedence.h" }
return config
