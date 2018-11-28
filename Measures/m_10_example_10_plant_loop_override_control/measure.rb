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
class M10Example10PlantLoopOverrideControl < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M10 Example 10. Plant Loop Override Control"
  end
  
  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus v 8.9.0 Energy Management System Application Guide, Example 10, based on user input."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how common warnings generated in .err files can be ‘trapped’ and eliminated by applying conditional logic in an OpenStudio EMS program. In this case, the warning we want to eliminate relates to improper cooling tower operation, and the warning states that the tower temperature is operating below a low temperature limit. The measure will use an EMS program that checks to see if the outdoor temperature is below the allowable temperature for a cooing tower to operate. If this is true, the operation of the plant loop belonging to the cooling tower will be disabled. To properly disable the plant loop, both the loop equipment flow control objects (the condenser pump) and the parent loop itself will be disabled. The loop pump will be disabled by setting an EMS Actuator variable representing the pump mass flow rate to a value of zero. The plant loop object will be disabled by setting the On/Off supervisory control to a value of Off."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # Make arrays of qualified plant loops names and handles
    condenser_plantloop_handles = OpenStudio::StringVector.new
    condenser_plantloop_display_names = OpenStudio::StringVector.new
    model.getPlantLoops.each do |plant_loop|
      show_loop = false
      if plant_loop.sizingPlant.loopType == "Condenser"
        show_loop = true
      end  
      if show_loop == true
        condenser_plantloop_handles << plant_loop.handle.to_s
        condenser_plantloop_display_names << plant_loop.name.to_s
      end
    end # end loop through plant loops   
    
    building = model.getBuilding
    condenser_plantloop_handles << building.handle.to_s
    condenser_plantloop_display_names << '*All Condenser Plant Loops*'    
    
    # Make an argument for condensor plant loop
    condensor_plant_loop_objects = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("condensor_plant_loop_objects", condenser_plantloop_handles, condenser_plantloop_display_names,true)
    condensor_plant_loop_objects.setDisplayName("Choose a Condenser Plant Loop to apply plant control overrides to.")
    condensor_plant_loop_objects.setDefaultValue('*All Condenser Plant Loops*') 
    args << condensor_plant_loop_objects
    
    #make an argument for the OA DB temp below which to disable the condenser plant loop operation 
    oa_db_override_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oa_db_override_temp",true)
    oa_db_override_temp.setDisplayName("The Outdoor Dry Bulb Temp (Deg F) below which the condenser plant loop will not be allowed to operate.")
    oa_db_override_temp.setDefaultValue(42.8)
    args << oa_db_override_temp
 
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
    condensor_plant_loop_objects = runner.getOptionalWorkspaceObjectChoiceValue('condensor_plant_loop_objects', user_arguments, model) # model is passed in because of argument type
    oa_db_override_temp = runner.getDoubleArgumentValue("oa_db_override_temp",user_arguments)
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)
    
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    
    high_limit = 50
    low_limit = 30
    
    if oa_db_override_temp > high_limit
      runner.registerWarning("Value of OA temp of #{oa_db_override_temp} Deg F for loop override is higher then upper warning limit of #{high_limit} Deg F.")
    end
    
    if oa_db_override_temp < low_limit
      runner.registerWarning("Value of OA temp of #{oa_db_override_temp} Deg F for loop override is lower then lower warning limit of #{low_limit} Deg F.")
    end
    
    oa_db_override_temp_SI = OpenStudio.convert(oa_db_override_temp,"F","C")
    
    # check the plantloops for existence in model
    apply_to_all_plantloops = false
    selected_plantloop = nil
    if condensor_plant_loop_objects.empty?
      handle = runner.getStringArgumentValue('condensor_plant_loop_objects', user_arguments)
      if handle.empty?
        runner.registerError('No plant loop was chosen.')
        return false
      else
        runner.registerError("The selected plant loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if !condensor_plant_loop_objects.get.to_PlantLoop.empty?
        selected_plantloop = condensor_plant_loop_objects.get.to_PlantLoop.get
      elsif !condensor_plant_loop_objects.get.to_Building.empty?
        apply_to_all_plantloops = true
      else
        runner.registerError('Script Error - argument not showing up as an air loop.')
        return false
      end
    end
        
    # define selected plantloop(s), depending on user input, add selected plantloop(s) to an array
    selected_plantloops = []
    if apply_to_all_plantloops == true
      model.getPlantLoops.each do |each_plantloop|
        if each_plantloop.sizingPlant.loopType == "Condenser"
          show_loop = true
        end  
        if show_loop == true
           selected_plantloops << each_plantloop
        end
      end # end loop through plantloops       
    else 
      selected_plantloops << selected_plantloop
    end
    
    if selected_plantloops.length == 0
      runner.registerAsNotApplicable("Model contains no 'qualified' PlantLoops for this measure to modify.") 
      return true
    end
    
    # declare variables for proper scope
    counter = 0
    ems_oa_db_sensor = nil
    ems_control_tower_loop_operation_prgm = nil
    ems_prgm_calling_mngr = nil
    
    #Create new EMS Sensor Object representing Site Outdoor Air Drybulb Temperature
    ems_oa_db_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Site Outdoor Air Drybulb Temperature")
    ems_oa_db_sensor.setName("OutdoorTemp")
    ems_oa_db_sensor.setKeyName("Environment")
    if verbose_info_statements == true
      runner.registerInfo("EMS Sensor object named #{ems_oa_db_sensor.name} added to the model to represent the 'Site Outdoor Air Drybulb Temperature'.")
    end
    
    # Create a 'stub' object for the EnergyManagementSystem:Program object for actuation of the condensor loops and re-setting pump flows
    ems_control_tower_loop_operation_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_control_tower_loop_operation_prgm.setName("TowerControl")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_control_tower_loop_operation_prgm.name}' added to control condensor plant loop operation.") 
    end
    
    # Create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS program
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("Condenser OnOff Management")
    ems_prgm_calling_mngr.setCallingPoint("InsideHVACSystemIterationLoop")
    ems_prgm_calling_mngr.addProgram(ems_control_tower_loop_operation_prgm) 
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_control_tower_loop_operation_prgm.name} EMS program.") 
    end
    
    # Loop through selected plantloops
    selected_plantloops.each do |plantloop|
       
      pump = nil 
      counter += 1 
      # get pump object associated with condenser loop
      plantloop.supplyComponents.each do |supply_comp|
        if not supply_comp.to_PumpConstantSpeed.empty?
          pump = supply_comp.to_PumpConstantSpeed.get
        end
        if not supply_comp.to_PumpVariableSpeed.empty?
          pump = supply_comp.to_PumpVariableSpeed.get
        end
      end # end loop through supply components
         
      # Create new EnergyManagementSystem:GlobalVariable object and configure to hold the value for PumpFlowOverrideReport
      pump_flow_override_report = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "PumpFlowOverrideReport#{counter}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable named '#{pump_flow_override_report.name}' to hold a pump flow override report value added to model.") 
      end
      
      # Create new EMS Actuator Object representing plant loop supervisory on/off control 
      plantloop_ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(plantloop,"Plant Loop Overall","On/Off Supervisory")
      plantloop_ems_actuator.setName("#{plantloop.name}Actuator_Loop#{counter}".gsub("-","_"))
      if verbose_info_statements == true
        runner.registerInfo("An EMS Actuator Object named '#{plantloop_ems_actuator.name}' representing a way to set a plantloop on/off supervisory control status has been added to model.") 
      end
      
      # Create new EMS Actuator Object representing condenser loop pump flow override (on/off) control
      pump_flow_override_ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(pump,"Pump","Pump Mass Flow Rate")
      pump_flow_override_ems_actuator.setName("#{plantloop.name}PumpFlowOverride#{counter}".gsub("-","_"))
      if verbose_info_statements == true
        runner.registerInfo("An EMS Actuator Object named '#{pump_flow_override_ems_actuator.name}' representing a way to override the condensor loop pump on/off status has been added to model.") 
      end
      
      # Create new EMS Output Variable Object holding the PumpFlowOverrideReport
      ems_cond_flow_override_on_EMS_output_var = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model,pump_flow_override_report)
      ems_cond_flow_override_on_EMS_output_var.setName("EMS Condenser Flow Override On#{counter}")
      ems_cond_flow_override_on_EMS_output_var.setEMSVariableName("#{pump_flow_override_report.name}")
      ems_cond_flow_override_on_EMS_output_var.setTypeOfDataInVariable("Averaged")
      ems_cond_flow_override_on_EMS_output_var.setUpdateFrequency("SystemTimeStep")
      ems_cond_flow_override_on_EMS_output_var.setUnits("On/Off") 
      
      # Add logic to the EMS program as we iterate through the selected condenser plantloop
      ems_control_tower_loop_operation_prgm.addLine("IF (#{ems_oa_db_sensor.name} < 6.0)")
      ems_control_tower_loop_operation_prgm.addLine("SET #{plantloop_ems_actuator.name} = 0.0")
      ems_control_tower_loop_operation_prgm.addLine("SET #{pump_flow_override_ems_actuator.name} = 0.0")
      ems_control_tower_loop_operation_prgm.addLine("SET #{ems_cond_flow_override_on_EMS_output_var.name} = 1.0")
      ems_control_tower_loop_operation_prgm.addLine("ELSE")
      ems_control_tower_loop_operation_prgm.addLine("SET #{plantloop_ems_actuator.name} = Null")
      ems_control_tower_loop_operation_prgm.addLine("SET #{pump_flow_override_ems_actuator.name} = Null")
      ems_control_tower_loop_operation_prgm.addLine("SET #{ems_cond_flow_override_on_EMS_output_var.name} = 0.0")
      ems_control_tower_loop_operation_prgm.addLine("ENDIF")
    
      output_var = OpenStudio::Model::OutputVariable.new("#{ems_cond_flow_override_on_EMS_output_var.name}", model)
      output_var.setName("#{ems_cond_flow_override_on_EMS_output_var.name}")
      output_var.setKeyValue("*")
      output_var.setReportingFrequency("Hourly")
    
    end # end loop through plantloops
    
    # create OutputEnergyManagementSystem object (a 'unique' object) and configure to allow EMS reporting
    output_EMS = model.getOutputEnergyManagementSystem
    output_EMS.setInternalVariableAvailabilityDictionaryReporting('internal_variable_availability_dictionary_reporting')
    output_EMS.setEMSRuntimeLanguageDebugOutputLevel('ems_runtime_language_debug_output_level')
    output_EMS.setActuatorAvailabilityDictionaryReporting('actuator_availability_dictionary_reporting')
    runner.registerInfo("Output EMS Program Object configured for model.") 
    
    # TODO - add 19 additional output variables from the E+ EMS example "EMSPlantLoopOverrideControl.idf", perhaps using boolean measure arguments for adding them. 
    #1 Site Outdoor Air Drybulb Temperature
    #2 Cooling Tower Inlet Temperature
    #3 Cooling Tower Outlet Temperature
    #4 Cooling Tower Mass Flow Rate
    #5 Cooling Tower Heat Transfer Rate
    #6 Cooling Tower Fan Electric Power
    #7 Zone Air Temperature
    #8 Pump Electric Power
    #9 Pump Outlet Temperature
    #10 Pump Mass Flow Rate
    #11 Plant Supply Side Cooling Demand Rate
    #12 Plant Supply Side Heating Demand Rate
    #13 Plant Supply Side Inlet Mass Flow Rate
    #14 Plant Supply Side Inlet Temperature
    #15 Plant Supply Side Outlet Temperature
   
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
   
  end # end run method
  
end # end class

# register the measure to be used by the application
M10Example10PlantLoopOverrideControl.new.registerWithApplication


