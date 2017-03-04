module("luci.controller.services.qosmanagement", package.seeall)

function index()
     entry({"admin", "services"}, firstchild(), "Services", 60).dependent=false
     entry({"admin", "services", "qosmanagement"}, template("services/qosmanagement"), _("QoS Management"), 1)

-- QoSManagement functions
     entry({"admin", "services", "qosmanagement", "listQoSEntries"}, call("_listQoSEntries"), nil).leaf = true
     entry({"admin", "services", "qosmanagement", "deleteQoSEntry"}, call("_deleteQoSEntry"), nil).leaf = true
     entry({"admin", "services", "qosmanagement", "addQoSEntry"}, call("_addQoSEntry"), nil).leaf = true

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
