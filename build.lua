local script_path = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script_path, ":p:h")
local backend_dir = vim.fs.joinpath(plugin_root, "backend")
local bin_name = vim.fn.has("win32") == 1 and "keyrics.exe" or "keyrics"

local res = vim.system({ "go", "build", "-o", bin_name, "main.go" }, {
    cwd = backend_dir,
    text = true,
}):wait()

if res.code ~= 0 then
    error("keyrics.nvim: Go build failed:\n" .. (res.stderr or ""))
end
