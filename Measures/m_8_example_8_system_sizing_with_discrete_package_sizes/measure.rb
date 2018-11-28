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
class M8Example8SystemSizingWithDiscretePackageSizes < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M8 Example 8. System Sizing with Discrete Package Sizes"
  end

# Per page 93 of the EnergyPlus EMS Example Guide   
#  Threshold Sizing Supply Airflow (cfm)		Selection Supply Airflow (cfm)
#         	0 < V ≤ 1200 							    V = 1200
#        1200 < V ≤ 1600 						        V = 1600
#        1600 < V ≤ 2000 						        V = 2000
#        2000 < V ≤ 2360 						        V = 2360
#        2360 < V ≤ 3000					 	        V = 3000
#        3000 < V ≤ 3400 						        V = 3400
#        3400 < V ≤ 4000 						        V = 4000
 
  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus v 8.9.0 Energy Management System Application Guide, Example 8, based on user input."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how EMS functions can be used to demonstrate how information from a sizing run can be used to select HVAC equipment from nominal product sizes where unit total capacity is directly related to the unit supply airflow (1 ton = 1200 cfm, 1.5 ton = 1600 cfm, etc.) of commercial packaged single-zone HVAC air systems. This measure is designed to work on AirLoops with packaged DX cooling equipment only. EMS functions will be used to extract the design supply airflow generated from system auto-sizing calculations. An interval variable is used to override the Sizing:System - 'Intermediate Air System Main Supply Volume Flow Rate' value variable. This measure approximates the manner that appropriate ‘real world’ equipment selections are made by HVAC design engineers. The table below will be used to map to the Maximum Flow rate of the packaged unit Fan:ConstantVolume object."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # Make arrays of qualified air loops names and handles
    airloop_handles = OpenStudio::StringVector.new
    airloop_display_names = OpenStudio::StringVector.new
    show_loop = false
    
    model.getAirLoopHVACs.each do |air_loop|
      if air_loop.designSupplyAirFlowRate.empty?
        supply_comps = air_loop.supplyComponents
        supply_comps.each do |supply_comp|
          if supply_comp.to_CoilCoolingDXSingleSpeed.is_initialized || supply_comp.to_CoilCoolingDXTwoSpeed.is_initialized || supply_comp.to_CoilCoolingDXVariableSpeed.is_initialized
            show_loop = true
          end      
        end # end loop through supply components
      end 
      #if loop as air_loop_air_loop_object of correct type then add to hash.
      if show_loop == true
        airloop_handles << air_loop.handle.to_s
        airloop_display_names << air_loop.name.to_s
      end
    end    
    
    building = model.getBuilding
    if show_loop == true 
      airloop_handles << building.handle.to_s
      airloop_display_names << '*All Autosized AirLoops served by DX Cooling*'    
    end     
       
    # Make an argument for air loops
    air_loop_objects = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("air_loop_objects", airloop_handles, airloop_display_names,true)
    air_loop_objects.setDisplayName("Choose an Air Loop to Alter.")
    air_loop_objects.setDefaultValue('*All Autosized AirLoops served by DX Cooling*') #if no loop is chosen this will run on all air loops
    args << air_loop_objects
    
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
    air_loop_objects = runner.getOptionalWorkspaceObjectChoiceValue('air_loop_objects', user_arguments, model) # model is passed in because of argument type
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)
  
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

    # initialize variables
    counter = 0
    
    # check the airloop for existence in model
    apply_to_all_airloops = false
    selected_airloop = nil
    if air_loop_objects.empty?
      handle = runner.getStringArgumentValue('air_loop_objects', user_arguments)
      if handle.empty?
        runner.registerError('No air loop was chosen.')
        return false
      else
        runner.registerError("The selected air loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if !air_loop_objects.get.to_AirLoopHVAC.empty?
        selected_airloop = air_loop_objects.get.to_AirLoopHVAC.get
      elsif !air_loop_objects.get.to_Building.empty?
        apply_to_all_airloops = true
      else
        runner.registerError('Script Error - argument not showing up as an air loop.')
        return false
      end
    end
    
    # define selected airloop(s), depending on user input, add selected airloops to an array
    selected_airloops = []
    show_loop = false
    if apply_to_all_airloops == true
      model.getAirLoopHVACs.each do |each_airloop|
        if each_airloop.designSupplyAirFlowRate.empty?
          show_loop = true
        end  
        if show_loop == true
           selected_airloops << each_airloop
        end
      end # end loop through airloops       
    else 
      selected_airloops << selected_airloop
    end

    # Further refine selected airloops to only have DX Cooling coils (1, 2 or variable speed)
    selected_airloops.each do |selected_airloop|
      keep_loop = false
      supply_comps = selected_airloop.supplyComponents
      supply_comps.each do |supply_comp|
        if supply_comp.to_CoilCoolingDXSingleSpeed.is_initialized || supply_comp.to_CoilCoolingDXTwoSpeed.is_initialized || supply_comp.to_CoilCoolingDXVariableSpeed.is_initialized
          keep_loop = true
        end      
      end # end loop through supply components 
      if keep_loop == false
        if verbose_info_statements == true
          runner.registerInfo("Autosized Airloop named #{selected_airloop.name} did not contain a DX cooling coil and the airloop will not be modified by this measure.")
          selected_airloops.remove(selected_airloop)
        end
      else
        if verbose_info_statements == true
          runner.registerInfo("keeping airloop #{selected_airloop.name}.")
        end
      end      
    end
    
    if selected_airloops.length == 0
      runner.registerAsNotApplicable("Model contains no 'qualified' AirLoops for this measure to modify.") 
      return true
    end
    
    # declare variables for proper scope
    ems_subroutine_prg = nil
    ems_resize_psz_based_on_clg_airflow_prgm = nil
    ems_prgm_calling_mngr = nil
    
    # Create a 'stub' object for the EnergyManagementSystem:Program object for resizing a PSZ airloop
    ems_resize_psz_based_on_clg_airflow_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_resize_psz_based_on_clg_airflow_prgm.setName("Resize PSZ To Match Product Availability")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_resize_psz_based_on_clg_airflow_prgm.name}' added to resize airloop equipment based on autosized High Speed Airflow of Two Speed DX Clg Coil.") 
    end
    
    # create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS programs
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("Apply Discrete Package Sizes to Air System Sizing")
    ems_prgm_calling_mngr.setCallingPoint("EndOfSystemSizing")
    ems_prgm_calling_mngr.addProgram(ems_resize_psz_based_on_clg_airflow_prgm)
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_resize_psz_based_on_clg_airflow_prgm.name} EMS program.") 
    end
    
    # Create new EnergyManagementSystem:GlobalVariable object and configure to hold the discrete value for MainVDot
    ems_arg_discrete_main_v_dot_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "argDiscreteMainVdot")
    if verbose_info_statements == true
      runner.registerInfo("EMS Global Variable named '#{ems_arg_discrete_main_v_dot_gv.name}' added to hold a discrete airflow value for equipment sizing added to model.") 
    end
    
    # Create new EnergyManagementSystem:GlobalVariable object and configure to hold the discrete value for MainVDot
    ems_arg_main_v_dot_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "argMainVdot")
    if verbose_info_statements == true
      runner.registerInfo("EMS Global Variable named '#{ems_arg_main_v_dot_gv.name}' added to hold a calculated airflow value for equipment sizing added to model.") 
    end
    
    # Create new EnergyManagementSystem:Subroutine object for selecting equipment based on discrete 
    # airflows available from Manufacturer
    ems_subroutine_prg = OpenStudio::Model::EnergyManagementSystemSubroutine.new(model)
    ems_subroutine_prg.setName("Select_Discrete_Nominal_Air_Flow")
    ems_subroutine_prg.addLine("IF (#{ems_arg_main_v_dot_gv.name} <= 0.56628)")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 0.56628")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 0.56628) && (#{ems_arg_main_v_dot_gv.name} <= 0.75504)")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 0.75504")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 0.75504) && (#{ems_arg_main_v_dot_gv.name} <= 0.9438 )")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 0.9438")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 0.9438) && (#{ems_arg_main_v_dot_gv.name} <= 1.13256 )")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 1.13256")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 1.13256) && (#{ems_arg_main_v_dot_gv.name} <= 1.4157 )")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 1.4157")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 1.4157) && (#{ems_arg_main_v_dot_gv.name} <= 1.60446 )")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 1.60446")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 1.60446) && (#{ems_arg_main_v_dot_gv.name} <= 1.8879 )")
    ems_subroutine_prg.addLine("SET #{ems_arg_discrete_main_v_dot_gv.name} = 1.8879")
    ems_subroutine_prg.addLine("ELSEIF (#{ems_arg_main_v_dot_gv.name} > 1.8879)")
    ems_subroutine_prg.addLine("SET dummy = @SevereWarnEP 666.0")
    ems_subroutine_prg.addLine("ENDIF")

    if verbose_info_statements == true
      runner.registerInfo("EMS Subroutine Program object named '#{ems_subroutine_prg.name}' added to reference main EMS program.") 
    end

    # Loop through selected AirLoops, hard size equipment airflow 
    selected_airloops.each do |airloop|
     
      # create a new EnergyManagementSystem:InternalVariable object for holding Intermediate Air System Main Supply Volume Flow Rate
      ems_internal_variable = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, "Intermediate Air System Main Supply Volume Flow Rate")
      ems_internal_variable.setName("#{airloop.name}_CalcMainSupVdot".gsub("-","_"))
      ems_internal_variable.setInternalDataIndexKeyName("#{airloop.name}")  
      if verbose_info_statements == true
        runner.registerInfo("EMS Program Internal Variable object named '#{ems_internal_variable.name}' added to model.") 
      end
      
      # Create new EMS Actuator Object representing airloop system sizing "Main Supply Volume Flow Rate" output variable
      ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(airloop,"Sizing:System","Main Supply Volume Flow Rate")
      ems_actuator.setName("#{airloop.name}MainSupVdotSet".gsub("-","_"))
      if verbose_info_statements == true
        runner.registerInfo("EMS Actuator Object named #{ems_actuator.name} representing the Main Supply Volume Flow Rate of the AirLoop named '#{airloop.name}. added to the model.") 
      end
      
      # Append logic to the EMS program as we iterate through the selected airloop
      ems_resize_psz_based_on_clg_airflow_prgm.addLine("SET #{ems_arg_main_v_dot_gv.name} = #{ems_internal_variable.name}")
      ems_resize_psz_based_on_clg_airflow_prgm.addLine("RUN #{ems_subroutine_prg.name}")
      ems_resize_psz_based_on_clg_airflow_prgm.addLine("SET #{ems_actuator.name} = #{ems_arg_discrete_main_v_dot_gv.name}")
      if verbose_info_statements == true
        runner.registerInfo("Logic appended to the EMS Actuator program Object named '#{ems_resize_psz_based_on_clg_airflow_prgm.name}' calling the EMS subroutine program for the AirLoop object named '#{airloop.name}'.") 
      end
      
    end # end loop through selected airloop objects
    
    # create OutputEnergyManagementSystem object (a 'unique' object) and configure to allow EMS reporting
    output_EMS = model.getOutputEnergyManagementSystem
    output_EMS.setInternalVariableAvailabilityDictionaryReporting('internal_variable_availability_dictionary_reporting')
    output_EMS.setEMSRuntimeLanguageDebugOutputLevel('ems_runtime_language_debug_output_level')
    output_EMS.setActuatorAvailabilityDictionaryReporting('actuator_availability_dictionary_reporting')
    if verbose_info_statements == true
      runner.registerInfo("Output EMS Program Object configured for model.") 
    end
    
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

  end # end run method
  
end # end class

# register the measure to be used by the application
M8Example8SystemSizingWithDiscretePackageSizes.new.registerWithApplication


