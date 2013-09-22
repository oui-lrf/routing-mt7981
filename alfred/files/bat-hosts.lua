#!/usr/bin/lua

local type_id = 64  -- bat-hosts

function get_hostname()
  local hostfile = io.open("/proc/sys/kernel/hostname", "r")
  local ret_string = hostfile:read("*a")
  ret_string = string.gsub(ret_string, "\n", "")
  hostfile:close()
  return ret_string
end

function get_interfaces_names()
  local ret = {}

  for name in io.popen("ls -1 /sys/class/net/"):lines() do
    -- skip loopback ("lo") mac (00:00:00:00:00:00)
    if name ~= "lo" then
      table.insert(ret, name)
    end
  end

  return ret
end

function get_interface_address(name)
  local addressfile = io.open("/sys/class/net/"..name.."/address", "r")
  local ret_string = addressfile:read("*a")
  ret_string = string.gsub(ret_string, "\n", "")
  addressfile:close()
  return ret_string
end


local function generate_bat_hosts()
-- get hostname and interface macs/names
-- then return a table containing valid bat-hosts lines
  local n, i
  local ifaces, ret = {}, {}

  local hostname = get_hostname()

  for n, i in ipairs(get_interfaces_names()) do
    local address = get_interface_address(i)
    ifaces[address] = i
  end

  for mac, iname in pairs(ifaces) do
    table.insert(ret, mac.." "..hostname.."_"..iname.."\n")
  end

  return ret
end

local function publish_bat_hosts()
-- pass a raw chunk of data to alfred
  local fd = io.popen("alfred -s " .. type_id, "w")
  if fd then
    local ret = generate_bat_hosts()
    if ret then
      fd:write(table.concat(ret))
    end
    fd:close()
  end
end

local function write_bat_hosts(rows)
  local content = { "### File generated by alfred-mod-bat-hosts\n" }

  -- merge the chunks from all nodes, de-escaping newlines
  for _, row in ipairs(rows)  do
    local node, value = unpack(row)
    table.insert(content, "# Node ".. node .. "\n")
    table.insert(content, value:gsub("\x0a", "\n") .. "\n")
  end

  -- write parsed content down to disk
  local fd = io.open("/tmp/bat-hosts", "w")
  if fd then
    fd:write(table.concat(content))
    fd:close()
  end
end

local function receive_bat_hosts()
-- read raw chunks from alfred, convert them to a nested table and call write_bat_hosts

  local fd = io.popen("alfred -r " .. type_id)
    --[[ this command returns something like
    { "54:e6:fc:b9:cb:37", "00:11:22:33:44:55 ham_wlan0\x0a00:22:33:22:33:22 ham_eth0\x0a" },
    { "90:f6:52:bb:ec:57", "00:22:33:22:33:23 spam\x0a" },
    ]]--

  if fd then
      local output = fd:read("*a")
      if output then
        assert(loadstring("rows = {" .. output .. "}"))()
        write_bat_hosts(rows)
      end
      fd:close()
  end
end

publish_bat_hosts()
receive_bat_hosts()
