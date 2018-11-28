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
class M12Example12VariableRefrigerantFlowSystemOverride < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M12 Example 12. Variable Refrigerant Flow System Override"
  end
  
  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus v 8.9.0 Energy Management System Application Guide, Example 12, based on user input."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how an OpenStudio measure calling EMS functions can be used to override specified thermostat control logic and set alternate modes of operation. This EMS measure sets a specific (user defined) indoor VRF terminal unit to operate at a specific (user-defined) part load ratio, constrained by operate minimum and maximum outdoor temperature limits of the paired condenser unit. The main input objects that implement this example are the variable refrigerant flow actuators that control the VRF system and specific terminal unit. Note that the terminal unit PLR can be controlled without controlling the mode of the VRF condenser, however, the specific terminal unit will operate in whatever mode the existing operation control scheme chooses. This example program simply “sets” the operating mode and PLR, other more complex control algorithms can be developed by the user as needed"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

   # 1) make a choice argument for qualifying VRF outdoor unit
    vrf_outdoor_unit_handles = OpenStudio::StringVector.new
    vrf_outdoor_unit_display_names = OpenStudio::StringVector.new

    # put qualifying VRF outdoor unit names into a hash
    vrf_outdoor_unit_hash = {}
    model.getAirConditionerVariableRefrigerantFlows.each do |outdoor_vrf_unit|
      vrf_outdoor_unit_hash[outdoor_vrf_unit.name.to_s] = outdoor_vrf_unit
    end

    # looping through a sorted hash of outdoor vrf units
    vrf_outdoor_unit_hash.sort.map do |outdoor_vrf_unit_name, outdoor_vrf_unit|
      vrf_outdoor_unit_handles << outdoor_vrf_unit.handle.to_s
      vrf_outdoor_unit_display_names << outdoor_vrf_unit_name
    end

    # add building to string vector with outdoor vrf units
    building = model.getBuilding
    vrf_outdoor_unit_handles << building.handle.to_s
    vrf_outdoor_unit_display_names << '*All Outdoor VRF Units*'  
    
    outdoor_vrf_units_to_modify = OpenStudio::Measure::OSArgument.makeChoiceArgument('outdoor_vrf_units_to_modify', vrf_outdoor_unit_handles, vrf_outdoor_unit_display_names, true)
    outdoor_vrf_units_to_modify.setDisplayName('Choose Outdoor VRF Units to apply EMS Program T-stat control changes to.')
    outdoor_vrf_units_to_modify.setDefaultValue('*All Outdoor VRF Units*') # if no outdoor VRF unit is chosen this will run on all zones
    args << outdoor_vrf_units_to_modify
    
    # 2) make a Double Precision Argument for the fixed PLR value to apply to the attached indoor vrf terminal unit
    indoor_vrf_unit_fixed_plr_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("indoor_vrf_unit_fixed_plr_value",true)
    indoor_vrf_unit_fixed_plr_value.setDisplayName("The fixed PLR value to apply to ALL indoor vrf terminal units attached to the selected outdoor VRF unit(s).")
    indoor_vrf_unit_fixed_plr_value.setDefaultValue(0.5) 
    args << indoor_vrf_unit_fixed_plr_value

    # 3) make a choice argument for setting EMS InternalVariableAvailabilityDictionaryReporting value
    int_var_avail_dict_rep_chs = OpenStudio::StringVector.new
    int_var_avail_dict_rep_chs << 'None'
    int_var_avail_dict_rep_chs << 'NotByUniqueKeyNames'
    int_var_avail_dict_rep_chs << 'Verbose'
     
    internal_variable_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_variable_availability_dictionary_reporting', int_var_avail_dict_rep_chs, true)
    internal_variable_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_variable_availability_dictionary_reporting.setDefaultValue('None')
    args << internal_variable_availability_dictionary_reporting
    
    # 4) make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    ems_runtime_language_debug_level_chs = OpenStudio::StringVector.new
    ems_runtime_language_debug_level_chs << 'None'
    ems_runtime_language_debug_level_chs << 'ErrorsOnly'
    ems_runtime_language_debug_level_chs << 'Verbose'
    
    ems_runtime_language_debug_output_level = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_runtime_language_debug_output_level', ems_runtime_language_debug_level_chs, true)
    ems_runtime_language_debug_output_level.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_runtime_language_debug_output_level.setDefaultValue('None')
    args << ems_runtime_language_debug_output_level
    
    # 5) make a choice argument for setting EMS ActuatorAvailabilityDictionaryReportingvalue
    actuator_avail_dict_rep_chs = OpenStudio::StringVector.new
    actuator_avail_dict_rep_chs << 'None'
    actuator_avail_dict_rep_chs << 'NotByUniqueKeyNames'
    actuator_avail_dict_rep_chs << 'Verbose'
    
    actuator_availability_dictionary_reporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('actuator_availability_dictionary_reporting', actuator_avail_dict_rep_chs, true)
    actuator_availability_dictionary_reporting.setDisplayName('Level of output reporting related to the EMS actuators that are available.')
    actuator_availability_dictionary_reporting.setDefaultValue('None')
    args << actuator_availability_dictionary_reporting
    
    return args
    
  end # end arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    verbose_info_statements = runner.getBoolArgumentValue("verbose_info_statements",user_arguments)
    outdoor_vrf_units_to_modify = runner.getOptionalWorkspaceObjectChoiceValue('outdoor_vrf_units_to_modify', user_arguments, model) # model is passed in because of argument type
    indoor_vrf_unit_fixed_plr_value = runner.getDoubleArgumentValue("indoor_vrf_unit_fixed_plr_value",user_arguments)
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)

    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

    # check for reasonableness of plr value
    if indoor_vrf_unit_fixed_plr_value <= 0.0
      runner.registerError("The value of #{indoor_vrf_unit_fixed_plr_value} entered for the PLR value must be greater than zero.")
    end

    if indoor_vrf_unit_fixed_plr_value > 1.0
      runner.registerError("The value of #{indoor_vrf_unit_fixed_plr_value} entered for the PLR value must be less then 1.0.")
    end
    
    # check the VRF outdoor unit for existence in model
    apply_to_all_vrf_outdoor_units = false
    selected_vrf_outdoor_units = nil
    
    if outdoor_vrf_units_to_modify.empty?
      handle = runner.getStringArgumentValue('outdoor_vrf_units_to_modify', user_arguments)
      if handle.empty?
        runner.registerError('No VRF Outdoor Unit object was chosen.')
        return false
      else
        runner.registerError("The selected VRF outdoor unit object with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if !outdoor_vrf_units_to_modify.get.to_AirConditionerVariableRefrigerantFlow.empty?
        selected_vrf_outdoor_units = outdoor_vrf_units_to_modify.get.to_AirConditionerVariableRefrigerantFlow.get
      elsif !outdoor_vrf_units_to_modify.get.to_Building.empty?
        apply_to_all_vrf_outdoor_units = true
      else
        runner.registerError('Script Error - argument not showing up as an outdoor VRF unit.')
        return false
      end
    end
    
    # define selected outdoor vrf unit objects, depending on user input, add selected vrf unit(s) to an array
    selected_outdoor_vrf_units = []
    if apply_to_all_vrf_outdoor_units == true
      model.getAirConditionerVariableRefrigerantFlows.each do |each_vrf_outdoor_unit|
        selected_outdoor_vrf_units << each_vrf_outdoor_unit
      end
    else 
      selected_outdoor_vrf_units << selected_vrf_outdoor_units
    end
    if selected_outdoor_vrf_units.length == 0
      runner.registerAsNotApplicable("Model contains no 'qualified' VRF outdoor unit objects for this measure to modify.") 
      return true
    end
    
    # declare variables for proper scope
    vrf_outdoor_unit_counter = 0
    vrf_indoor_unit_counter = 0
    ems_vrf_control_prgm = nil
    ems_prgm_calling_mngr = nil
 
    # Create a stub for the EnergyManagementSystem:Program object for initializing the VRF control modes
    ems_initialize_vrf_control_modes_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_initialize_vrf_control_modes_prgm.setName("InitializeVRFControlModes")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_initialize_vrf_control_modes_prgm.name} was added to initialize the control mode of specified VRF outdoor unit(s).")
    end
    
    # Create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS program "Init VRF Control Mode Constants"
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("Init VRF Control Mode Constants")
    ems_prgm_calling_mngr.setCallingPoint("BeginNewEnvironment")
    ems_prgm_calling_mngr.addProgram(ems_initialize_vrf_control_modes_prgm)  
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_initialize_vrf_control_modes_prgm.name} EMS program.") 
    end
    
    # Create a stub for the EnergyManagementSystem:Program object for actuation of the VRF outdoor unit
    ems_vrf_control_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_vrf_control_prgm.setName("VRFControl")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_vrf_control_prgm.name} was added to override the specified thermostat control logic of the VRF outdor unit.")
    end
    
    # Create a second new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS program "VRF OnOff Management"
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("VRF OnOff Management")
    ems_prgm_calling_mngr.setCallingPoint("InsideHVACSystemIterationLoop")
    ems_prgm_calling_mngr.addProgram(ems_vrf_control_prgm)  
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_vrf_control_prgm.name} EMS program.") 
    end
    
    #Loop through selected vrf outdoor unit objects
    selected_outdoor_vrf_units.each do |outdoor_vrf_unit|
      vrf_outdoor_unit_counter += 1
      
      # create new EMS Global Variable objects representing the operating status of the VRF outdoor unit 
      ems_vrf_status_off_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "vrf_status_off_#{vrf_outdoor_unit_counter}")
      ems_vrf_status_cooling_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "vrf_status_cooling_#{vrf_outdoor_unit_counter}")
      ems_vrf_status_heating_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "vrf_status_heating_#{vrf_outdoor_unit_counter}")

      # Append logic statements to the EMS program as we iterate through the selected outdoor vrf unit objects
      ems_initialize_vrf_control_modes_prgm.addLine("SET #{ems_vrf_status_off_gv.name} = 0.0")
      ems_initialize_vrf_control_modes_prgm.addLine("SET #{ems_vrf_status_cooling_gv.name} = 1.0")
      ems_initialize_vrf_control_modes_prgm.addLine("SET #{ems_vrf_status_heating_gv.name} = 2.0")
      
      # create a new VRF outdoor unit EMS actuator object representing the operating status of the VRF outdoor unit 
      ems_outdoor_vrf_unit_status_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(outdoor_vrf_unit,"Variable Refrigerant Flow Heat Pump","Operating Mode")
      ems_outdoor_vrf_unit_status_actuator.setName("VRF_Actuator_OnOff#{vrf_outdoor_unit_counter}".gsub("-","_"))
      if verbose_info_statements == true
        runner.registerInfo("An EMS Actuator object named '#{ems_outdoor_vrf_unit_status_actuator.name}' representing the Operating Mode of 'Variable Refrigerant Flow Heat Pump' object named #{outdoor_vrf_unit.name} was added to the model.") 
      end
      
      # place attached indoor vrf indoor terminal unit objects into an array
      indoor_unit_terminals_vector = outdoor_vrf_unit.terminals
      if indoor_unit_terminals_vector.count == 0
        runner.registerInfo("VRF Outdoor unit object named #{outdoor_vrf_unit.name} does not appear to have any connected indoor VF terminal unit objects.")
      end
      
      indoor_unit_terminals_vector.each do |indoor_unit_terminal|
        
        vrf_indoor_unit_counter += 1
        
        # loop through the indoor terminal units to create an actuator associated with the part load ratio attribute of the indoor unit object
        ems_indoor_vrf_unit_PLR_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(indoor_unit_terminal,"Variable Refrigerant Flow Terminal Unit","Part Load Ratio")
        ems_indoor_vrf_unit_PLR_actuator.setName("#{indoor_unit_terminal.name}_VRF#{vrf_outdoor_unit_counter}".gsub("-","_"))
        if verbose_info_statements == true
          runner.registerInfo("An EMS Actuator object named '#{ems_indoor_vrf_unit_PLR_actuator.name}' representing the PLR value associated with the 'Variable Refrigerant Flow Indoor Terminal Unit' object named #{indoor_unit_terminal.name} was added to the model.") 
        end
        
        # Append logic statements to the EMS program as we iterate through the attached indoor vrf unit objects
        ems_vrf_control_prgm.addLine("SET #{ems_outdoor_vrf_unit_status_actuator.name} = #{ems_vrf_status_heating_gv.name}")
        ems_vrf_control_prgm.addLine("SET #{ems_indoor_vrf_unit_PLR_actuator.name} = #{indoor_vrf_unit_fixed_plr_value}")
    
      end # end loop throught associated indoor VRF units
    
      # create new EnergyManagementSystem:OutputVariable object and configure it to hold the VRF outdoor unit control status 
      vrf_outdoor_unit_control_status_value = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ems_outdoor_vrf_unit_status_actuator)
      vrf_outdoor_unit_control_status_value.setName("Erl VRF Control Status#{vrf_outdoor_unit_counter}") 
      vrf_outdoor_unit_control_status_value.setEMSVariableName("#{ems_outdoor_vrf_unit_status_actuator.name}")
      vrf_outdoor_unit_control_status_value.setTypeOfDataInVariable("Averaged")
	  vrf_outdoor_unit_control_status_value.setUpdateFrequency("SystemTimeStep")    
    
    end # end loop through VRF outdoor units   
      
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    
  end # end run method
  
end # end class

# register the measure to be used by the application
M12Example12VariableRefrigerantFlowSystemOverride.new.registerWithApplication

