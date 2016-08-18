--  Managegin List of QoS Entries withautomatic IP assignment.
--
--  "n/a" serves as a placeholder in case an entry was deleted.
--  On insertion, the Program looks for lowest "n/a" entry and will
--  insert there. If no "n/a" entry is there, the entry will be
--  inserted at the end of the current list.
--


function getIP(index)
  local num = (index-1) + 51*256  --lua tables start at 1:
  local third_octett = math.floor(num/256)
  local fourth_octett = num - third_octett*256
  return ("172.16." .. third_octett .. "." .. fourth_octett)
end



function getIndex(IP)
  local first, second, third, fourth = IP:match("([^.]+).([^.]+).([^.]+).([^.]+)")
  return ( (third-51)*256 + fourth +1 )
end



function readList(fileName)

  local file = io.open(fileName, "r")
  
  local database = { }
  for l in io.lines("QoSList") do
    local h, m, p, d = l:match '(%S+)%s+(%S+)%s+(%S+)%s+(%S+)'
    table.insert(database, { host=h, MAC=m, prio=p, device=d })
  end

  file:close()
  return database

end



function writeList(db, fileName)

  local file = io.open(fileName, "w")

  for key,value in pairs(db) do
    if db[key].host == nil then
      file:write("n/a n/a n/a n/a\n")
    else
      file:write(db[key].host, " ", db[key].MAC, " ", db[key].prio, " ", db[key].device, "\n")
    end
  end

  file:close()
  return 1

end



function printCurrentList()

  local db = readList("QoSList")
  print()
  print("hostname    ", "MAC address      ", "assigned IP  ", "prio", "type")
  print("---------------------------------------------------------------------")
  for key,value in pairs(db) do
    if db[key].host ~= "n/a" then
      print(string.format("%s_%s\t%s\t%s\t%s\t%s", db[key].host, db[key].device, db[key].MAC, getIP(key), db[key].prio, db[key].device))
    end
  end
  print()
end



local function findInsertPosition(db)
  for key, v in pairs(db) do
    if db[key].host == "n/a" then
      return key
    end
  end
  return nil
end


function insertEntry(h, m, p, d)

--find the first apperance of 'nil'
  local db = readList("QoSList")
  local key = findInsertPosition(db)
  
  if key ~= nil then
    db[key].host = h
    db[key].MAC = m
    db[key].prio = p
    db[key].device = d
  else
    table.insert(db, { host=h, MAC=m, prio=p, device=d })
  end

  writeList(db, "QoSList")

end



function deleteEntry(IP)

  local db = readList("QoSList")
  local key = getIndex(IP)

  if db[key] == nil or db[key].host == "n/a" then  --check whether entry is there
    print("Entry not there. Nothing to delete.")
    return nil
  else

    print("Will delete '" .. db[key].host .. "' (MAC " .. db[key].MAC .. ", IP " .. getIP(key) .. ").")
    print("Continue? [Y/N]")
    io.flush()
    if io.read() == "Y" then
      db[key].host = "n/a"
      db[key].MAC = ""
      db[key].prio = ""
      db[key].device = ""

      writeList(db, "QoSList")
      return 1
    else
      return 0
    end

  end

end




printCurrentList()

deleteEntry("172.16.51.1")
insertEntry("philipp", "af:24:d7:b9:c0:90", "low", "PC")
