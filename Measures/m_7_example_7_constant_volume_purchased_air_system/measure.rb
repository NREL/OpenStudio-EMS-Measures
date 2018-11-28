# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class M7Example7ConstantVolumePurchasedAirSystem < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M7 Example 7. Constant Volume Purchased Air System"
  end

  # human readable description
  def description
    return "This measure replicates the EMS functionality described in Example 7 from the EnergyPlus V8.9 EMS Application Guide."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure asks the user which existing conditioned thermal zones to convert to be served by an Autosized ZoneHVACIdealLoadsAirSystems from a choice list. The choice list will only be populated by Thermal zones which are (1) conditioned and (2) served only by ZoneHVAC Equipment objects, which this measure will delete. The measure configures the ZoneHVACIdealLoadsAirSystems with user-defined values for the supply airflow rates (cfm/ft2), leaving air temperature (Deg F) and leaving air humidity ratios (lb H2O / lb dry air) for both cooling and heating modes."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements
    
    # Note: There does not seem to be a way to retrieve the linkage between 
    # existing ZoneHVACIdealLoadsAirSystemideal objects and their 
    # attached Thermal Zones (via the API). Therefore this measure will 
    # ask the user which existing conditioned thermal zones to 
    # convert to be served by (autosized) ZoneHVACIdealLoadsAirSystems from a choice list. 
    # initially, the choice list will only be populated by Thermal zones which are 
    # (1) conditioned and (2) served only by ZoneHVAC Equipment objetcs, which this 
    # measure will delete.  
    
    # 1) make an argument for <conditioned> thermal zone(s) served only by ZoneHVAC equipment 
    # to apply ZoneHVACIdealLoadsAirSystem assignments to 
    tz_handles = OpenStudio::StringVector.new
    tz_display_names = OpenStudio::StringVector.new

    # put all thermal zone names into a hash
    tz_hash = {}
    model.getThermalZones.each do |tz|
      tz_hash[tz.name.to_s] = tz
    end

    # looping through a sorted hash of zones to place 'qualified' thermal zones within
    # must be conditioned and not attached to an airloop
    tz_hash.sort.map do |tz_name, tz|
      if tz.thermostatSetpointDualSetpoint.is_initialized
        tstat = tz.thermostatSetpointDualSetpoint.get
        if tstat.heatingSetpointTemperatureSchedule.is_initialized || tstat.coolingSetpointTemperatureSchedule.is_initialized
          if tz.airLoopHVAC.empty?
            tz_handles << tz.handle.to_s
            tz_display_names << tz_name
          end
        end
      end
    end

    # add building to string vector with zones
    building = model.getBuilding
    tz_handles << building.handle.to_s
    tz_display_names << '*All Cond. Zones not served by Air Loops*'    
    
    zones = OpenStudio::Measure::OSArgument.makeChoiceArgument('zones', tz_handles, tz_display_names, true)
    zones.setDisplayName('Choose Conditioned Thermal Zone(s) to apply Ideal HVAC system changes to.')
    zones.setDefaultValue('*All Cond. Zones not served by Air Loops*') # if no zone is chosen this will run on all zones
    args << zones
    
    # Make a double precision argument for the Supply Mass Flow rate for Heating 
    heating_mdot_per_ft2 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("heating_mdot_per_ft2",true)
    heating_mdot_per_ft2.setDisplayName("Htg Supply Airflow")
    heating_mdot_per_ft2.setDescription("Airflow of Zone Ideal HVAC system when in heating mode in cfm/ft^2.")
    heating_mdot_per_ft2.setDefaultValue(1.0)
    heating_mdot_per_ft2.setMinValue(0.0)
    heating_mdot_per_ft2.setMaxValue(3.0)
    args << heating_mdot_per_ft2
      
    # Make a double precision argument for the Supply Mass Flow rate for Cooling
    cooling_mdot_per_ft2 = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cooling_mdot_per_ft2",true)
    cooling_mdot_per_ft2.setDisplayName("Clg Supply Airflow")
    cooling_mdot_per_ft2.setDescription("Airflow of Zone Ideal HVAC system when in cooling mode in cfm/ft^2.")
    cooling_mdot_per_ft2.setDefaultValue(1.2)
    cooling_mdot_per_ft2.setMinValue(0.0)
    cooling_mdot_per_ft2.setMaxValue(3.0)
    args << cooling_mdot_per_ft2

    # Make a double precision argument for the Supply Air Dry Bulb Temperature for Heating 
    heating_LAT = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("heating_LAT",true)
    heating_LAT.setDisplayName("Htg LAT")
    heating_LAT.setDescription("Supply Air Temp of Zone Ideal HVAC system when in heating mode, Deg F.")
    heating_LAT.setDefaultValue(105)
    heating_LAT.setMinValue(90)
    heating_LAT.setMaxValue(120)
    args << heating_LAT

    # Make a double precision argument for the Supply Air Dry Bulb Temperature for Cooling
    cooling_LAT = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cooling_LAT",true)
    cooling_LAT.setDisplayName("Clg LAT")
    cooling_LAT.setDescription("Supply Air Temp of Zone Ideal HVAC system when in cooling mode, Deg F.")
    cooling_LAT.setDefaultValue(55)
    cooling_LAT.setMinValue(42)
    cooling_LAT.setMaxValue(65)
    args << cooling_LAT
 
    # Make a double precision argument for the Supply Air Humidity Ratio for Heating 
    heating_HumRat = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("heating_HumRat",true)
    heating_HumRat.setDisplayName("Htg HumRat")
    heating_HumRat.setDescription("Supply Air Humidity Ratio of Zone Ideal HVAC system when in heating mode, (lb H2O/lb dry air).")
    heating_HumRat.setDefaultValue(0.015)
    heating_HumRat.setMinValue(0.006)
    heating_HumRat.setMaxValue(0.017)
    args << heating_HumRat
    
    # Make a double precision argument for the Supply Air Humidity Ratio for Cooling
    cooling_HumRat = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cooling_HumRat",true)
    cooling_HumRat.setDisplayName("Clg HumRat")
    cooling_HumRat.setDescription("Supply Air Humidity Ratio of Zone Ideal HVAC system when in cooling mode, (lb H2O/lb dry air).")
    cooling_HumRat.setDefaultValue(0.009)
    cooling_HumRat.setMinValue(0.006)
    cooling_HumRat.setMaxValue(0.017)
    args << cooling_HumRat

    # make a choice argument for setting EMS InternalVariableAvailabilityDictionaryReporting value
    int_var_avail_dict_rep_chs = OpenStudio::StringVector.new
    int_var_avail_dict_rep_chs << 'None'
    int_var_avail_dict_rep_chs << 'NotByUniqueKeyNames'
    int_var_avail_dict_rep_chs << 'Verbose'
     
    internal_variable_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_variable_availability_dictionary_reporting', int_var_avail_dict_rep_chs, true)
    internal_variable_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_variable_availability_dictionary_reporting.setDefaultValue('None')
    args << internal_variable_availability_dictionary_reporting
    
    # make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    ems_runtime_language_debug_level_chs = OpenStudio::StringVector.new
    ems_runtime_language_debug_level_chs << 'None'
    ems_runtime_language_debug_level_chs << 'ErrorsOnly'
    ems_runtime_language_debug_level_chs << 'Verbose'
    
    ems_runtime_language_debug_output_level = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_runtime_language_debug_output_level', ems_runtime_language_debug_level_chs, true)
    ems_runtime_language_debug_output_level.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_runtime_language_debug_output_level.setDefaultValue('None')
    args << ems_runtime_language_debug_output_level
    
    # make a choice argument for setting EMS ActuatorAvailabilityDictionaryReportingvalue
    actuator_avail_dict_rep_chs = OpenStudio::StringVector.new
    actuator_avail_dict_rep_chs << 'None'
    actuator_avail_dict_rep_chs << 'NotByUniqueKeyNames'
    actuator_avail_dict_rep_chs << 'Verbose'
    
    actuator_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('actuator_availability_dictionary_reporting', actuator_avail_dict_rep_chs, true)
    actuator_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS actuators that are available.')
    actuator_availability_dictionary_reporting.setDefaultValue('None')
    args << actuator_availability_dictionary_reporting
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    verbose_info_statements = runner.getBoolArgumentValue("verbose_info_statements",user_arguments)
    zones = runner.getOptionalWorkspaceObjectChoiceValue('zones', user_arguments, model) # model is passed in because of argument type
    cooling_mdot_per_ft2 = runner.getDoubleArgumentValue("cooling_mdot_per_ft2",user_arguments)
    heating_mdot_per_ft2 = runner.getDoubleArgumentValue("heating_mdot_per_ft2",user_arguments)
    cooling_LAT = runner.getDoubleArgumentValue("cooling_LAT",user_arguments)
    heating_LAT = runner.getDoubleArgumentValue("heating_LAT",user_arguments)
    cooling_HumRat = runner.getDoubleArgumentValue("cooling_HumRat",user_arguments)
    heating_HumRat = runner.getDoubleArgumentValue("heating_HumRat",user_arguments)
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)

    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    
    # test user argument values for reasonableness
    if cooling_LAT > heating_LAT 
      runner.registerError("Measure failed because the value of #{cooling_LAT} Deg F entered for the clg supply air temperature must be less then then value of #{heating_LAT} entered for the htg supply air temp.") 
      return false
    end
    
    if cooling_mdot_per_ft2 < 0.50 
      runner.registerError("Measure failed because the value of #{cooling_mdot_per_ft2} cfm/ft2 entered for the clg airflow per sqft must be greater then 0.50.") 
      return false
    end

    if heating_mdot_per_ft2 < 0.50 
      runner.registerError("Measure failed because the value of #{heating_mdot_per_ft2} cfm/ft2 entered for the htg airflow per sqft must be greater then 0.50.") 
      return false
    end
    
    # check the zone selection for existence in model
    apply_to_all_zones = false
    selected_zone = nil
    if zones.empty?
      handle = runner.getStringArgumentValue('zones', user_arguments)
      if handle.empty?
        runner.registerError('No thermal zone was chosen.')
        return false
      else
        runner.registerError("The selected thermal zone with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if !zones.get.to_ThermalZone.empty?
        selected_zone = zones.get.to_ThermalZone.get
      elsif !zones.get.to_Building.empty?
        apply_to_all_zones = true
      else
        runner.registerError('Script Error - argument not showing up as thermal zone.')
        return false
      end
    end
    
    # define selected zone(s), depending on user input, add selected zones to an array
    selected_zones = []
    if apply_to_all_zones == true
      model.getThermalZones.each do |each_zone|
        if each_zone.thermostatSetpointDualSetpoint.is_initialized
           tstat = each_zone.thermostatSetpointDualSetpoint.get
           if tstat.heatingSetpointTemperatureSchedule.is_initialized || tstat.coolingSetpointTemperatureSchedule.is_initialized
             if each_zone.airLoopHVAC.empty?
               selected_zones << each_zone
             else
               if verbose_info_statements == true
                 runner.registerInfo("HVAC System serving Thermal Zone named #{each_zone.name} is attached to air AirLoop, and will not be modified by this measure.") 
               end
             end
           else
             if verbose_info_statements == true
               runner.registerInfo("Thermal Zone named #{each_zone.name} is unconditioned, and will not be modified by this measure.") 
             end
           end
         end  
      end  
    else
      selected_zones << selected_zone
    end
    
    if selected_zones.length == 0
      runner.registerError("Model contains no 'qualified' Themal Zones for this measure to modelfy.") 
      return false
    end
   
    # Convert arguments to SI units
    cooling_LAT_SI = OpenStudio.convert(cooling_LAT,"F","C")
    heating_LAT_SI = OpenStudio.convert(heating_LAT,"F","C")

    # initialize counter variable and declare EMS variables for proper scope within loops
    ems_det_purchased_air_state_prg = nil
    ems_set_purchased_air_prg = nil
    ems_prgm_calling_mngr = nil
    counter = 0

    # Loop through selected conditioned zone(s), replace existing HVAC equipment with ZoneHVACIdealLoadsAirSystems objects
    selected_zones.each do |zone|
      
      counter += 1 
      cooling_mdot = zone.floorArea * cooling_mdot_per_ft2
      cooling_mdot_SI = OpenStudio.convert(cooling_mdot,"cfm","m^3/s")
      
      heating_mdot = zone.floorArea * heating_mdot_per_ft2
      heating_mdot_SI = OpenStudio.convert(heating_mdot,"cfm","m^3/s")
            
      zone.equipment.each do |zone_equipment|
        # remove zone equipment HVAC object attached to zone. NOTE: the .remove method also removes 'child' coils from their plant loops
        next if zone_equipment.to_FanZoneExhaust.is_initialized
        if verbose_info_statements == true
          runner.registerInfo("Removing ZoneHVAC Equipment named #{zone_equipment.name} currently serving Thermal Zone #{zone.name}.")
        end
        zone_equipment.remove
      end   
      
      # Remove existing outdoor VRF units (special type of ZoneHVAC Equip that is not in zone and not in AirLoops)
      if model.getAirConditionerVariableRefrigerantFlows.count != 0
        runner.registerAsNotApplicable("This model has one outdoor VRF unit named '#{getAirConditionerVariableRefrigerantFlows[0].name}'. This measure has not been written to identify whether or not to remove a VRF indoor unit from a thermal zone. The measure logic will not be executed.")
        return true
      end
      
      # Remove plant loops that no longer have demand side components that are coils
      model.getPlantLoops.each do |plantloop|
        delete_loop = true
        plantloop.demandComponents.each do |comp| 
          if comp.to_CoilCoolingLowTempRadiantConstFlow.is_initialized or
             comp.to_CoilCoolingLowTempRadiantVarFlow.is_initialized or
             comp.to_WaterUseConnections.is_initialized or
             comp.to_CoilWaterHeatingDesuperheater.is_initialized or
             comp.to_CoilCoolingWater.is_initialized or 
             comp.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized or
             comp.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized or 
             comp.to_CoilHeatingLowTempRadiantVarFlow.is_initialized or
             comp.to_CoilHeatingLowTempRadiantConstFlow.is_initialized or 
             comp.to_CoilHeatingWater.is_initialized or
             comp.to_CoilHeatingWaterBaseboard.is_initialized or 
             comp.to_CoilHeatingWaterBaseboardRadiant.is_initialized or
             comp.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized or 
             comp.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized or
             comp.to_CoilSystemCoolingWaterHeatExchangerAssisted.is_initialized or 
             comp.to_CoilWaterHeatingAirToWaterHeatPump.is_initialized or
             comp.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.is_initialized
            
            delete_loop = false
          end
        end  
        if delete_loop == true
          if verbose_info_statements == true
            runner.registerInfo("Removing #{plantloop.sizingPlant.loopType} Plant Loop named '#{plantloop.name}' from the model as the measure previously removed all demand side coils from this loop.")
          end
          plantloop.remove
        end
      end # end loop through plant loops
                             
      # create ZoneHVACIdealLoadsAirSystem and assign to the thermal zone. 
      ideal_loads_HVAC = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
      ideal_loads_HVAC.setName("#{zone.name}#{counter}AIR")
      ideal_loads_HVAC.addToThermalZone(zone)
      if verbose_info_statements == true
        runner.registerInfo("Replaced the existing Zone HVAC system(s) serving the thermal zone named '#{zone.name}' with a new ZoneHVACIdealLoadsAirSystem.") 
      end
      
      # First time (and only time) through the thermal zone loop, create new EnergyManagementSystem:Program, EnergyManagementSystem:ProgramCallingManager 
      # and EnergyManagement:GlobalVariable objects and stub them out
      
      if counter == 1
      
        # Create new EnergyManagementSystem:Program object for determining purchased air 
        ems_det_purchased_air_state_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
        ems_det_purchased_air_state_prg.setName("Determine_Purch_Air_State")
        if verbose_info_statements == true
          runner.registerInfo("EMS Program object named '#{ems_det_purchased_air_state_prg.name}' added to determine zone purchased air status.") 
        end
        
        # Create new EnergyManagementSystem:Program object for setting purchased air 
        ems_set_purchased_air_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
        ems_set_purchased_air_prg.setName("Set_Purch_Air")
        if verbose_info_statements == true
          runner.registerInfo("EMS Program object named '#{ems_set_purchased_air_prg.name}' added to set zone purchased air status.") 
        end
        
        # create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS programs
        ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
        ems_prgm_calling_mngr.setName("Constant Volume Purchased Air Example")
        ems_prgm_calling_mngr.setCallingPoint("AfterPredictorAfterHVACManagers")
        ems_prgm_calling_mngr.addProgram(ems_det_purchased_air_state_prg)
        ems_prgm_calling_mngr.addProgram(ems_set_purchased_air_prg)
        if verbose_info_statements == true
          runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_det_purchased_air_state_prg.name} and #{ems_set_purchased_air_prg.name} EMS programs.") 
        end
        
      end # end logic that only runs once
      
      # Create new EnergyManagementSystem:GlobalVariable object and configure to hold the current "Zone State"
      ems_zone_state_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone.name}_State".gsub(" ","_"))
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named '#{ems_zone_state_gv.name}' was added to hold the current 'Zone State' - heating, cooling or deadband.") 
      end
      
      # Create new EnergyManagementSystem:Sensor object representing the Zone Predicted Sensible Load to Setpoint Heat Transfer Rate
      ems_zone_pred_sens_load_to_Stpt_HTR_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Zone Predicted Sensible Load to Setpoint Heat Transfer Rate")
      ems_zone_pred_sens_load_to_Stpt_HTR_sensor.setName("Sensible_Load_Zone_#{counter}")
      ems_zone_pred_sens_load_to_Stpt_HTR_sensor.setKeyName("#{zone.name}") 
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named '#{ems_zone_pred_sens_load_to_Stpt_HTR_sensor.name}' representing the Zone Predicted Sensible Load to Setpoint Heat Transfer Rate for the zone named #{zone.name} added to the model.") 
      end
      
      # Create EMS Actuator Objects representing Ideal Loads Air System Air Mass Flow Rate, Supply Air temp and Supply Air Humidity Ratio serving the thermal zone
      ems_ideal_air_loads_mdot_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(ideal_loads_HVAC,"Ideal Loads Air System","Air Mass Flow Rate")
      ems_ideal_air_loads_mdot_actuator.setName("ZONE_#{counter}_AIR_Mdot")
      if verbose_info_statements == true
        runner.registerInfo("EMS Actuator object named '#{ems_ideal_air_loads_mdot_actuator.name}' representing the Ideal Air Loads System Mass Flow Rate for the Ideal Air Loads System named #{ideal_loads_HVAC.name} was added to the model.") 
      end
      
      ems_ideal_air_loads_supply_temp_sensor = OpenStudio::Model::EnergyManagementSystemActuator.new(ideal_loads_HVAC,"Ideal Loads Air System","Air Temperature")
      ems_ideal_air_loads_supply_temp_sensor.setName("ZONE_#{counter}_AIR_SupplyT") 
      if verbose_info_statements == true
        runner.registerInfo("EMS Actuator object named '#{ems_ideal_air_loads_supply_temp_sensor.name}' representing the Ideal Air Loads System Supply Air Temperature for the Ideal Air Loads System named #{ideal_loads_HVAC.name} was added to the model.") 
      end
      
      ems_ideal_air_loads_supply_HumRat_sensor = OpenStudio::Model::EnergyManagementSystemActuator.new(ideal_loads_HVAC,"Ideal Loads Air System","Air Humidity Ratio")
      ems_ideal_air_loads_supply_HumRat_sensor.setName("ZONE_#{counter}_AIR_SupplyHumRat") 
      if verbose_info_statements == true
        runner.registerInfo("EMS Actuator object named '#{ems_ideal_air_loads_supply_HumRat_sensor.name}' representing the Ideal Air Loads System Supply Air Humidity Ratio the Ideal Air Loads System named #{ideal_loads_HVAC.name} was added to the model.") 
      end
      
      # Add logic to the two EMS programs as we iterate through the selected zone loop
      # NOTE: State value of 1 means zone is heating, state value of 2 means zone is cooling, state value of 0 means zone in deadband
      ems_det_purchased_air_state_prg.addLine("IF (#{ems_zone_pred_sens_load_to_Stpt_HTR_sensor.name} <= 0.0)")
      ems_det_purchased_air_state_prg.addLine("SET #{ems_zone_state_gv.name} = 2.0")
      ems_det_purchased_air_state_prg.addLine("ELSEIF (#{ems_zone_pred_sens_load_to_Stpt_HTR_sensor.name} > 0.0)")
      ems_det_purchased_air_state_prg.addLine("SET #{ems_zone_state_gv.name} = 1.0")
      ems_det_purchased_air_state_prg.addLine("ENDIF")
            
      ems_set_purchased_air_prg.addLine("IF (#{ems_zone_state_gv.name} == 2.0)")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_mdot_actuator.name} = #{cooling_mdot_SI}")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_supply_temp_sensor.name} = #{cooling_LAT_SI}")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_supply_HumRat_sensor.name} = #{cooling_HumRat}")
      ems_set_purchased_air_prg.addLine("ELSEIF (#{ems_zone_state_gv.name} == 1.0)")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_mdot_actuator.name} = #{heating_mdot_SI}")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_supply_temp_sensor.name} = #{heating_LAT_SI}")
      ems_set_purchased_air_prg.addLine("SET #{ems_ideal_air_loads_supply_HumRat_sensor.name} = #{heating_HumRat}")
      ems_set_purchased_air_prg.addLine("ENDIF")
   
    end  # end loop through qualified thermal zones

    # create OutputEnergyManagementSystem object (a 'unique' object) and configure to allow EMS reporting
    output_EMS = model.getOutputEnergyManagementSystem
    output_EMS.setInternalVariableAvailabilityDictionaryReporting('internal_variable_availability_dictionary_reporting')
    output_EMS.setEMSRuntimeLanguageDebugOutputLevel('ems_runtime_language_debug_output_level')
    output_EMS.setActuatorAvailabilityDictionaryReporting('actuator_availability_dictionary_reporting')

    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

  end # end run method
  
end # end class

# register the measure to be used by the application
M7Example7ConstantVolumePurchasedAirSystem.new.registerWithApplication


