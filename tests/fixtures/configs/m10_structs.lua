local h2o = require "h2odin"

local config = h2o.config()
config.package = "m10s"
config.foreign.import_lib = "m10s"
config.foreign.link_prefix = "rl_"

config.structs.fields = {
  ["BoneInfo.name"] = { tag = 'fmt:"s,0"' },
  ["BoneInfo.parent"] = { type = "i32" },
}
config.structs.align = { Mesh = 16 }

config.structs.field = function(field)
  if field.struct_name == "Mesh" and field.name == "vertexCount" then
    return { type = "c.int" }
  end
  return nil
end

config.procs.params = {
  ["SetConfigFlags.flags"] = { type = "ConfigFlags" },
  ["DrawTexturePro.tint"] = { default = "WHITE" },
}
config.procs.results = {
  GetKeyPressed = { type = "c.int" },
}

config.procs.param = function(param)
  if param.proc_name == "DrawTexturePro" and param.name == "tint" then
    return { type = "Color" }
  end
  return nil
end

return config
