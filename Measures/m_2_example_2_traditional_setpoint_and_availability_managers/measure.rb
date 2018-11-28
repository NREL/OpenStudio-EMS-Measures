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
class M2Example2TraditionalSetpointAndAvailabilityManagers < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "m_2_example_2_traditional_setpoint_and_availability_managers"
  end

  # human readable description
  def description
    return "This measure will demonstrate how to use OpenStudio EMS objects to model supervisory control of HVAC systems. The functionality of three traditional HVAC system managers (scheduled setpoints, mixed air setpoints, and night cycle availability) are replaced with equivalent OpenStudio EMS objects"
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will replicate the functionality described in the EnergyPlus Energy Management System Application Guide, Example 2., based on user input."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a Choice List Argument for selecting the VAV airloophvac to demonstrate examnple 8.2 EnergyPlus EMS features against
    qualified_airloop_handles = OpenStudio::StringVector.new
    qualified_airloop_display_names = OpenStudio::StringVector.new

    # put airloops into a hash
    airloop_hash = {}
    model.getAirLoopHVACs.each do |airloop|
      airloop_hash[airloop.name.to_s] = airloop
    end

    # looping through a sorted hash of airloops
    airloop_hash.sort.map do |airloop_name, airloop|
      has_vfd_fan = false
      airloop.supplyComponents.each do |supply_comp|
        if supply_comp.to_FanVariableVolume.is_initialized
          has_vfd_fan = true
        end
      end
      if has_vfd_fan == true 
        qualified_airloop_handles << airloop.handle.to_s
        qualified_airloop_display_names << airloop_name 
      end
    end  
 
    # make an argument for airloop
    airloop = OpenStudio::Measure::OSArgument.makeChoiceArgument('airloop', qualified_airloop_handles, qualified_airloop_display_names, true)
    airloop.setDisplayName("Choose an Airloop to replicate EMS functions described in EMS Applications Guide, Example 8.2.")
    args << airloop  
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # make a choice argument for setting InternalVariableAvailabilityDictionaryReporting value
    internal_variable_availability_dictionary_reporting_choice = OpenStudio::StringVector.new
    internal_variable_availability_dictionary_reporting_choice << 'None'
    internal_variable_availability_dictionary_reporting_choice << 'NotByUniqueKeyNames'
    internal_variable_availability_dictionary_reporting_choice << 'Verbose'
     
    internal_variable_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_variable_availability_dictionary_reporting', internal_variable_availability_dictionary_reporting_choice, true)
    internal_variable_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_variable_availability_dictionary_reporting.setDefaultValue('None')
    args << internal_variable_availability_dictionary_reporting
    
    # make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    ems_runtime_language_debug_output_level_choice = OpenStudio::StringVector.new
    ems_runtime_language_debug_output_level_choice << 'None'
    ems_runtime_language_debug_output_level_choice << 'ErrorsOnly'
    ems_runtime_language_debug_output_level_choice << 'Verbose'
    
    ems_runtime_language_debug_output_level = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_runtime_language_debug_output_level', ems_runtime_language_debug_output_level_choice, true)
    ems_runtime_language_debug_output_level.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_runtime_language_debug_output_level.setDefaultValue('None')
    args << ems_runtime_language_debug_output_level
    
    # make a choice argument for setting ActuatorAvailabilityDictionaryReportingvalue
    actuator_availability_dictionary_reporting_choice = OpenStudio::StringVector.new
    actuator_availability_dictionary_reporting_choice << 'None'
    actuator_availability_dictionary_reporting_choice << 'NotByUniqueKeyNames'
    actuator_availability_dictionary_reporting_choice << 'Verbose'
    
    actuator_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('actuator_availability_dictionary_reporting', actuator_availability_dictionary_reporting_choice, true)
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
    airloop = runner.getOptionalWorkspaceObjectChoiceValue('airloop', user_arguments, model) # model is passed in because of argument type
    verbose_info_statements = runner.getBoolArgumentValue("verbose_info_statements",user_arguments)
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments) 
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments) 
    
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
 
    # declare variables for proper scope 
    zone_mean_air_temp_ems_sensor_array = []
    htg_setpoint_sch_array = []
    clg_setpoint_sch_array = []
    htg_setpoint_sch = nil
    clg_setpoint_sch = nil
    
    # trap for N/A condition if no airloopHVAC present
    if model.getAirLoopHVACs.count == 0
      runner.registerAsNotApplicable("Model does not have any AirLoopHVAC to choose from - this measure is not applicable.")
      return true
    end

    # check to make sure AirLoopHVAC user argument is legitimate, and retrieve object if so.  
    air_loop = nil
    if not airloop.get.to_AirLoopHVAC.empty?
      air_loop = airloop.get.to_AirLoopHVAC.get
      # replace whitespaces from airloop name
      current_airloop_name = air_loop.name
      air_loop.setName(current_airloop_name.to_s.gsub(" ","_"))
    else
      runner.registerError("Script Error - argument not showing up as air loop.")
      return false
    end

    # Prepare .osm model file for replicating EMS features found in the EMS example 8.2
    # create and inject a Seasonal-Reset-Supply-Air-Temp-Sch schedule containing the temperature  
    # values desired forthe air system’s supply deck 
    # Through: 3/31, For: AllDays,Until: 24:00,13.0,
    # Through: 9/30,For: AllDays,Until: 24:00,13.0,
    # Through: 12/31,For: AllDays,Until: 24:00,13.0
    
    sch_type = OpenStudio::Model::ScheduleTypeLimits.new(model)
    sch_type.setUnitType("Temperature")
    sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sch.setName("Seasonal-Reset-Supply-Air-Temp-Sch")
    sch.setScheduleTypeLimits(sch_type)
    r1 = OpenStudio::Model::ScheduleRule.new(sch)
    r1.setApplySunday(true)
    r1.setApplyMonday(true) 
    r1.setApplyTuesday(true) 
    r1.setApplyWednesday(true) 
    r1.setApplyThursday(true) 
    r1.setApplyFriday(true) 
    r1.setApplySaturday(true) 
    r1_start_date = [1, 1]
    r1_end_date = [3, 31]
    r1.setStartDate(model.getYearDescription.makeDate(r1_start_date[0], r1_start_date[1]))
    r1.setEndDate(model.getYearDescription.makeDate(r1_end_date[0], r1_end_date[1]))
    r1.daySchedule.clearValues()
    r1.daySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 13)
    
    r2 = OpenStudio::Model::ScheduleRule.new(sch)
    r2.setApplySunday(true)
    r2.setApplyMonday(true) 
    r2.setApplyTuesday(true) 
    r2.setApplyWednesday(true) 
    r2.setApplyThursday(true) 
    r2.setApplyFriday(true) 
    r2.setApplySaturday(true) 
    r2_start_date = [4, 1]
    r2_end_date = [9, 30]
    r2.setStartDate(model.getYearDescription.makeDate(r2_start_date[0], r2_start_date[1]))
    r2.setEndDate(model.getYearDescription.makeDate(r2_end_date[0], r2_end_date[1]))
    r2.daySchedule.clearValues()
    r2.daySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 13)
        
    r3 = OpenStudio::Model::ScheduleRule.new(sch)
    r3.setApplySunday(true)
    r3.setApplyMonday(true) 
    r3.setApplyTuesday(true) 
    r3.setApplyWednesday(true) 
    r3.setApplyThursday(true) 
    r3.setApplyFriday(true) 
    r3.setApplySaturday(true) 
    r3_start_date = [10, 1]
    r3_end_date = [12, 31]
    r3.setStartDate(model.getYearDescription.makeDate(r3_start_date[0], r3_start_date[1]))
    r3.setEndDate(model.getYearDescription.makeDate(r3_end_date[0], r3_end_date[1]))
    r3.daySchedule.clearValues()
    r3.daySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 13)

    # retrieve necessary nodes and declare variables for proper scope
    outdoor_air_mixer_outlet_node = nil
    cooling_coil_outlet_node = nil
    heating_coil_outlet_node = nil

    airloop_supply_side_outlet_node = air_loop.supplyOutletNode.to_Node.get    
    air_loop.supplyComponents.each do |supply_component|
    
      if supply_component.to_CoilCoolingWater.is_initialized
        airloop_cooling_coil = supply_component.to_CoilCoolingWater.get
        if airloop_cooling_coil.airInletModelObject.is_initialized
          airloop_cooling_coil_inlet_model_obj = airloop_cooling_coil.airInletModelObject.get
          airloop_cooling_coil_outlet_model_obj = airloop_cooling_coil.airOutletModelObject.get
          outdoor_air_mixer_outlet_node = airloop_cooling_coil_inlet_model_obj.to_Node.get
          if verbose_info_statements == true
            runner.registerInfo("Outdoor Air Mixer Outlet Node of airloop named '#{air_loop.name}' has been identified as #{outdoor_air_mixer_outlet_node.name}.") 
          end
          cooling_coil_outlet_node = airloop_cooling_coil_outlet_model_obj.to_Node.get
          if verbose_info_statements == true
            runner.registerInfo("Cooling Coil Outlet Node of airloop named '#{air_loop.name}' has been identified as #{cooling_coil_outlet_node.name}.") 
          end
        end
      end
      
      if supply_component.to_CoilHeatingWater.is_initialized
        airloop_heating_coil = supply_component.to_CoilHeatingWater.get
        if airloop_heating_coil.airOutletModelObject.is_initialized
          heating_coil_outlet_model_obj = airloop_heating_coil.airOutletModelObject.get
          heating_coil_outlet_node = heating_coil_outlet_model_obj.to_Node.get
          if verbose_info_statements == true
            runner.registerInfo("Heating Coil Outlet Node of airloop named '#{air_loop.name}' has been identified as #{heating_coil_outlet_node.name}.") 
          end
        end
      end  
    end # end loop through air_loop supply components
        
    # create EMS sensor objects representing zone temperature by looping through thermal zones connected to the airloop 
    air_loop.thermalZones.each do |thermal_zone|
    
      # Create new EnergyManagementSystem:Sensor objects representing the Mean Air Temp of the Thermal Zone 
      ems_zone_mean_air_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Zone Mean Air Temperature")
      ems_zone_mean_air_temp_sensor.setName("T_#{thermal_zone.name}_VAV")
      ems_zone_mean_air_temp_sensor.setKeyName("#{thermal_zone.name}")
      zone_mean_air_temp_ems_sensor_array << ems_zone_mean_air_temp_sensor
      if verbose_info_statements == true
        runner.registerInfo("An EMS Sensor object named '#{ems_zone_mean_air_temp_sensor.name}' representing the mean air temperature of the thermal zone named '#{thermal_zone.name}' was added to the model.") 
      end
      
      # get heating and cooling T-stat schedules associated with thermal zones, knowing that for the prototype  
      # buildings, all thermal zones connected to a VAV AHU use the same htg and clg thermostat schedules zones
      # this code will retrieve the htg and clg t-stat schedules from the LAST thermal zone in the thermal_zone loop
      if thermal_zone.thermostatSetpointDualSetpoint.is_initialized
        dual_setpoint_tstat = thermal_zone.thermostatSetpointDualSetpoint.get
        if dual_setpoint_tstat.heatingSetpointTemperatureSchedule.is_initialized
          htg_setpoint_sch = dual_setpoint_tstat.heatingSetpointTemperatureSchedule.get 
        end 
        if dual_setpoint_tstat.coolingSetpointTemperatureSchedule.is_initialized
          clg_setpoint_sch = dual_setpoint_tstat.coolingSetpointTemperatureSchedule.get 
        end 
      end      
    end

    # Create a new EnergyManagementSystem:Sensor object representing Airloop Connected Thermal Zone Heating Setpoint Schedule
    ems_tz_heating_setpoint_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Schedule Value")
    ems_tz_heating_setpoint_sensor.setName("htg_sp")
    ems_tz_heating_setpoint_sensor.setKeyName("#{htg_setpoint_sch.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_tz_heating_setpoint_sensor.name}' representing Heating Setpoint Schedule of Thermal Zones connected to the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:Sensor object representing Airloop Connected Thermal Zone Cooling Setpoint Schedule
    ems_tz_cooling_setpoint_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Schedule Value")
    ems_tz_cooling_setpoint_sensor.setName("clg_sp")
    ems_tz_cooling_setpoint_sensor.setKeyName("#{clg_setpoint_sch.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_tz_cooling_setpoint_sensor.name}' representing Cooling Setpoint Schedule of Thermal Zones connected to the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:Sensor object representing the Seasonal Reset Supply Air Temperature Schedule
    ems_seasonal_reset_SAT_sch_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Schedule Value")
    ems_seasonal_reset_SAT_sch_sensor.setName("Seasonal_Reset_SAT_Sched")
    ems_seasonal_reset_SAT_sch_sensor.setKeyName("#{sch.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_seasonal_reset_SAT_sch_sensor.name}' representing the seasonal reset supply air temp schedule to be used on the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:Sensor object representing the AirLoop VAV Fan Outlet Node Temperature (also the AirLoopHVAC supply outllet node)
    ems_vav_fan_outlet_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Temperature")
    ems_vav_fan_outlet_temp_sensor.setName("T#{air_loop.name}_FanOut")
    ems_vav_fan_outlet_temp_sensor.setKeyName("#{airloop_supply_side_outlet_node.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_vav_fan_outlet_temp_sensor.name}' representing the supply outlet node temp of the airloop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:Sensor object representing the AirLoop VAV Fan Inlet Node Temperature - the same node as the htg coil outlet node temp
    ems_fan_inlet_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Temperature")
    ems_fan_inlet_temp_sensor.setName("T#{air_loop.name}_FanIn")
    ems_fan_inlet_temp_sensor.setKeyName("#{heating_coil_outlet_node.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_fan_inlet_temp_sensor.name}' representing the inlet temp of the VAV supply fan serving the airloop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EMS Actuator Object representing the AirLoopHVAC availability status
    ems_airloop_avail_status_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(air_loop,"AirLoopHVAC", "Availability Status")
    ems_airloop_avail_status_actuator.setName("#{air_loop.name}_NightCycStat")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_airloop_avail_status_actuator.name}' representing the availability status of the airloop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EMS Actuator Object representing the AirLoopHVAC supply outlet node temperature setpoint
    ems_loop_outlet_node_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(airloop_supply_side_outlet_node,"System Node Setpoint", "Temperature Setpoint")
    ems_loop_outlet_node_actuator.setName("#{air_loop.name}_SAT_setpoint")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_loop_outlet_node_actuator.name}' representing the supply outlet node of the airloop named '#{air_loop.name}' was added to the model.") 
    end
     
    # Create a new EMS Actuator Object representing the AirLoopHVAC outdoor air mixer outlet node temp setpoint
    ems_oa_air_mixer_outlet_node_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(outdoor_air_mixer_outlet_node,"System Node Setpoint", "Temperature Setpoint")
    ems_oa_air_mixer_outlet_node_actuator.setName("#{air_loop.name}_OA_Setpoint")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_oa_air_mixer_outlet_node_actuator.name}' representing the outdoor air mixer outlet node of the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EMS Actuator Object representing the water clg coil outlet node setpoint
    ems_clg_coil_outlet_node_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(cooling_coil_outlet_node,"System Node Setpoint", "Temperature Setpoint")
    ems_clg_coil_outlet_node_actuator.setName("#{air_loop.name}_CoolC_Setpoint")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_clg_coil_outlet_node_actuator.name}' representing the water cooling coil outlet node of the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create a new EMS Actuator Object representing the water htg coil outlet node setpoint
    ems_htg_coil_outlet_node_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(heating_coil_outlet_node,"System Node Setpoint", "Temperature Setpoint")
    ems_htg_coil_outlet_node_actuator.setName("#{air_loop.name}_HeatC_Setpoint")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_htg_coil_outlet_node_actuator.name}' representing the water heating coil outlet node of the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create new EnergyManagementSystem:Program object for setting the discharge temperature setpoint on the AirLoopHVAC supply outlet node
    ems_vav_sched_setpt_mngr_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_vav_sched_setpt_mngr_prgm.setName("#{air_loop.name}_vav_sched_setpoint_prgm")
    ems_vav_sched_setpt_mngr_prgm.addLine("SET #{ems_loop_outlet_node_actuator.name} = #{ems_seasonal_reset_SAT_sch_sensor.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Program Object named '#{ems_vav_sched_setpt_mngr_prgm.name}' for changing the VAV airloop discharge temperature setpoint setpoint on the supply outlet node of the air loop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create new EnergyManagementSystem:Program object for managing the mixed air setpoint managers to account for injection of fan heat
    ems_mixed_air_setpt_mngr_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_mixed_air_setpt_mngr_prgm.setName("#{air_loop.name}_MixedAirManagers")
    ems_mixed_air_setpt_mngr_prgm.addLine("SET #{ems_clg_coil_outlet_node_actuator.name} =  #{ems_seasonal_reset_SAT_sch_sensor.name} - (#{ems_vav_fan_outlet_temp_sensor.name} - #{ems_fan_inlet_temp_sensor.name})")
    ems_mixed_air_setpt_mngr_prgm.addLine("SET #{ems_htg_coil_outlet_node_actuator.name} =  #{ems_seasonal_reset_SAT_sch_sensor.name} - (#{ems_vav_fan_outlet_temp_sensor.name} - #{ems_fan_inlet_temp_sensor.name})")
    ems_mixed_air_setpt_mngr_prgm.addLine("SET #{ems_oa_air_mixer_outlet_node_actuator.name} =  #{ems_seasonal_reset_SAT_sch_sensor.name} - (#{ems_vav_fan_outlet_temp_sensor.name} - #{ems_fan_inlet_temp_sensor.name})")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Program Object named '#{ems_mixed_air_setpt_mngr_prgm.name}' for setting mixed air temperature setpoints to account for fan heat on the airloop named '#{air_loop.name}' was added to the model.") 
    end
    
    # Create new EnergyManagementSystem:Program object for managing AirLoopHVAC Night Cycle Availability 
    ems_airloop_night_cyc_mngr_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_airloop_night_cyc_mngr_prgm.setName("#{air_loop.name}_NightCycleMGR")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET Toffset = 0.8333")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET NoAction = 0.0")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET ForceOff = 1.0")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET CycleOn = 2.0")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET CycleOnZoneFansOnly = 3")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET CycleOnZoneFansOnly = 3")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{air_loop.name}_htg_TurnOn  = #{ems_tz_heating_setpoint_sensor.name}")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{air_loop.name}_htg_TurnOff = #{ems_tz_heating_setpoint_sensor.name} + (2*Toffset)")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{air_loop.name}_clg_TurnOn = #{ems_tz_cooling_setpoint_sensor.name}")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{air_loop.name}_clg_TurnOff = #{ems_tz_cooling_setpoint_sensor.name} - (2*Toffset)")
    
    # add EMS logic for determining min and max mean air temps of zones connected to the AirLoopHVAC - needed to set nighttime availability manager
    counter = 0
    zone_mean_air_temp_ems_sensor_array.each do |ems_zone_mean_air_temp_sensor|
      counter += 1    
      if counter == 1
        ems_airloop_night_cyc_mngr_prgm.addLine("SET Tmin = #{ems_zone_mean_air_temp_sensor.name}")
        ems_airloop_night_cyc_mngr_prgm.addLine("SET Tmax = #{ems_zone_mean_air_temp_sensor.name}")
      else
        ems_airloop_night_cyc_mngr_prgm.addLine("SET Tmin = @MIN Tmin #{ems_zone_mean_air_temp_sensor.name}")
        ems_airloop_night_cyc_mngr_prgm.addLine("SET Tmax = @MAX Tmax #{ems_zone_mean_air_temp_sensor.name}")
      end
    end
 
    ems_airloop_night_cyc_mngr_prgm.addLine("IF Tmin < #{air_loop.name}_htg_TurnOn")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{ems_airloop_avail_status_actuator.name} = CycleOn")
    ems_airloop_night_cyc_mngr_prgm.addLine("RETURN")
    ems_airloop_night_cyc_mngr_prgm.addLine("ELSEIF Tmin > #{air_loop.name}_htg_TurnOff")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{ems_airloop_avail_status_actuator.name} = NoAction")
    ems_airloop_night_cyc_mngr_prgm.addLine("ENDIF")
    ems_airloop_night_cyc_mngr_prgm.addLine("IF Tmax > #{air_loop.name}_clg_TurnOn")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{ems_airloop_avail_status_actuator.name} = CycleOn")
    ems_airloop_night_cyc_mngr_prgm.addLine("ELSEIF Tmax < #{air_loop.name}_clg_TurnOff")
    ems_airloop_night_cyc_mngr_prgm.addLine("SET #{ems_airloop_avail_status_actuator.name} = NoAction")
    ems_airloop_night_cyc_mngr_prgm.addLine("ENDIF")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Program Object named '#{ems_airloop_night_cyc_mngr_prgm.name}' for monitoring unoccupied zone temps and cycling fans and coils servng '#{air_loop.name}' if needed, was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS programs
    program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    program_calling_manager.setName("EMS-based Setpoint Managers")
    program_calling_manager.setCallingPoint("AfterPredictorAfterHVACManagers")
    program_calling_manager.addProgram(ems_vav_sched_setpt_mngr_prgm)
    program_calling_manager.addProgram(ems_mixed_air_setpt_mngr_prgm)
    program_calling_manager.addProgram(ems_airloop_night_cyc_mngr_prgm)
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{program_calling_manager.name}' added to call multiple EMS programs.") 
    end
    
    # create unique object for OutputEnergyManagementSystem object and configure to allow EMS reporting
    outputEMS = model.getOutputEnergyManagementSystem
    outputEMS.setInternalVariableAvailabilityDictionaryReporting("internal_variable_availability_dictionary_reporting")
    outputEMS.setEMSRuntimeLanguageDebugOutputLevel("ems_runtime_language_debug_output_level")
    outputEMS.setActuatorAvailabilityDictionaryReporting("actuator_availability_dictionary_reporting")
    if verbose_info_statements == true
      runner.registerInfo("The EMS Output Energy Management System Program object has been configured per the user arguments.") 
    end
    
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    return true
    
  end
  
end

# register the measure to be used by the application
M2Example2TraditionalSetpointAndAvailabilityManagers.new.registerWithApplication
