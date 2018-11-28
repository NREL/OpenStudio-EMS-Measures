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
class M5Example5ComputedSchedule < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M5 Example 5. Computed Schedule"
  end

  # human readable description
  def description
    return "This measure replicates the EMS functionality described in Example 5 from the EnergyPlus V8.9 EMS Application Guide."    
  end

  # human readable description of modeling approach
  def modeler_description
    return "The example demonstrates the use of a thermostat schedule object as and EMS actuator object. The EMS program alters the scheduled values as a function of hour of day and day of week."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
   
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # 1) make an argument for <conditioned> thermal zone(s) to apply EMS t-stat schedule changes to 
    tz_handles = OpenStudio::StringVector.new
    tz_display_names = OpenStudio::StringVector.new

    # put thermal zone names into a hash
    tz_hash = {}
    model.getThermalZones.each do |tz|
      tz_hash[tz.name.to_s] = tz
    end

    # looping through a sorted hash of zones
    tz_hash.sort.map do |tz_name, tz|
      if tz.thermostatSetpointDualSetpoint.is_initialized
        tstat = tz.thermostatSetpointDualSetpoint.get
        if tstat.heatingSetpointTemperatureSchedule.is_initialized || tstat.coolingSetpointTemperatureSchedule.is_initialized
          tz_handles << tz.handle.to_s
          tz_display_names << tz_name
        end
      end
    end

    # add building to string vector with zones
    building = model.getBuilding
    tz_handles << building.handle.to_s
    
    tz_display_names << '*All Conditioned Thermal Zones*'    
 
    zones = OpenStudio::Measure::OSArgument.makeChoiceArgument('zones', tz_handles, tz_display_names, true)
    zones.setDisplayName('Choose Conditioned Thermal Zone(s) to apply EMS Program T-stat changes to.')
    zones.setDefaultValue('*All Conditioned Thermal Zones*') # if no zone is chosen this will run on all zones
    args << zones
    
    # 2) make a choice argument for setting EMS InternalVariableAvailabilityDictionaryReporting value
    int_var_avail_dict_rep_chs = OpenStudio::StringVector.new
    int_var_avail_dict_rep_chs << 'None'
    int_var_avail_dict_rep_chs << 'NotByUniqueKeyNames'
    int_var_avail_dict_rep_chs << 'Verbose'
     
    internal_variable_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_variable_availability_dictionary_reporting', int_var_avail_dict_rep_chs, true)
    internal_variable_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_variable_availability_dictionary_reporting.setDefaultValue('None')
    args << internal_variable_availability_dictionary_reporting
    
    # 3) make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    ems_runtime_language_debug_level_chs = OpenStudio::StringVector.new
    ems_runtime_language_debug_level_chs << 'None'
    ems_runtime_language_debug_level_chs << 'ErrorsOnly'
    ems_runtime_language_debug_level_chs << 'Verbose'
    
    ems_runtime_language_debug_output_level = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_runtime_language_debug_output_level', ems_runtime_language_debug_level_chs, true)
    ems_runtime_language_debug_output_level.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_runtime_language_debug_output_level.setDefaultValue('None')
    args << ems_runtime_language_debug_output_level
    
    # 4) make a choice argument for setting EMS ActuatorAvailabilityDictionaryReportingvalue
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
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)
    
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

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
     
    # define selected zones, depending on user input, add selected zones to an array
    selected_zones = []
    if apply_to_all_zones == true
       model.getThermalZones.each do |each_zone|
         if each_zone.thermostatSetpointDualSetpoint.is_initialized
           tstat = each_zone.thermostatSetpointDualSetpoint.get
           if tstat.heatingSetpointTemperatureSchedule.is_initialized || tstat.coolingSetpointTemperatureSchedule.is_initialized
             selected_zones << each_zone
           end
         end  
       end  
    else
      selected_zones << selected_zone
    end

    constant_clg_setpt = 24 # Deg C, from EMS Application Guide
    constant_htg_setpt = 21 # Deg C, from EMS Application Guide
    
    # create ScheduleConstant object for heating schedule 
    constant_htg_setpt_sch = OpenStudio::Model::ScheduleConstant.new(model)
    constant_htg_setpt_sch.setName("HTGSETP_SCH")
    constant_htg_setpt_sch.setValue(constant_htg_setpt)
    if verbose_info_statements == true
      runner.registerInfo("Created new Schedule:Constant object representing constant a heating temp of #{OpenStudio.convert(constant_htg_setpt,"C","F")} deg F.") 
    end
    
    # create ScheduleConstant object for cooling schedule 
    constant_clg_setpt_sch = OpenStudio::Model::ScheduleConstant.new(model)
    constant_clg_setpt_sch.setName("CLGSETP_SCH")
    constant_clg_setpt_sch.setValue(constant_clg_setpt)
    if verbose_info_statements == true
      runner.registerInfo("Created new Schedule:Constant object representing constant a cooling temp of #{OpenStudio.convert(constant_clg_setpt,"C","F")} deg F.") 
    end
    
    #loop through selected conditioned zone(s), find dual setpoint T-stat, and assign new htg and clg T-stat schedules 
    selected_zones.each do |zone|
    
      tstat_dual_setpt = zone.thermostatSetpointDualSetpoint
      if tstat_dual_setpt.is_initialized
        tstat_dual_setpt = tstat_dual_setpt.get
        
        # get existing zone heating t-stat schedule - an OpenStudio resource object
        exg_htg_temp_sch = tstat_dual_setpt.heatingSetpointTemperatureSchedule
        if exg_htg_temp_sch.is_initialized
          exg_htg_temp_sch = exg_htg_temp_sch.get
          exg_htg_temp_sch_name = exg_htg_temp_sch.name
            
          # replace existing heating T-stat schedule with constant temp schedule so that the existing schedule object (a resource  
          # object potentially referenced elsewhere in the osm file) is not tampered with.
          tstat_dual_setpt.setHeatingSchedule(constant_htg_setpt_sch)
          if verbose_info_statements == true
            runner.registerInfo("For Dual Setpoint T-stat serving the zone named #{zone.name}, replaced htg setpoint schedule named #{exg_htg_temp_sch_name} with new schedule named #{constant_htg_setpt_sch.name}.") 
          end
        end
          
        # get existing zone cooling t-stat schedule        
        exg_clg_temp_sch = tstat_dual_setpt.coolingSetpointTemperatureSchedule
        if exg_clg_temp_sch.is_initialized
          exg_clg_temp_sch = exg_clg_temp_sch.get
          exg_clg_temp_sch_name = exg_clg_temp_sch.name
            
          # replace existing cooling T-stat schedule with constant temp schedule so that the existing schedule object (a resource  
          # object potentially referenced elsewhere in the osm file) is not tampered with.
          tstat_dual_setpt.setCoolingSchedule(constant_clg_setpt_sch)
          if verbose_info_statements == true
            runner.registerInfo("For Dual Setpoint T-stat serving zone named #{zone.name}, replaced clg setpoint schedule named #{exg_clg_temp_sch_name} with new schedule named #{constant_clg_setpt_sch.name}.") 
          end
        end
      else
        runner.RegisterError("This measure was written to modify the schedules of an existing Dual Setpoint Thermostat schedule. the zone named #{zone.name} does not have this type of thermostat object. Please correct and re-run.")
        retun false
      end      
    
    end # end loop through selected_zones

    # Create EMS Actuator Objects
    ems_htg_sch_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(constant_htg_setpt_sch,"Schedule:Constant","Schedule Value")
    ems_htg_sch_actuator.setName("myHTGSETP_SCH")
    if verbose_info_statements == true
      runner.registerInfo("EMS Actuator object named '#{ems_htg_sch_actuator.name}' representing the htg t-stat schedule named #{constant_htg_setpt_sch.name} added to the model.") 
    end
    ems_clg_sch_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(constant_clg_setpt_sch,"Schedule:Constant","Schedule Value")
    ems_clg_sch_actuator.setName("myCLGSETP_SCH")
    if verbose_info_statements == true
      runner.registerInfo("EMS Actuator object named '#{ems_clg_sch_actuator.name}' representing the clg t-stat schedule named #{constant_clg_setpt_sch.name} added to the model.") 
    end
    # Create new EnergyManagementSystem:Program object for computing cooling setpoint and modfying the clg schedule
    ems_clg_setpoint_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_clg_setpoint_prg.setName("MyComputedCoolingSetpointProg")
    ems_clg_setpoint_prg.addLine("IF (DayOfWeek == 1)")
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 30.0")
    ems_clg_setpoint_prg.addLine("ELSEIF (Holiday == 3.0) && (DayOfMonth == 21) && (Month == 1)") # Winter Design Day
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 30.0")
    ems_clg_setpoint_prg.addLine("ELSEIF HOUR < 6")
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 30.0")
    ems_clg_setpoint_prg.addLine("ELSEIF (Hour >= 6) && (Hour < 22) && (DayOfWeek >= 2) && (DayOfWeek <= 6)")
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 24.0")
    ems_clg_setpoint_prg.addLine("ELSEIF (Hour >= 6) && (hour < 18) && (DayOfWeek == 7)") 
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 24.0")
    ems_clg_setpoint_prg.addLine("ELSEIF (Hour >= 6) && (hour >= 18) && (DayOfWeek == 7)")
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 30.0")
    ems_clg_setpoint_prg.addLine("ELSEIF (Hour >= 22)")
    ems_clg_setpoint_prg.addLine("SET #{ems_clg_sch_actuator.name} = 30.0")
    ems_clg_setpoint_prg.addLine("ENDIF") 
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_clg_setpoint_prg.name}' added to modify the clg setpoint of qualifed zones based on EMS logic.")
    end
    
    # Create new EnergyManagementSystem:Program object for computing heating setpoint
    ems_htg_setpoint_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_htg_setpoint_prg.setName("MyComputedHeatingSetpointProg")
    ems_htg_setpoint_prg.addLine("SET locHour = Hour")      # Echo out for debug
    ems_htg_setpoint_prg.addLine("SET locDay = DayOfWeek")  # Echo out for debug
    ems_htg_setpoint_prg.addLine("SET locHol = Holiday")    # Echo out for debug
    ems_htg_setpoint_prg.addLine("IF (DayOfWeek == 1)")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 15.6")
    ems_htg_setpoint_prg.addLine("ELSEIF (Holiday == 3.0) && (DayOfYear == 21)")    # Winter Design Day
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 21.0")
    ems_htg_setpoint_prg.addLine("ELSEIF HOUR < 5")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 15.6")
    ems_htg_setpoint_prg.addLine("ELSEIF (Hour >= 5) && (Hour < 19) && (DayOfWeek >= 2) && (DayOfWeek <= 6)")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 21.0")
    ems_htg_setpoint_prg.addLine("ELSEIF (Hour >= 6) && (hour < 17) && (DayOfWeek == 7)")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 21.0")
    ems_htg_setpoint_prg.addLine("ELSEIF (Hour >= 6) && (hour <= 17) && (DayOfWeek == 7)")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 15.6")
    ems_htg_setpoint_prg.addLine("ELSEIF (Hour >= 19)")
    ems_htg_setpoint_prg.addLine("SET #{ems_htg_sch_actuator.name} = 15.6")
    ems_htg_setpoint_prg.addLine("ENDIF")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_htg_setpoint_prg.name}' added to modify the htg setpoint of qualified zone based on EMS logic.")
    end
    
    # create new EnergyManagementSystem:ProgramCallingManager object and configure to call htg and clg setpoint EMS programs
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("My Setpoint Schedule Calculator Example")
    ems_prgm_calling_mngr.setCallingPoint("BeginTimestepBeforePredictor")
    ems_prgm_calling_mngr.addProgram(ems_clg_setpoint_prg)
    ems_prgm_calling_mngr.addProgram(ems_htg_setpoint_prg)
    runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_clg_setpoint_prg.name} and #{ems_htg_setpoint_prg.name} EMS programs.") 
    
    # create OutputEnergyManagementSystem object (a 'unique' object) and configure to allow EMS reporting
    output_EMS = model.getOutputEnergyManagementSystem
    output_EMS.setInternalVariableAvailabilityDictionaryReporting('internal_variable_availability_dictionary_reporting')
    output_EMS.setEMSRuntimeLanguageDebugOutputLevel('ems_runtime_language_debug_output_level')
    output_EMS.setActuatorAvailabilityDictionaryReporting('actuator_availability_dictionary_reporting')
    
    # create output variables for reporting on EMS actuated objects
    htg_schedule_output_variable = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    htg_schedule_output_variable.setReportingFrequency('timestep')
    sch_name = constant_htg_setpt_sch.name.to_s
    htg_schedule_output_variable.setKeyValue(sch_name)
    htg_schedule_output_variable.setVariableName('Schedule Value')
    if verbose_info_statements == true
      runner.registerInfo("A new E+ output variable object named '#{htg_schedule_output_variable.name}' was added to the .rdd file generated by model.") 
    end
    
    clg_schedule_output_variable = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    clg_schedule_output_variable.setReportingFrequency('timestep')
    sch_name =  constant_clg_setpt_sch.name.to_s
    clg_schedule_output_variable.setKeyValue(sch_name)
    clg_schedule_output_variable.setVariableName('Schedule Value')
    if verbose_info_statements == true
      runner.registerInfo("A new E+ output variable object named '#{clg_schedule_output_variable.name}' was added to the .rdd file generated by model.") 
    end
    
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

  end # end run method
  
end # end class

# register the measure to be used by the application
M5Example5ComputedSchedule.new.registerWithApplication


