print("\27[31m SDL crushes with DCHECK. Some tests are commented. After resolving uncomment tests!\27[0m")
--ATF defect: APPLINK-28830 : Worng check of RAI params in TC for regsiter app interface(TC0x)

config.defaultProtocolVersion = 2
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.SDLStoragePath = config.pathToSDL .. "storage/"
---------------------------------------------------------------------------------------------
---------------------------- Required Shared libraries --------------------------------------
---------------------------------------------------------------------------------------------

	local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
	local commonSteps = require('user_modules/shared_testcases/commonSteps')
	local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
	local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')
		
	DefaultTimeout = 3
	local iTimeout = 2000
	local commonPreconditions = require ('/user_modules/shared_testcases/commonPreconditions')


---------------------------------------------------------------------------------------------
------------------------- General Precondition before ATF start -----------------------------
---------------------------------------------------------------------------------------------
	-- Precondition: remove policy table and log files
	commonSteps:DeleteLogsFileAndPolicyTable()


---------------------------------------------------------------------------------------------
---------------------------- General Settings for configuration----------------------------
---------------------------------------------------------------------------------------------
	Test = require('connecttest')

	require('cardinalities')
	local events = require('events')  
	local mobile_session = require('mobile_session')
	require('user_modules/AppTypes')
	local isReady = require('user_modules/IsReady_Template/isReady')

	local resultCode = "SUCCESS"

---------------------------------------------------------------------------------------------
-------------------------------------------Common variables-----------------------------------
---------------------------------------------------------------------------------------------
	local params_RAI = commonFunctions:cloneTable(isReady.params_RAI)

---------------------------------------------------------------------------------------------
-------------------------------------------Preconditions-------------------------------------
---------------------------------------------------------------------------------------------

--Not applicable

-----------------------------------------------------------------------------------------------
-------------------------------------------TEST BLOCK I----------------------------------------
--------------------------------Check normal cases of Mobile request---------------------------
-----------------------------------------------------------------------------------------------

-- Not applicable for '..tested_method..' HMI API.



----------------------------------------------------------------------------------------------
----------------------------------------TEST BLOCK II-----------------------------------------
-----------------------------Check special cases of Mobile request----------------------------
----------------------------------------------------------------------------------------------

-- Not applicable for '..tested_method..' HMI API.

-----------------------------------------------------------------------------------------------
-------------------------------------------TEST BLOCK III--------------------------------------
----------------------------------Check normal cases of HMI response---------------------------
-----------------------------------------------------------------------------------------------

--List of CRQs:
	--APPLINK-20918: [GENIVI] VR interface: SDL behavior in case HMI does not respond to IsReady_request or respond with "available" = false
		-- 1. HMI respond '..tested_method..' (false) -> SDL must return 'UNSUPPORTED_RESOURCE, success:false' to all single VR-related RPC
		-- 2. HMI respond '..tested_method..' (false) and app sends RPC that must be spitted -> SDL must NOT transfer VR portion of spitted RPC to HMI
		-- 3. HMI does NOT respond to '..tested_method..'_request -> SDL must transfer received RPC to HMI even to non-responded VR module

--List of parameters in '..tested_method..' response:
	--Parameter 1: correlationID: type=Integer, mandatory="true"
	--Parameter 2: method: type=String, mandatory="true" (method = "'..tested_method..'") 
	--Parameter 3: resultCode: type=String Enumeration(Integer), mandatory="true" 
	--Parameter 4: info/message: type=String, minlength="1" maxlength="10" mandatory="false" 
	--Parameter 5: available: type=Boolean, mandatory="true"
