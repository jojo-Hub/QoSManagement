--  Managing a list of QoS entries with automatic IP assignment.
--
--  "n/a" serves as a placeholder in case an entry was deleted.
--  On insertion, the program looks for lowest "n/a" entry and will
--  insert there. If no "n/a" entry is there, the entry will be
--  inserted at the end of the current list.
--
-- the public functions are:
--     - QoSMLib.add(hostname, MAC, prio, device)
--     - QoSMLib.deleteIP(IP)
--     - QoSMLib.printPrioList(prio)
--     - QoSMLib.printAll()
--     - QoSMLib.changePrio(IP, newPrio)

local QoSMLib = {}


----------------------------------------------------------------------------
-- private library functions
----------------------------------------------------------------------------

local function getIP(index, prio)

  local offset=0

  if     prio =="default" then offset=128
  elseif prio=="high"     then offset=144
  elseif prio=="priority" then offset=160
  elseif prio=="express"  then offset=176
  else return nil
  end

  local num = (index-1) + offset*256  --lua tables start at 1!
  local third_octett = math.floor(num/256)
  local fourth_octett = num - third_octett*256
  return ("172.16." .. third_octett .. "." .. fourth_octett)

end



local function getIndex(IP, prio) --TODO: improve by using index calculation

  local index = 1
  while getIP(index, prio) ~= IP do
    index = index + 1
  end
  
  return index

end



local function readList(fileName)

  local file = io.open(fileName, "r")
  local database = { }

  for l in io.lines(fileName) do
    local h, m, d = l:match '(%S+)%s+(%S+)%s+(%S+)'
    table.insert(database, { host=h, MAC=m, device=d })
  end

  file:close()
  return database

end



local function writeList(db, fileName)

  local file = io.open(fileName, "w")

  for key,value in pairs(db) do
    if db[key].host == nil then
      file:write("n/a n/a n/a\n")
    else
      file:write(db[key].host, " ", db[key].MAC, " ", db[key].device, "\n")
    end
  end

  file:close()
  return true

end



local function findInsertPosition(db)

  local pos = 1

  for key, v in pairs(db) do
    if db[key].host == "n/a" then
        table.remove(db, key) 
      return key
    end
    pos = key+1
  end

  return pos

end



local function insertEntry(db, h, m, d, prio)

  local key = findInsertPosition(db)
  if (key > 4096) then
    return false
  else
    table.insert(db, key, { host=h, MAC=m, device=d })
    return getIP(key, prio)
  end

end



local function restartDNS()
  os.execute("/etc/init.d/dnsmasq reload")
  print("  DHCP Server restarted. Reconnect the device to make changes effective.\n")
end



