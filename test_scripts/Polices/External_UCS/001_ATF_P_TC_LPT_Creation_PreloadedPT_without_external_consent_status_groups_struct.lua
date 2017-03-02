---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] External UCS: PreloadedPT without "external_consent_status_groups" struct
--
-- Description:
-- In case:
-- SDL uploads PreloadedPolicyTable without "external_consent_status_groups:
-- [<functional_grouping>: <Boolean>]" -> of "device_data" -> "<device identifier>"
-- -> "user_consent_records" -> "<app id>" section
-- SDL must:
-- a. consider this PreloadedPT as valid (with the pre-conditions of all other valid PreloadedPT content)
-- b. continue working as assigned.
--
-- Preconditions:
-- 1. Stop SDL
-- 2. Modify PreloadedPolicyTable (add 'external_consent_status_groups' section)
-- 3. Start SDL
-- 4. Check SDL status => 0 (SDL is stopped)
--
-- Steps:
-- 1. Remove Local Policy Table
-- 2. Modify PreloadedPolicyTable (remove 'external_consent_status_groups' section)
-- 3. Start SDL
-- 4. Check SDL status
--
-- Expected result:
-- Status = 1 (SDL is running)
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
  config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
  config.defaultProtocolVersion = 2

--[[ Required Shared Libraries ]]
  local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
  local commonSteps = require('user_modules/shared_testcases/commonSteps')
  local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
  local sdl = require('SDL')
  local testCasesForExternalUCS = require('user_modules/shared_testcases/testCasesForExternalUCS')

--[[ General Precondition before ATF start ]]
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
  commonPreconditions:BackupFile("sdl_preloaded_pt.json")

--[[ General Settings for configuration ]]
  Test = require("user_modules/connecttest_resumption")
  require('user_modules/AppTypes')

--[[ Preconditions ]]
  commonFunctions:newTestCasesGroup("Preconditions")

  function Test:StopSDL()
    testCasesForExternalUCS.ignitionOff(self)
  end

  function Test:CheckSDLStatus_1_STOPPED()
    testCasesForExternalUCS.checkSDLStatus(self, sdl.STOPPED)
  end

  function Test.RemoveLPT()
    testCasesForExternalUCS.removeLPT()
  end

  function Test.UpdatePreloadedPT_Add_section()
    local updateFunc = function(preloadedTable)
      preloadedTable.policy_table.device_data = {
        [config.deviceMAC] = {
          user_consent_records = {
            [config.application1.registerAppInterfaceParams.appID] = {
              external_consent_status_groups = {
                Location = false
              }
            }
          }
        }
      }
    end
    testCasesForExternalUCS.updatePreloadedPT(updateFunc)
  end

  function Test.StartSDL()
    StartSDL(config.pathToSDL, config.ExitOnCrash)
    os.execute("sleep 1")
  end

  function Test:CheckSDLStatus_2_STOPPED()
    testCasesForExternalUCS.checkSDLStatus(self, sdl.STOPPED)
  end

  function Test:StopSDL()
    testCasesForExternalUCS.ignitionOff(self)
  end

  function Test.RemoveLPT()
    testCasesForExternalUCS.removeLPT()
  end

  function Test.UpdatePreloadedPT_Remove_section()
    local updateFunc = function(preloadedTable)
      -- whole 'device_data' section is not allowed in PreloadedPT according to data dictionary
      preloadedTable.policy_table.device_data = nil
    end
    testCasesForExternalUCS.updatePreloadedPT(updateFunc)
  end

--[[ Test ]]
  commonFunctions:newTestCasesGroup("Test")

  function Test.StartSDL()
    StartSDL(config.pathToSDL, config.ExitOnCrash)
    os.execute("sleep 1")
  end

  function Test:CheckSDLStatus_3_RUNNING()
    testCasesForExternalUCS.checkSDLStatus(self, sdl.RUNNING)
  end

--[[ Postconditions ]]
  commonFunctions:newTestCasesGroup("Postconditions")

  function Test.StopSDL()
    StopSDL()
  end

  function Test.RestorePreloadedFile()
    commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
  end

return Test
