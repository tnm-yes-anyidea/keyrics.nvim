-- keyrics.nvim/build.lua
local root = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local backend_dir = root .. "/backend"
local bin_name = vim.fn.has("win32") == 1 and "keyrics.exe" or "keyrics"

if vim.system then
    local res = vim.system({ "go", "build", "-o", bin_name, "main.go" }, { cwd = backend_dir }):wait()
    if res.code ~= 0 then
        error("keyrics.nvim: Go build failed:\n" .. (res.stderr or ""))
    end
else
    local job = vim.fn.jobstart({ "go", "build", "-o", bin_name, "main.go" }, { cwd = backend_dir })
    if vim.fn.jobwait({ job })[1] ~= 0 then
        error("keyrics.nvim: Go build failed")
    end
end