-- test whether te ised MAC adress has a valid format
local function checkMAC(MAC)
  return MAC==string.match(MAC, "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
end



-- test whether a valid priority is used
local function checkPrio(prio)
  if prio=="default" or prio=="high" or prio=="priority" or prio=="express" then
    return true
  else
    return false
  end
end



-- look for MAC or hostname in /etc/ethers
local function MACalreadyAssigned(MAC)

  local file = io.open("/etc/ethers", "r")  
  local ethers = { }

  for l in io.lines("/etc/ethers") do
    local m, h = l:match '(%S+)%s+(%S+)'
    table.insert(ethers, { MAC=m, host=h })
  end
  file:close()

  for key, v in pairs(ethers) do
    if ethers[key].MAC == MAC then
      return true
    end
  end
  return false

end



-- look for IP in /etc/hosts
local function IPAlreadyAssigned(IP)

  local file = io.open("/etc/hosts", "r")  
  local hosts = { }

  for l in io.lines("/etc/hosts") do
    local i, h = l:match '(%S+)%s+(%S+)'
    table.insert(hosts, { IP=i, host=h })
  end
  file:close()

  for key, v in pairs(hosts) do
    if hosts[key].IP == IP then
      return true
    end
  end
  return false

end



-- look for hostname in /etc/hosts
local function hostnameAlreadyAssigned(hostname)

  local file = io.open("/etc/hosts", "r")  
  local hosts = { }

  for l in io.lines("/etc/hosts") do
    local i, h = l:match '(%S+)%s+(%S+)'
    table.insert(hosts, { IP=i, host=h })
  end
  file:close()

  for key, v in pairs(hosts) do
    if hosts[key].host == hostname then
      return true
    end
  end
  return false

end



local function getPrioOfIP(IP)

  local first, second, third_str, fourth_str = IP:match("([^.]+).([^.]+).([^.]+).([^.]+)")

  third = tonumber(third_str)
  fourth = tonumber(fourth_str)

  if     third >=128 and third <=143 and fourth>=0 and fourth <=255 then return "default"
  elseif third >=144 and third <=159 and fourth>=0 and fourth <=255 then return "high"
  elseif third >=160 and third <=175 and fourth>=0 and fourth <=255 then return "priority"
  elseif third >=176 and third <=191 and fourth>=0 and fourth <=255 then return "express"
  else return nil
  end

end



local function deleteEntry(db, key)

  if db[key] == nil or db[key].host == "n/a" then  --check whether entry is there
    print("  Entry not there. Nothing to delete.")
    return 0
  else
    local hostname = db[key].host
    db[key].host = "n/a"
    db[key].MAC = "n/a"
    db[key].device = "n/a"
    return hostname
  end

end



local function deleteDNSassignment(hostname)
  os.execute("sed -i '/"..hostname.."/d' /etc/ethers")
  os.execute("sed -i '/"..hostname.."/d' /etc/hosts")
  return true
end


----------------------------------------------------------------------------
-- public library functions
----------------------------------------------------------------------------

function QoSMLib.add(hostname, MAC, prio, device)
  print()

--do some checks
  if not checkMAC(MAC) then
    print("  Invalid MAC, check characters and format (AA:BB:CC:DD:EE:FF).")
    return 0
  end

  if not checkPrio(prio) then
    print("  Invalid priority.")
    return 0
  end

  if MACalreadyAssigned(MAC) then
    print("  MAC " .. MAC .. " is alredy in use. Abort.\n")
    return false
  end

  if hostnameAlreadyAssigned(hostname) then
    print("  Hostname " .. hostname .. " is alredy in use. Abort.\n")
    return false
  end


  local ListName = "/usr/share/QoSM/QoS_"..prio
  local db = readList(ListName)
  local IP = insertEntry(db, hostname, MAC, device, prio)
  local written = writeList(db, ListName)
  
  if IP ~= nil and written then
    os.execute("echo '" .. MAC .. " " .. hostname .. "' >> /etc/ethers")
    os.execute("echo '" .. IP .. " " .. hostname .. "' >> /etc/hosts")
    print("  Successfully assigned " .. hostname .. " (" .. MAC .. ") to " ..prio .. "/" .. IP)
    restartDNS()
    print()
    return true
  else
    print("  Error adding host to list. Maybe maximum reached?\n")
    return false
  end

end



function QoSMLib.deleteIP(IP)
  print()

  if not IPAlreadyAssigned(IP, nil) then
    print("  Could not find IP to delete. Abort.\n")
    return false
  end

  local prio = getPrioOfIP(IP)
  local ListName = "/usr/share/QoSM/QoS_" .. prio
  local db = readList(ListName)
  local key = getIndex(IP, prio)

  print("  Will delete '" .. db[key].host .. "' (MAC " .. db[key].MAC .. ").")
  print("  Continue? [Y/N]")
  io.flush()
  if io.read() == "Y" then
    hostname = deleteEntry(db, key)
    if hostname ~= nil then
      writeList(db, ListName)
      deleteDNSassignment(hostname)
      print("  Sucessfully deleted.")
      restartDNS()
      print()
      return true
    else
      print("  Error deleting host from list.\n")
      return false
    end
  end

end



function QoSMLib.printPrioList(prio)
  local fileName = "/usr/share/QoSM/QoS_" .. prio
  local db = readList(fileName)

-- get the length of longest hostname or "hostname" for propper aligning
  local maxLength = 0
  for key,value in pairs(db) do
    local localLength = string.len(db[key].host)
    if( localLength > maxLength ) then maxLength = localLength end
  end
  maxLength = maxLength + 2 

  print(" QoS priority '" .. prio .. "':")
  --local tableHead = "     hostname" .. string.rep(" ", maxLength-8) .. "MAC address        assigned IP     device"
  --print(tableHead)
  --print("    " .. string.rep("-", string.len(tableHead)-2) )
  for key,value in pairs(db) do
      if db[key].host ~= "n/a" then
        local hostStr = db[key].host
        local IPStr = getIP(key, prio)
        io.write("     " .. hostStr .. string.rep(" ", maxLength - string.len(hostStr)))
        io.write(db[key].MAC .. "  ")
        io.write(IPStr .. string.rep(" ", 14 + 2 - string.len(IPStr)))
        print(db[key].device)
      end
  end
  print()
end


function QoSMLib.printAll()
  local prio = {"default", "high", "priority", "express"}
  for i = 1, 4 do
    QoSMLib.printPrioList(prio[i])
    print()
  end
end



function QoSMLib.changePrio(IP, newPrio)

  if not IPAlreadyAssigned(IP, nil) then
    print("  Could not find IP to change priority. Abort.\n")
    return false
  end

  local oldPrio = getPrioOfIP(IP)
  local ListName = "/usr/share/QoSM/QoS_" .. oldPrio
  local db = readList(ListName)
  local key = getIndex(IP, oldPrio)

  local MAC = db[key].MAC
  local device = db[key].device

-- delete the current entry
  local hostname = deleteEntry(db, key)
  if hostname ~= nil then
    writeList(db, ListName)
    deleteDNSassignment(hostname)
  else
    print("  Error deleting host from list.\n")
    return false
  end

-- recreate the entry with the new prio
  local ListName = "/usr/share/QoSM/QoS_"..newPrio
  local db = readList(ListName)
  local IP = insertEntry(db, hostname, MAC, device, newPrio)
  local written = writeList(db, ListName)
  
  if IP ~= nil and written then
    os.execute("echo '" .. MAC .. " " .. hostname .. "' >> /etc/ethers")
    os.execute("echo '" .. IP .. " " .. hostname .. "' >> /etc/hosts")
    print("  Successfully changed " .. hostname .. " (" .. MAC .. ") to " .. newPrio .. "/" .. IP)
    restartDNS()
    print()
    return true
  else
    print("  Error adding host to list. Maybe maximum reached?\n")
    return false
  end

end



return QoSMLib
