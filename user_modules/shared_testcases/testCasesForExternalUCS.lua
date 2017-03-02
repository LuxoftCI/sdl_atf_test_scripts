---------------------------------------------------------------------------------------------
-- Common functions for External_UCS test scripts
---------------------------------------------------------------------------------------------
local mobile_session = require("mobile_session")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local json = require("modules/json")
local sdl = require('SDL')

local utils = { }

-- [[ Variables ]]

  utils.HMIAppIds = { }
  utils.pts = nil

-- [[ Functions ]]

--[[@createTableFromJsonFile: Create table from .json file
--! @parameters:
--! file - input file
--]]
  function utils.createTableFromJsonFile(file)
    local f = io.open(file, "r")
    local content = f:read("*all")
    f:close()
    return json.decode(content)
  end

--[[@createJsonFileFromTable: Create .json file from table
--! @parameters:
--! table - input table
--! file - output file
--]]
  function utils.createJsonFileFromTable(table, file)
    local f = io.open(file, "w")
    f:write(json.encode(table))
    f:close()
  end

--[[@checkSDLStatus: Checks SDL status against defined one
--! @parameters:
--! expStatus - expected status of SDL (0 - STOPPED, 1 - RUNNING)
--]]
  function utils.checkSDLStatus(test, expStatus)
    local actStatus = sdl:CheckStatusSDL()
    print("SDL status: " .. tostring(actStatus))
    if actStatus ~= expStatus then
      local msg = "Expected SDL status: " .. expStatus .. ", actual: " .. actStatus
      test:FailTestCase(msg)
    end
  end

--[[@removeLPT: Delete Local Policy Table
--! @parameters: NO
--]]
  function utils.removeLPT()
    local data = { "AppStorageFolder", "AppInfoStorage" }
    for _, v in pairs(data) do
      os.execute("rm -rf " .. commonPreconditions:GetPathToSDL()
        .. commonFunctions:read_parameter_from_smart_device_link_ini(v))
    end
  end

--[[@removePTS: Delete Policy Table Snapshot
--! @parameters: NO
--]]
  function utils.removePTS()
    local filePath = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath") ..
      "/" .. commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
    os.execute("rm -rf " .. filePath)
  end

  local function updatePTU()
    local appId = config.application1.registerAppInterfaceParams.appID
    utils.pts.policy_table.consumer_friendly_messages.messages = nil
    utils.pts.policy_table.device_data = nil
    utils.pts.policy_table.module_meta = nil
    utils.pts.policy_table.usage_and_error_counts = nil
    utils.pts.policy_table.app_policies[appId] = {
      keep_context = false,
      steal_focus = false,
      priority = "NONE",
      default_hmi = "NONE"
    }
    utils.pts.policy_table.app_policies[appId]["groups"] = { "Base-4", "Base-6" }
    utils.pts.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
    utils.pts.policy_table.module_config.preloaded_pt = nil
  end

  local function ptu(test, status)
    local policy_file_name = "PolicyTableUpdate"
    local policy_file_path = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
    local ptu_file_name = os.tmpname()
    local requestId = test.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
    EXPECT_HMIRESPONSE(requestId)
    :Do(function()
        test.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
          { requestType = "PROPRIETARY", fileName = policy_file_name })
        utils.createJsonFileFromTable(utils.pts, ptu_file_name)
        EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", { status = "UPDATING" }, { status = status }):Times(2)
        test.mobileSession1:ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
        :Do(function()
            local corIdSystemRequest = test.mobileSession1:SendRPC("SystemRequest",
              { requestType = "PROPRIETARY", fileName = policy_file_name }, ptu_file_name)
            EXPECT_HMICALL("BasicCommunication.SystemRequest")
            :Do(function(_, d)
                test.hmiConnection:SendResponse(d.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
                test.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
                  { policyfile = policy_file_path .. "/" .. policy_file_name })
              end)
              test.mobileSession1:ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS"})
          end)
      end)
    os.remove(ptu_file_name)
  end

--[[@startSession: Start mobile session
--! @parameters:
--! id - session number (1, 2 etc.) (mandatory)
--]]
  function utils.startSession(test, id)
    test["mobileSession"..id] = mobile_session.MobileSession(test, test.mobileConnection)
    test["mobileSession"..id]:StartService(7)
  end

--[[@registerApp: Register application
--! @parameters:
--! id - application number (1, 2 etc.), equals to session number (mandatory)
--]]
  function utils.registerApp(test, id)
    local RAIParams = config["application"..id].registerAppInterfaceParams
    local corId = test["mobileSession"..id]:SendRPC("RegisterAppInterface", RAIParams)
    EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
      { application = { appName = RAIParams.appName } })
    :Do(function(_, d)
        utils.HMIAppIds[RAIParams.appID] = d.params.application.appID
      end)
    test["mobileSession"..id]:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
    :Do(function()
        test["mobileSession"..id]:ExpectNotification("OnHMIStatus",
          { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
        test["mobileSession"..id]:ExpectNotification("OnPermissionsChange")
      end)
  end

--[[@activateApp: Activate application and start Local Policy Table update
--! @parameters:
--! id - application number (1, 2 etc.), equals to session number (mandatory)
--! status - expected final status ('UPDATE_NEEDED', 'UP_TO_DATE')
--! updateFunc - function to update specific sections in PTU file
--! that has to be passed as an input parameter
--]]
  function utils.activateApp(test, id, status, updateFunc)
    local appId = config["application"..id].registerAppInterfaceParams.appID
    local reqId = test.hmiConnection:SendRequest("SDL.ActivateApp", { appID = utils.HMIAppIds[appId] })
    EXPECT_HMIRESPONSE(reqId)
    :Do(function(_, d1)
        if d1.result.isSDLAllowed ~= true then
          local reqId2 = test.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
            { language = "EN-US", messageCodes = { "DataConsent" } })
          EXPECT_HMIRESPONSE(reqId2)
          :Do(function()
              test.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
                { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
              EXPECT_HMICALL("BasicCommunication.ActivateApp")
              :Do(function(_, d2)
                  test.hmiConnection:SendResponse(d2.id,"BasicCommunication.ActivateApp", "SUCCESS", { })
                  test["mobileSession"..id]:ExpectNotification("OnHMIStatus",
                    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
                end)
            end)
        end
      end)
    EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
    :Do(function(_, d)
        utils.pts = utils.createTableFromJsonFile(d.params.file)
        if status then
          test.hmiConnection:SendResponse(d.id, d.method, "SUCCESS", { })
          updatePTU()
          if updateFunc then
            updateFunc(utils.pts)
          end
          ptu(test, status)
        end
      end)
  end

--[[@updatePreloadedPT: Update PreloadedPT file
--! @parameters:
--! updateFunc - function to update specific sections in PreloadedPT file
--! that has to be passed as an input parameter
--]]
  function utils.updatePreloadedPT(updateFunc)
    local preloadedFile = commonPreconditions:GetPathToSDL() .. "sdl_preloaded_pt.json"
    local preloadedTable = utils.createTableFromJsonFile(preloadedFile)
    preloadedTable.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
    if updateFunc then
      updateFunc(preloadedTable)
    end
    utils.createJsonFileFromTable(preloadedTable, preloadedFile)
  end

--[[@ignitionOff: Perform Igninition Off
--! @parameters: NO
--]]
  function utils.ignitionOff(test)
    test.hmiConnection:SendNotification("BasicCommunication.OnExitAllApplications", { reason = "IGNITION_OFF" })
    StopSDL()
  end

return utils