-----------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------				
-- Cases 2: HMI does not sends '..tested_method..' response or send invalid response
-----------------------------------------------------------------------------------------------

	-----------------------------------------------------------------------------------------------
	--CRQ #1: APPLINK-25064: [RegisterAppInterface] SDL behavior in case HMI does NOT respond to IsReady request
	-- Requirement is applicable for VR; UI; TTS; VehicleInfo
	-- Requirement is not applicable for Navigation
	--Verification criteria:	
		-- In case HMI does NOT respond to <Interface>.IsReady_request to SDL (<Interface>: VehicleInfo, TTS, UI, VR)
		-- and mobile app sends RegisterAppInterface_request to SDL
		-- and SDL successfully registers this application (see req-s # APPLINK-16420, APPLINK-16251, APPLINK-16250, APPLINK-16249, APPLINK-16320, APPLINK-15686, APPLINK-16307)
		-- SDL must:
		-- provide the value of <Interface>-related params:
		-- a. either received from HMI via <Interface>.GetCapabilities response (please see APPLINK-24325, APPLINK-24102, APPLINK-24100, APPLINK-23626)
		-- b. either retrieved from 'HMI_capabilities.json' file
	-----------------------------------------------------------------------------------------------
	local function RegisterApplication_Check_Interfaces_Parameters_From_HMI_capabilities_json(TestCaseName)
	
		--List of resultCodes: APPLINK-16420 SUCCESS, APPLINK-16251 WRONG_LANGUAGE, APPLINK-16250 WRONG_LANGUAGE languageDesired, APPLINK-16249 WRONG_LANGUAGE hmiDisplayLanguageDesired, APPLINK-16320 UNSUPPORTED_RESOURCE unavailable/not supported component, APPLINK-15686 RESUME_FAILED, APPLINK-16307 WARNINGS, true
		
		-- APPLINK-16420 SUCCESS
		Test["TC01_"..TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_SUCCESS"] = function(self)
			local local_paramsRAI = params_RAI
			commonTestCases:DelayedExp(iTimeout)
			
			--mobile side: RegisterAppInterface request
			local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)

			--hmi side: expect BasicCommunication.OnAppRegistered request
			EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
			{
				application=
				{
					appName=config.application1.registerAppInterfaceParams.appName
				}
			})
			:Do(function(_,data)
				self.appName=data.params.application.appName
				self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
			end)

			--mobile side: expect response
			-- SDL sends Interface-related parameters to mobile app with value from HMI_capabilities_json
			local_paramsRAI.success = true
			local_paramsRAI.resultCode = "SUCCESS"
		
			self.mobileSession:ExpectResponse(CorIdRegister, local_paramsRAI)
			
			--mobile side: expect notification
			self.mobileSession:ExpectNotification("OnHMIStatus", { systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"})
		end				
		--[[TODO: Shall be uncommented when SDL Dcheck is fixed Additional investigation is needed. 
		-- Should be checked on last commit and defect to be created
		--DCHECK failed with "result" [StartAppHmiStateResumption][/home/istoimenova/Gen420_SmartDeviceLinkCore/sdl_core/src/components/application_manager/src/resumption/resume_ctrl_impl.cc:354]
		commonSteps:UnregisterApplication("Postcondition_UnregisterApplication_SUCCESS")
		
		-- APPLINK-16320 UNSUPPORTED_RESOURCE unavailable/not supported component: It is not applicable for RegisterAppInterface because RegisterAppInterface is not split able request
		
		--APPLINK-16251 WRONG_LANGUAGE
		--APPLINK-16250 WRONG_LANGUAGE languageDesired
		Test["TC01_"..TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_WRONG_LANGUAGE"] = function(self)
			
			local local_paramsRAI = params_RAI
			commonTestCases:DelayedExp(iTimeout)
			
			--Set language  = "RU-RU"
			local parameters = commonFunctions:cloneTable(config.application1.registerAppInterfaceParams)
			parameters.languageDesired = "RU-RU"
	
			--mobile side: RegisterAppInterface request
			local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", parameters)

			--hmi side: expect BasicCommunication.OnAppRegistered request
			EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
			{
				application=
				{
					appName=config.application1.registerAppInterfaceParams.appName
				}
			})
			:Do(function(_,data)
				self.appName=data.params.application.appName
				self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
			end)
			
			--mobile side: expect response
			-- SDL sends Interface-related parameters to mobile app with value from HMI_capabilities_json
			local_paramsRAI.success = true
			local_paramsRAI.resultCode = "WRONG_LANGUAGE"
			
			self.mobileSession:ExpectResponse(CorIdRegister, local_paramsRAI)
			
			--mobile side: expect notification
			self.mobileSession:ExpectNotification("OnHMIStatus", { systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"})	 
		end	
		
		commonSteps:UnregisterApplication("Postcondition_UnregisterApplication_WRONG_LANGUAGE")

		--APPLINK-16249 WRONG_LANGUAGE hmiDisplayLanguageDesired: It is for UI interface only.
		Test["TC01_"..TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_WRONG_LANGUAGE1"] = function(self)
			
			local local_paramsRAI = params_RAI
			commonTestCases:DelayedExp(iTimeout)
			
			--Set hmiDisplayLanguageDesired  = "RU-RU"
			local parameters = commonFunctions:cloneTable(config.application1.registerAppInterfaceParams)
			parameters.hmiDisplayLanguageDesired = "RU-RU"
	
			--mobile side: RegisterAppInterface request
			local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", parameters)

			--hmi side: expect BasicCommunication.OnAppRegistered request
			EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
			{
				application=
				{
					appName=config.application1.registerAppInterfaceParams.appName
				}
			})
			:Do(function(_,data)
				self.appName=data.params.application.appName
				self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
			end)
			
			--mobile side: expect response
			-- SDL sends Interface-related parameters to mobile app with value from HMI_capabilities_json
			local_paramsRAI.success = true
			local_paramsRAI.resultCode = "WRONG_LANGUAGE"
			
			self.mobileSession:ExpectResponse(CorIdRegister, local_paramsRAI)
			
			--mobile side: expect notification
			self.mobileSession:ExpectNotification("OnHMIStatus", { systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"})	 
		end	

		commonSteps:UnregisterApplication("Postcondition_UnregisterApplication_WRONG_LANGUAGE")

		-- APPLINK-16307 WARNINGS, true
		Test["TC01_"..TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_WARNINGS"] = function(self)
			local local_paramsRAI = params_RAI
			commonTestCases:DelayedExp(iTimeout)
			
			local parameters = commonFunctions:cloneTable(config.application1.registerAppInterfaceParams)
			parameters.appHMIType = {"MEDIA"}
	
			--mobile side: RegisterAppInterface request
			local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", parameters)

			--hmi side: expect BasicCommunication.OnAppRegistered request
			EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
			{
				application=
				{
					appName=config.application1.registerAppInterfaceParams.appName
				}
			})
			:Do(function(_,data)
				self.appName=data.params.application.appName
				self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
			end)
			
			--mobile side: expect response
			-- SDL sends Interface-related parameters to mobile app with value from HMI_capabilities_json
			local_paramsRAI.success = true
			local_paramsRAI.vrCapabilities = true
			
			self.mobileSession:ExpectResponse(CorIdRegister, local_paramsRAI)
			
			--mobile side: expect notification
			self.mobileSession:ExpectNotification("OnHMIStatus", { systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"})
		end	
	

		
		-- APPLINK-15686 RESUME_FAILED
		--////////////////////////////////////////////////////////////////////////////////////////////--
		-- Check absence of resumption in case HashID in RAI is not match
		--////////////////////////////////////////////////////////////////////////////////////////////--

		--Precondition:
		commonSteps:UnregisterApplication(TestCaseName .. "_Precondition_for_checking_RESUME_FAILED_UnregisterApp")
		commonSteps:RegisterAppInterface(TestCaseName .. "_Precondition_for_checking_RESUME_FAILED_RegisterApp")
		commonSteps:ActivationApp(_, TestCaseName .. "_Precondition_for_checking_RESUME_FAILED_ActivateApp")	

		--TODO: Commented because script can't be debugged.
		--[[
		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_AddCommand()
			
			--mobile side: sending AddCommand request
			local cid = self.mobileSession:SendRPC("AddCommand",
			{
				cmdID = 1,
				menuParams = 	
				{
					position = 0,
					menuName ="Command 1"
				}, 
				vrCommands = {"VRCommand 1"}
			})
		
			--hmi side: expect UI.AddCommand request 
			EXPECT_HMICALL("UI.AddCommand", 
			{ 
				cmdID = icmdID,		
				menuParams = 
				{
					position = 0,
					menuName ="Command 1"
				}
			})
			:Do(function(_,data)
				--hmi side: sending UI.AddCommand response 
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)

			--hmi side: expect VR.AddCommand request 
			EXPECT_HMICALL("VR.AddCommand", 
			{ 
				cmdID = 1,							
				type = "Command",
				vrCommands = 
				{
					"VRCommand 1"
				}
			})
			:Do(function(_,data)
				--hmi side: sending VR.AddCommand response 
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)	
		
			
			--mobile side: expect AddCommand response 
			EXPECT_RESPONSE(cid, {  success = true, resultCode = "SUCCESS"  })
			:Do(function()
				--mobile side: expect OnHashChange notification
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
					:Do(function(_, data)
						self.currentHashID = data.payload.hashID
					end)
			end)		
		end

		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_CreateInteractionChoiceSet()
			--mobile side: sending CreateInteractionChoiceSet request
			local cid = self.mobileSession:SendRPC("CreateInteractionChoiceSet",
												{
													interactionChoiceSetID = 1,
													choiceSet = 
													{ 
														
														{ 
															choiceID = 1,
															menuName = "Choice 1",
															vrCommands = 
															{ 
																"VrChoice 1",
															}
														}
													}
												})
		
			
			--hmi side: expect VR.AddCommand request
			EXPECT_HMICALL("VR.AddCommand", 
						{ 
							cmdID = 1,
							appID = self.applications[config.application1.registerAppInterfaceParams.appName],
							type = "Choice",
							vrCommands = {"VrChoice 1"}
						})
			:Do(function(_,data)
				--hmi side: sending VR.AddCommand response
				grammarIDValue = data.params.grammarID
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)
		
			--mobile side: expect CreateInteractionChoiceSet response
			EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
			:Do(function(_,data)
				
				--mobile side: expect OnHashChange notification
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
				:Do(function(_, data)
					self.currentHashID = data.payload.hashID
				end)
			end)
		end

		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_AddSubMenu()
			
			--mobile side: sending AddSubMenu request
			local cid = self.mobileSession:SendRPC("AddSubMenu",
												{
													menuID = 1,
													position = 500,
													menuName = "SubMenupositive 1"
												})

			--hmi side: expect UI.AddSubMenu request
			EXPECT_HMICALL("UI.AddSubMenu", 
						{ 
							menuID = 1,
							menuParams = {
								position = 500,
								menuName = "SubMenupositive 1"
							}
						})
			:Do(function(_,data)
				--hmi side: sending UI.AddSubMenu response
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)
			
			--mobile side: expect AddSubMenu response
			EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
			:Do(function()
				--mobile side: expect OnHashChange notification
				
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
					:Do(function(_, data)
						self.currentHashID = data.payload.hashID
					end)
			end)
		end

		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_SetGlobalProperites()
		
			--mobile side: sending SetGlobalProperties request
			local cid = self.mobileSession:SendRPC("SetGlobalProperties",
												{
													menuTitle = "Menu Title",
													timeoutPrompt = 
													{
														{
															text = "Timeout prompt",
															type = "TEXT"
														}
													},
													vrHelp = 
													{
														{
															position = 1,
															text = "VR help item"
														}
													},
													helpPrompt = 
													{
														{
															text = "Help prompt",
															type = "TEXT"
														}
													},
													vrHelpTitle = "VR help title",
												})


			--hmi side: expect TTS.SetGlobalProperties request
			EXPECT_HMICALL("TTS.SetGlobalProperties",
						{
							timeoutPrompt = 
							{
								{
									text = "Timeout prompt",
									type = "TEXT"
								}
							},
							helpPrompt = 
							{
								{
									text = "Help prompt",
									type = "TEXT"
								}
							}
						})
				:Do(function(_,data)
					--hmi side: sending UI.SetGlobalProperties response
					self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
				end)

			--hmi side: expect UI.SetGlobalProperties request
			EXPECT_HMICALL("UI.SetGlobalProperties",
						{
							menuTitle = "Menu Title",
							vrHelp = 
							{
								{
									position = 1,
									text = "VR help item"
								}
							},
							vrHelpTitle = "VR help title"
						})
			:Do(function(_,data)
				--hmi side: sending UI.SetGlobalProperties response
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)


			--mobile side: expect SetGlobalProperties response
			EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
			:Do(function(_,data)

				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
				:Do(function(_, data)
					self.currentHashID = data.payload.hashID
				end)
			end)
		end

		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_SubscribeButton()
		
			--mobile side: sending SubscribeButton request
			local cid = self.mobileSession:SendRPC("SubscribeButton", {buttonName = "PRESET_0"})

			--expect Buttons.OnButtonSubscription
			EXPECT_HMINOTIFICATION("Buttons.OnButtonSubscription", 
			{
				appID = self.applications[config.application1.registerAppInterfaceParams.appName], 
				isSubscribed = true, 
				name = "PRESET_0"
			})

			--mobile side: expect SubscribeButton response
			EXPECT_RESPONSE(cid, {success = true, resultCode = "SUCCESS"})
			:Do(function(_,data)
				
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
				:Do(function(_, data)
					self.currentHashID = data.payload.hashID
				end)
			end)
		end
	 
	 	--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_SubscribeVehicleData()
		
			--mobile side: sending SubscribeVehicleData request
			local cid = self.mobileSession:SendRPC("SubscribeVehicleData",{gps = true})
		
			--hmi side: expect SubscribeVehicleData request
			EXPECT_HMICALL("VehicleInfo.SubscribeVehicleData",{gps = true})
			:Do(function(_,data)
				--hmi side: sending VehicleInfo.SubscribeVehicleData response
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { gps = { resultCode = "SUCCESS", dataType = "VEHICLEDATA_GPS"}})	
			end)
		
			--mobile side: expect SubscribeVehicleData response
			EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
			:Do(function(_,data)
				
				--mobile side: expect OnHashChange notification
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange
				EXPECT_NOTIFICATION("OnHashChange")
				:Do(function(_, data)
					self.currentHashID = data.payload.hashID
				end)
			end)
		end

		--TODO: Check preconditions
		function Test:Precondition_for_checking_RESUME_FAILED_AddResumptionData_SubscribeWayPoints()
			
			local cid = self.mobileSession:SendRPC("SubscribeWayPoints", {})

			--hmi side: expected SubscribeWayPoints request
			EXPECT_HMICALL("Navigation.SubscribeWayPoints")
			:Do(function(_,data)
				--hmi side: sending Navigation.SubscribeWayPoints response
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)
			
			--mobile side: SubscribeWayPoints response
			EXPECT_RESPONSE(cid, {success = true , resultCode = "SUCCESS"})
			:Do(function(_,data)
				--Requirement id in JAMA/or Jira ID: APPLINK-15682
				--[Data Resumption]: OnHashChange

				--userPrint(31,"DEFECT ID: APPLINK-25808")
				EXPECT_NOTIFICATION("OnHashChange")
				:Do(function(_, data)
					self.currentHashID = data.payload.hashID
				end)
			end)
		end
		
		function Test:Precondition_for_checking_RESUME_FAILED_CloseConnection()

			self.mobileConnection:Close() 
		end

		function Test:Precondition_for_checking_RESUME_FAILED_ConnectMobile()

			self:connectMobile()
		end

		function Test:Precondition_for_checking_RESUME_FAILED_StartSession()
		  self.mobileSession = mobile_session.MobileSession(
			  self,
			  self.mobileConnection,
			  config.application1.registerAppInterfaceParams)

			self.mobileSession:StartService(7)
		end

		--Test[TestCaseName .. "_RegisterApplication_Check_VR_Parameters_From_HMI_capabilities_json_resultCode_RESUME_FAILED"] = function(self)
		Test["TC11_"TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_RESUME_FAILED"] = function(self)
			local local_paramsRAI = params_RAI
			commonTestCases:DelayedExp(iTimeout)
			
			local parameters = commonFunctions:cloneTable(config.application1.registerAppInterfaceParams)
			parameters.hashID = "sdfgTYWRTdfhsdfgh"

			--mobile side: RegisterAppInterface request
			local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", parameters)

			--hmi side: expect BasicCommunication.OnAppRegistered request
			EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
			{
				application=
				{
					appName=config.application1.registerAppInterfaceParams.appName
				}
			})
			:Do(function(_,data)
				self.appName=data.params.application.appName
				self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
			end)

			--mobile side: expect response
			-- SDL sends VR-related parameters to mobile app with value from HMI_capabilities_json
			local_paramsRAI.success = true
			local_paramsRAI.resultCode = "RESUME_FAILED"
	
			self.mobileSession:ExpectResponse(CorIdRegister, params_RAI)
			
			--mobile side: expect notification
			self.mobileSession:ExpectNotification("OnHMIStatus", 
						{systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"}, 
						{systemContext="MAIN", hmiLevel="FULL", audioStreamingState="AUDIBLE"}
			)
			:Times(2)
			
			-- The logic shall be checked for template
			EXPECT_HMICALL("UI.AddCommand")
			:Times(0)

			EXPECT_HMICALL("VR.AddCommand")
			:Times(0)

			EXPECT_HMICALL("UI.AddSubMenu")
			:Times(0)

			--APPLINK-9532: Sending TTS.SetGlobalProperties to VCA in case no obtained from mobile app
			--Description: When registering the app as soon as the app gets HMI Level NONE, SDL sends TTS.SetGlobalProperties(helpPrompt[]) with an empty array of helpPrompts (just helpPrompts, no timeoutPrompt).
			--hmi side: expect TTS.SetGlobalProperties request
			EXPECT_HMICALL("TTS.SetGlobalProperties")
			:Do(function(_,data)
				--hmi side: sending UI.SetGlobalProperties response
				self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
			end)
			:ValidIf(function(_,data)
				if data.params.timeoutPrompt then
					commonFunctions:printError("TTS.SetGlobalProperties request came with unexpected timeoutPrompt parameter.")
					return false
				elseif data.params.helpPrompt and #data.params.helpPrompt == 0 then
					return true
				elseif data.params.helpPrompt == nil then
					commonFunctions:printError("UI.SetGlobalProperties request came without helpPrompt")
					return false
				else 
					commonFunctions:printError("UI.SetGlobalProperties request came with some unexpected values of helpPrompt, array length is " .. tostring(#data.params.helpPrompt))
					return false
				end
			end)


			EXPECT_HMICALL("UI.SetGlobalProperties")
			:Times(0)

			--mobile side: expect OnHashChange notification
			EXPECT_NOTIFICATION("OnHashChange")
			:Times(0)
		end	]]
	end

	for i=1, #TestData do
	--for i=10, 10 do
		--for i=1, 2 do

		local TestCaseName = "Case_" .. TestData[i].caseID.."_" ..TestData[i].description 
			
		--Print new line to separate new test cases group
		commonFunctions:newTestCasesGroup(TestCaseName)

		isReady:StopStartSDL_HMI_MOBILE(self, TestData[i].caseID, TestCaseName)

		if(TestedInterface ~= "Navigation") then
			--Check with all possible RAI parameters
			if (i == 1) then
				-- In case response is not sent from HMI RAI will be checked for all possible successfully registered applications
				-- in scope of APPLINK-16420 / APPLINK-16251 / APPLINK-16250 / APPLINK-16249 / APPLINK-16320 / APPLINK-15686 / APPLINK-16307
				RegisterApplication_Check_Interfaces_Parameters_From_HMI_capabilities_json(TestCaseName) 
			else
				--Test will be executed for all cases when IsReady won't be sent because of wrong JSON format
				-- The test will be executed only for case of successfully registered application in scope of APPLINK-16420
				Test["TC0"..i.."_"..TestCaseName .. "_RegisterApplication_Check_"..TestedInterface.."_Parameters_From_HMI_capabilities_json_resultCode_SUCCESS"] = function(self)
					local local_paramsRAI = params_RAI
					commonTestCases:DelayedExp(iTimeout)
					
					--mobile side: RegisterAppInterface request
					local CorIdRegister=self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)

					--hmi side: expect BasicCommunication.OnAppRegistered request
					EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", 
					{
						application=
						{
							appName=config.application1.registerAppInterfaceParams.appName
						}
					})
					:Do(function(_,data)
						self.appName=data.params.application.appName
						self.applications[config.application1.registerAppInterfaceParams.appName]=data.params.application.appID
					end)
					
					--mobile side: expect response
					-- SDL sends Interface-related parameters to mobile app with value from HMI_capabilities_json.
					local_paramsRAI.success = true
					local_paramsRAI.resultCode = "SUCCESS"
				
					self.mobileSession:ExpectResponse(CorIdRegister, local_paramsRAI)
					
					--mobile side: expect notification
					self.mobileSession:ExpectNotification("OnHMIStatus", { systemContext="MAIN", hmiLevel="NONE", audioStreamingState="NOT_AUDIBLE"})
				end	
			end
		else

			print("\27[31m Tests for RAI are not applicable for Navigation interface!\27[0m")
		end
	end --for i=1, #TestData do


----------------------------------------------------------------------------------------------
-----------------------------------------TEST BLOCK IV----------------------------------------
------------------------------Check special cases of HMI response-----------------------------
----------------------------------------------------------------------------------------------

-- These cases are merged into TEST BLOCK III


	
-----------------------------------------------------------------------------------------------
-------------------------------------------TEST BLOCK V----------------------------------------
-------------------------------------Checks All Result Codes-----------------------------------
-----------------------------------------------------------------------------------------------

--Not applicable



----------------------------------------------------------------------------------------------
-----------------------------------------TEST BLOCK VI----------------------------------------
-------------------------Sequence with emulating of user's action(s)--------------------------
----------------------------------------------------------------------------------------------

--Not applicable



----------------------------------------------------------------------------------------------
-----------------------------------------TEST BLOCK VII---------------------------------------
--------------------------------------Different HMIStatus-------------------------------------
----------------------------------------------------------------------------------------------
-- Not applicable

	function Test:Postcondition_RestorePreloadedFile()
		commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
	end

	Test["ForceKill" .. tostring(i)] = function (self)
		os.execute("ps aux | grep smart | awk \'{print $2}\' | xargs kill -9")
		os.execute("sleep 1")
	end

return Test