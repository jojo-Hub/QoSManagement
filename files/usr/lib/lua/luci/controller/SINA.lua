module("luci.controller.SINA", package.seeall)

function index()
     entry({"admin", "SINA"}, firstchild(), "SINA", 60).dependent=false
     entry({"admin", "SINA", "ngcontrol"}, template("SINA/ngcontrol"), _("UMTS Control"), 1)
     entry({"admin", "SINA", "qosmanagement"}, template("SINA/qosmanagement"), _("QoS Management"), 2)

-- nGcontrol functions
     entry({"admin", "SINA", "statusOf"}, call("_statusOf"), nil).leaf = true
     entry({"admin", "SINA", "statusChange"}, call("_statusChange"), nil).leaf = true

-- QoSManagement functions
     entry({"admin", "SINA", "listQoSEntries"}, call("_listQoSEntries"), nil).leaf = true
     entry({"admin", "SINA", "deleteQoSEntry"}, call("_deleteQoSEntry"), nil).leaf = true
     entry({"admin", "SINA", "addQoSEntry"}, call("_addQoSEntry"), nil).leaf = true

end



--***********************************************************************
-- nGcontrol functions implementation

  function _statusChange(action, interface)

    os.execute("logger -t nGctrl 'user requested to "..action.." UMTS"..interface.."'")

    if action == 'Disable' then
      os.execute("/usr/share/nGcontrol/dongleOff "..interface)
    elseif action == 'Enable' then
      os.execute("/usr/share/nGcontrol/dongleOn "..interface)
      os.execute("/usr/share/nGcontrol/mwan/dongleRestart "..interface)
    else   
      os.execute("/usr/share/nGcontrol/mwan/dongleRestart "..interface)
    end
  end


  function _statusOf(iface)

    local mArray = {}
        local IP = "192.168."..iface..".1"

    require("uci")
    local huaweiLib = require("huaweiLib")
    local netm = require("luci.model.network").init() -- to get the interfaces' uptime

    x = uci.cursor()

    -- check whether iface is enabled
    local interfaceEnabled = (x:get("mwan3", "UMTS"..iface, "enabled") == "1")
    if not interfaceEnabled then
      mArray.Enabled = 0
    else
      mArray.Enabled = 1

      -- check whether iface can be reached
      local gateways = huaweiLib.getDefaultGateways()
      if not gateways[IP] then
        mArray.Route = 0
      else
        -- we can read info of iface since route exists to
        mArray.Route = 1
        mArray.Status = huaweiLib.queryStatus(IP)
        -- and add uptimeinfo (in secondes, will be parsed from javaScript)
        local netm = require("luci.model.network").init()
        local net = netm:get_network("UMTS"..iface)
        mArray.Uptime = tonumber(net:uptime())
        -- and add ResetAttempts
        mArray.retryAttempts = x:get("mwan3", "UMTS"..iface, "retryAttempt")
        mArray.retryMax = x:get("mwan3", "config", "retryMax")

      end

    end

    -- send gathered info via json
    luci.http.prepare_content("application/json")
    luci.http.write_json(mArray)

  end



--***********************************************************************
-- QoSManagement function implementation

  function _listQoSEntries(prio)

    local mArray = {}
    local QoSMLib = require "QoSMLib"

    mArray = QoSMLib.getPrioList(prio)

    -- for the result table, remove the entries which are n/a
    for key,value in pairs(mArray) do
      if mArray[key].host == "n/a" then
        mArray[key].host = nil
        mArray[key].MAC = nil
        mArray[key].device= nil
        mArray[key].IP= nil
      end
    end

    -- send gathered info via json
    luci.http.prepare_content("application/json")
    luci.http.write_json(mArray)

  end


  function _deleteQoSEntry(IP)

    local mArray = {}
    local QoSMLib = require "QoSMLib"

    mArray = QoSMLib.deleteIP(IP)

    luci.http.prepare_content("application/json")
    luci.http.write_json(mArray)

  end


  function _addQoSEntry(hostname, MAC, prio, device)

    local mArray = {}
    local QoSMLib = require "QoSMLib"

    mArray = QoSMLib.add(hostname, MAC, prio, device)

    luci.http.prepare_content("application/json")
    luci.http.write_json(mArray)

  end
