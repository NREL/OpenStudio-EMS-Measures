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
class M11Example11PerformanceCurveResultOverride < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M11 Example 11. Performance Curve Result Override"
  end
  
  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus v8.9.0 Energy Management System Application Guide, Example 11, based on user input. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how an OpenStudio measure calling EMS functions can be used to model the performance of HVAC equipment that cannot be represented well by using single “standard” performance curve objects (cubic, quadratic, biquadratic, etc.)  For example, properly characterizing some HVAC equipment objects requires using different performance curves that cover operation of different parts of the performance regime. This measure will alter (overwrite) the Coil Cooling DX Single Speed Cooling Capacity as a function of temperature performance curve object and attributes used by the simulation if the outdoor air temperature falls below a user defined threshold. This measure allows the user to define the biquadratic curve coefficients associated with the Coil Cooling DX Single Speed Cooling Capacity."
  end

  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements
 
    # Choice List Argument for Qualifying DX Cooling Coil Object (should be a member of a PTHP zone equipment object) 
    dx_single_speed_clg_coils_handles = OpenStudio::StringVector.new
    dx_single_speed_clg_coils_display_names = OpenStudio::StringVector.new
    model.getZoneHVACPackagedTerminalHeatPumps.each do |zoneHVACPackagedTerminalHeatPump|
      dx_cooling_coil = zoneHVACPackagedTerminalHeatPump.coolingCoil.to_CoilCoolingDXSingleSpeed.get 
      dx_single_speed_clg_coils_handles << dx_cooling_coil.handle.to_s
      dx_single_speed_clg_coils_display_names << dx_cooling_coil.name.to_s
    end # end loop through coil_cooling_DX_single_speed objects   
    
    building = model.getBuilding
    dx_single_speed_clg_coils_handles << building.handle.to_s
    dx_single_speed_clg_coils_display_names << '*All Single Speed DX Cooling Coils*'    
    
    # Make an argument for CoilCoolingDXSingleSpeeds objects
    coil_cooling_DX_single_speed_objects = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("coil_cooling_DX_single_speed_objects", dx_single_speed_clg_coils_handles, dx_single_speed_clg_coils_display_names,true)
    coil_cooling_DX_single_speed_objects.setDisplayName("Choose a Single Speed DX Cooling Coil belonging to a PTHP object to apply CoolCapFT curve to.")
    coil_cooling_DX_single_speed_objects.setDefaultValue('*All Single Speed DX Cooling Coils*') 
    args << coil_cooling_DX_single_speed_objects
    
    #make an argument for the OA DB temp below which the capacity of the DX cooling coil changes
    oa_db_curve_threshold_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oa_db_curve_threshold_temp",true)
    oa_db_curve_threshold_temp.setDisplayName("The Outdoor Dry Bulb Temp (Deg F) below which the 'CoolCapFT' curve will be enabled.")
    oa_db_curve_threshold_temp.setDefaultValue(87.8)
    args << oa_db_curve_threshold_temp

    # Double Precision Argument for C2A Replacement HPACCoolCapFT biquadratic curve attribute
    c2_a = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_a",true)
    c2_a.setDisplayName("The value of a in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_a.setDefaultValue(0.942567793) 
    args << c2_a

    # Double Precision Argument for C2B Replacement HPACCoolCapFT biquadratic curve attribute
    c2_b = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_b",true)
    c2_b.setDisplayName("The value of b in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_b.setDefaultValue(-0.009543347) 
    args << c2_b
 
    # Double Precision Argument for C2C Replacement HPACCoolCapFT biquadratic curve attribute
    c2_c = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_c",true)
    c2_c.setDisplayName("The value of c in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_c.setDefaultValue(0.000683770)
    args << c2_c

    # Double Precision Argument for C2D Replacement HPACCoolCapFT biquadratic curve attribute
    c2_d = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_d",true)
    c2_d.setDisplayName("The value of d in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_d.setDefaultValue(-0.011042676)
    args << c2_d

    # Double Precision Argument for C2E Replacement HPACCoolCapFT biquadratic curve attribute
    c2_e = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_e",true)
    c2_e.setDisplayName("The value of e in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_e.setDefaultValue(0.000005249)
    args << c2_e

    # Double Precision Argument for C2F Replacement HPACCoolCapFT biquadratic curve attribute
    c2_f = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("c2_f",true)
    c2_f.setDisplayName("The value of f in curve 'a + b (Twb;i) + c (Twb;i) + d (Tc;i) + e (Tc;i) + f (Twb;i) (Tc;i)'.")
    c2_f.setDefaultValue(-0.000009720)
    args << c2_f

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
    coil_cooling_DX_single_speed_objects = runner.getOptionalWorkspaceObjectChoiceValue('coil_cooling_DX_single_speed_objects', user_arguments, model) # model is passed in because of argument type
    oa_db_curve_threshold_temp = runner.getDoubleArgumentValue("oa_db_curve_threshold_temp",user_arguments)
    c2_a = runner.getDoubleArgumentValue("c2_a",user_arguments)
    c2_b = runner.getDoubleArgumentValue("c2_b",user_arguments)
    c2_c = runner.getDoubleArgumentValue("c2_c",user_arguments)
    c2_d = runner.getDoubleArgumentValue("c2_d",user_arguments)
    c2_e = runner.getDoubleArgumentValue("c2_e",user_arguments)
    c2_f = runner.getDoubleArgumentValue("c2_f",user_arguments)
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments)
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments)

    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

    # convert threshold temperature to SI 
    oa_db_curve_threshold_temp_SI = OpenStudio.convert(oa_db_curve_threshold_temp,"F","C")

    # check the dx cooling coils for existence in model
    apply_to_all_dx_single_speed_coils = false
    selected_dx_clg_coils = nil
    
    if coil_cooling_DX_single_speed_objects.empty?
      handle = runner.getStringArgumentValue('coil_cooling_DX_single_speed_objects', user_arguments)
      if handle.empty?
        runner.registerError('No dx coil object was chosen.')
        return false
      else
        runner.registerError("The selected single speed dx cooling coil with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if !coil_cooling_DX_single_speed_objects.get.to_CoilCoolingDXSingleSpeed.empty?
        selected_dx_clg_coils = coil_cooling_DX_single_speed_objects.get.to_CoilCoolingDXSingleSpeed.get
      elsif !coil_cooling_DX_single_speed_objects.get.to_Building.empty?
        apply_to_all_plantloops = true
      else
        runner.registerError('Script Error - argument not showing up as a dx cooling coil.')
        return false
      end
    end

    # define selected single speed dx cooling coils), depending on user input, add selected coil(s) to an array
    selected_dx_single_speed_clg_coils = []
    if apply_to_all_plantloops == true
      model.getCoilCoolingDXSingleSpeeds.each do |each_dx_coil|
        selected_dx_single_speed_clg_coils << each_dx_coil
      end
    else 
      selected_dx_single_speed_clg_coils << selected_dx_clg_coils
    end
    if selected_dx_single_speed_clg_coils.length == 0
      runner.registerAsNotApplicable("Model contains no 'qualified' single speed dx cooling coils attached to PTHP Zone HVAC for this measure to modify.") 
      return true
    end
  
    # declare variables for proper scope
    counter = 0
    oa_db_EMS_sensor = nil
    ems_curve_overwrite_mngr_prgm = nil
    ems_prgm_calling_mngr = nil
    dx_coil_inlet_node = nil
    dx_coil_outlet_node = nil
    oa_mixer_inlet_node_name = nil
    pthp = nil
    
    # Create a 'stub' object for the EnergyManagementSystem:Program object for overriding DX Single Speed clg coil capacity curves 
    ems_curve_overwrite_mngr_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_curve_overwrite_mngr_prgm.setName("CurveOverwriteMGR")
    if verbose_info_statements == true
      runner.registerInfo("EMS Program object named '#{ems_curve_overwrite_mngr_prgm.name}' added to control when clg coil capacity curves will be overridden.") 
    end
    
    # Create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS program
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("EMSBasedCurveManager")
    ems_prgm_calling_mngr.setCallingPoint("AfterPredictorBeforeHVACManagers")
    ems_prgm_calling_mngr.addProgram(ems_curve_overwrite_mngr_prgm)  
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call #{ems_curve_overwrite_mngr_prgm.name} EMS program.") 
    end
    
    # Loop through selected plantloops
    selected_dx_single_speed_clg_coils.each do |dx_clg_coil|
    
      counter += 1
    
      # get curve name for dx_clg_coil object
      cap_curve = dx_clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve
      # Retrieve existing coefficients from curve
    
      if not cap_curve.to_CurveBiquadratic.empty?
        curve_obj = cap_curve.to_CurveBiquadratic.get
        c1_a = curve_obj.coefficient1Constant 
        c1_b = curve_obj.coefficient2x
        c1_c = curve_obj.coefficient3xPOW2
        c1_d = curve_obj.coefficient4y
        c1_e = curve_obj.coefficient5yPOW2
        c1_f = curve_obj.coefficient6xTIMESY
        if verbose_info_statements == true
          runner.registerInfo("retrieve coefficient values of existing Biquadratic curve named #{cap_curve.name} associated with the DX Single Speed Cooling coil named #{dx_clg_coil.name}.")
        end
      else
        runner.registerError("This measure requires the Total Cooling Capacity Function Of Temperature Curve named #{cap_curve.name} associated with the DX Single Speed Cooling coil named #{dx_clg_coil} to be a BiQuadratic Curve. Please correct and re-run.")
        return false
      end 
    
      # retrieve parent PTHP object for 'feedforward' node naming that occurs in osm->idf translator
      if not dx_clg_coil.containingZoneHVACComponent.empty?
        zone_HVAC_component = dx_clg_coil.containingZoneHVACComponent.get
        if not zone_HVAC_component.to_ZoneHVACPackagedTerminalHeatPump.empty?
          pthp = zone_HVAC_component.to_ZoneHVACPackagedTerminalHeatPump.get

          # get dx_clg_coil object inlet node
          # Use PTHP name pattern "<PTHP_NAME> MIXED AIR NODE" Per conversation with Kyle Benne on 4/11/2018,
          dx_coil_inlet_node = "#{pthp.name} Mixed Air Node" 

          #get dx_clg_coil object outlet node
          # Use PTHP name pattern "<PTHP_NAME> COOLING COIL OUTLET NODE" Per conversation with Kyle Benne on 4/11/2018,
          dx_coil_outlet_node = "#{pthp.name} Cooling Coil Outlet Node" 
    
          # get OA mixer object (outdoor air inlet temperature) and (outdoor air inlet pressure) nodes 
          # Use PTHP name pattern "<PTHP_NAME> OA NODE" Per conversation with Kyle Benne on 4/11/2018,
          oa_mixer_inlet_node_name = "#{pthp.name} OA Node"

        end
      end  
    
      # create a new EMS Actuator Object representing the cooling capacity as a function of temperature curve 
      ems_clg_cap_func_temp_curve_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(cap_curve,"Curve","Curve Result")
      ems_clg_cap_func_temp_curve_actuator.setName("CurveOverwrite#{counter}".gsub("-","_"))
      if verbose_info_statements == true
        runner.registerInfo("EMS Actuator object named '#{ems_clg_cap_func_temp_curve_actuator.name}' representing the 'clg curve as a function of temp' object associated with dx cooling coil object named #{dx_clg_coil.name}.") 
      end
      # create new EnergyManagementSystem:GlobalVariable object and configure to hold EMS program results before modifying the curve output
      ems_curve_input_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "CurveInput2_#{counter}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named '#{ems_curve_input_gv.name}' representing results of evaluating the new performance curve associated with #{dx_clg_coil.name} added to the model.") 
      end
      
      # create new EMS Sensor Object representing 'DX Coil capacity as function of temp' curve 
      ems_actual_curve_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Performance Curve Output Value")
      ems_actual_curve_sensor.setName("ActualCurve#{counter}")
      ems_actual_curve_sensor.setKeyName("#{cap_curve.name}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_actual_curve_sensor.name} added to the model to represent the 'Clg Capacity as a Function of Temp' curve associated with the DX cooling coil object named #{dx_clg_coil.name}.")
      end
     
      #Create new EMS Sensor Object representing OA Mixer inlet node pressure 
      ems_oa_mixer_inlet_node_pressure_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Pressure")
      ems_oa_mixer_inlet_node_pressure_sensor.setName("Pressure#{counter}")
      ems_oa_mixer_inlet_node_pressure_sensor.setKeyName("#{oa_mixer_inlet_node_name}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_oa_mixer_inlet_node_pressure_sensor.name} added to the model to represent the 'System Node Pressure' associated with the inlet node of the Outdoor Air Mixer object serving the PTHP object named #{dx_clg_coil.name}.")
      end
      
      #Create new EMS Sensor Object representing dx coil inlet node dry bulb temperature 
      ems_coil_inlet_dbt_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Temperature")
      ems_coil_inlet_dbt_sensor.setName("CoilInletDBT#{counter}")
      ems_coil_inlet_dbt_sensor.setKeyName("#{dx_coil_inlet_node}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_coil_inlet_dbt_sensor.name} added to the model to represent the 'System Node Temperature' associated with the inlet node of the dx coil object named #{dx_clg_coil.name}.")
      end
      
      #Create new EMS Sensor Object representing dx coil inlet node humidity ratio
      ems_coil_inlet_hum_rat_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Humidity Ratio")
      ems_coil_inlet_hum_rat_sensor.setName("CoilInletW#{counter}")
      ems_coil_inlet_hum_rat_sensor.setKeyName("#{dx_coil_inlet_node}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_coil_inlet_hum_rat_sensor.name} added to the model to represent the 'System Node Humidity Ratio' associated with the inlet node of the dx coil object named #{dx_clg_coil.name}.")
      end
      
      #Create new EMS Sensor Object representing OA Mixer inlet node dry bulb temp
      ems_oa_mixer_inlet_node_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "System Node Temperature")
      ems_oa_mixer_inlet_node_temp_sensor.setName("OAT#{counter}")
      ems_oa_mixer_inlet_node_temp_sensor.setKeyName("#{oa_mixer_inlet_node_name}")
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_oa_mixer_inlet_node_temp_sensor.name} added to the model to represent the 'System Node Temperature' associated with the inlet node of the Outdoor Air Mixer object serving the PTHP object named #{dx_clg_coil.name}.")
      end
      
      # create new EnergyManagementSystem:OutputVariable object and configure it to hold the current curve value 
      ems_erl_curve_value_ov = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ems_actual_curve_sensor)
      ems_erl_curve_value_ov.setName("ERLCurveValue#{counter}") 
      ems_erl_curve_value_ov.setEMSVariableName("#{ems_actual_curve_sensor.name}")
      ems_erl_curve_value_ov.setTypeOfDataInVariable("Averaged")
	  ems_erl_curve_value_ov.setUpdateFrequency("ZoneTimeStep")    
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named #{ems_erl_curve_value_ov.name} added to the model to represent the current performance curve value.") 
      end
      
      # create new EnergyManagementSystem:OutputVariable object and configure it to hold the old curve value 
      ems_old_curve_value_gv = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ems_curve_input_gv)
      ems_old_curve_value_gv.setName("OldCurveValue#{counter}") 
      ems_old_curve_value_gv.setEMSVariableName("#{ems_curve_input_gv.name}")
      ems_old_curve_value_gv.setTypeOfDataInVariable("Averaged")
	  ems_old_curve_value_gv.setUpdateFrequency("ZoneTimeStep")    
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named #{ems_old_curve_value_gv.name} added to the model to represent the old performance curve value.") 
      end
      
      # create new EnergyManagementSystem:OutputVariable object and configure it to hold the new curve value 
      ems_new_curve_value_gv = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ems_clg_cap_func_temp_curve_actuator)
      ems_new_curve_value_gv.setName("NewCurveValue#{counter}") 
      ems_new_curve_value_gv.setEMSVariableName("#{ems_clg_cap_func_temp_curve_actuator.name}")
      ems_new_curve_value_gv.setTypeOfDataInVariable("Averaged")
	  ems_new_curve_value_gv.setUpdateFrequency("ZoneTimeStep")    
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named #{ems_new_curve_value_gv.name} added to the model to represent the new performance curve value.") 
      end
      
      # Add logic to the EMS program as we iterate through the selected dx cooling coil objects
      ems_curve_overwrite_mngr_prgm.addLine("SET TTmp_#{counter} = #{ems_coil_inlet_dbt_sensor.name}")
      ems_curve_overwrite_mngr_prgm.addLine("SET WTmp_#{counter} = #{ems_coil_inlet_hum_rat_sensor.name}")
      ems_curve_overwrite_mngr_prgm.addLine("SET PTmp_#{counter} = #{ems_oa_mixer_inlet_node_pressure_sensor.name}")
      ems_curve_overwrite_mngr_prgm.addLine("SET MyWB_#{counter} = @TwbFnTdbWPb TTmp_#{counter} WTmp_#{counter} PTmp_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("SET IVOnea_#{counter} = MyWB_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("SET IVTwo_#{counter} = #{ems_oa_mixer_inlet_node_temp_sensor.name}")
      ems_curve_overwrite_mngr_prgm.addLine("SET IVThree_#{counter} = IVOnea_#{counter}*IVTwo_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C1_#{counter} = #{c1_a}") 
      ems_curve_overwrite_mngr_prgm.addLine("SET C2_#{counter} = #{c1_b}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C3_#{counter} = #{c1_c}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C4_#{counter} = #{c1_d}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C5_#{counter} = #{c1_e}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C6_#{counter} = #{c1_f}")

      ems_curve_overwrite_mngr_prgm.addLine("SET C1_a#{counter} = #{c2_a}") 
      ems_curve_overwrite_mngr_prgm.addLine("SET C2_a#{counter} = #{c2_b}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C3_a#{counter} = #{c2_c}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C4_a#{counter} = #{c2_d}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C5_a#{counter} = #{c2_e}")
      ems_curve_overwrite_mngr_prgm.addLine("SET C6_a#{counter} = #{c2_f}")
    
      # break curve input into two seperate statments (left and right hand) as to not exceed EMS 100 character line limit.
      ems_curve_overwrite_mngr_prgm.addLine("SET LeftCurveInput_#{counter}=C1_#{counter}+(C2_#{counter}*IVOnea_#{counter})+(C3_#{counter}*IVOnea_#{counter}*IVonea_#{counter})")
      ems_curve_overwrite_mngr_prgm.addLine("SET RightCurveInput_#{counter}=(C4_#{counter}*IVTwo_#{counter})+(C5_#{counter}*IVTwo_#{counter}*IVTwo_#{counter})+(C6_#{counter}*IVThree_#{counter})")
      ems_curve_overwrite_mngr_prgm.addLine("SET CurveInput_#{counter} = LeftCurveInput_#{counter} + RightCurveInput_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("SET ##{ems_curve_input_gv.name} = CurveInput_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("IF #{ems_oa_mixer_inlet_node_temp_sensor.name}>#{oa_db_curve_threshold_temp_SI}")
      ems_curve_overwrite_mngr_prgm.addLine("SET LeftCurveInput_#{counter}=C1_a#{counter}+(C2_a#{counter}*IVOnea_#{counter})+(C3_a#{counter}*IVOnea_#{counter}*IVonea_#{counter})")
      ems_curve_overwrite_mngr_prgm.addLine("SET RightCurveInput_#{counter}=(C4_a#{counter}*IVTwo_#{counter})+(C5_a#{counter}*IVTwo_#{counter}*IVTwo_#{counter})+(C6_a#{counter}*IVThree_#{counter})")
      ems_curve_overwrite_mngr_prgm.addLine("SET CurveInput_#{counter}=LeftCurveInput_#{counter} + RightCurveInput_#{counter}")
      ems_curve_overwrite_mngr_prgm.addLine("ENDIF")
      ems_curve_overwrite_mngr_prgm.addLine("SET #{ems_clg_cap_func_temp_curve_actuator.name} = CurveInput_#{counter}")
  
      # create new OutputVariable object describing info at the requested reporting frequency
      erl_curve_value_output_variable = OpenStudio::Model::OutputVariable.new("#{ems_erl_curve_value_ov.name}",model)
      erl_curve_value_output_variable.setKeyValue("*") 
      erl_curve_value_output_variable.setReportingFrequency("Hourly") 
      if verbose_info_statements == true
        runner.registerInfo("EnergyPlus Output Variable object named #{ems_erl_curve_value_ov.name} added to the .rdd file for post-processing.") 
      end
    
      # create new OutputVariable object describing info at the requested reporting frequency
      erl_curve_value_output_variable = OpenStudio::Model::OutputVariable.new("#{ems_old_curve_value_gv.name}",model)
      erl_curve_value_output_variable.setKeyValue("*") 
      erl_curve_value_output_variable.setReportingFrequency("Hourly") 
      if verbose_info_statements == true
        runner.registerInfo("EnergyPlus Output Variable object named #{ems_old_curve_value_gv.name} added to the .rdd file for post-processing.") 
      end
      
      # create new OutputVariable object describing info at the requested reporting frequency
      erl_curve_value_output_variable = OpenStudio::Model::OutputVariable.new("#{ems_new_curve_value_gv.name}",model)
      erl_curve_value_output_variable.setKeyValue("*") 
      erl_curve_value_output_variable.setReportingFrequency("Hourly") 
      if verbose_info_statements == true
        runner.registerInfo("EnergyPlus Output Variable object named #{ems_new_curve_value_gv.name} added to the .rdd file for post-processing.") 
      end
      
    end # end loop through selected dx cooling coils 

    # create new OutputVariable object describing info at the requested reporting frequency
    output_variable_oa_db = OpenStudio::Model::OutputVariable.new("Site Outdoor Air Drybulb Temperature",model)
    output_variable_oa_db.setKeyValue("*")
    output_variable_oa_db.setReportingFrequency("Hourly") 
    output_variable_oa_db.setVariableName("Site Outdoor Air Drybulb Temperature")
    if verbose_info_statements == true
      runner.registerInfo("EnergyPlus Output Variable object named #{output_variable_oa_db.name} added to the .rdd file for post-processing.") 
    end
        
    # create OutputEnergyManagementSystem object (a 'unique' object) and configure to allow EMS reporting
    output_EMS = model.getOutputEnergyManagementSystem
    output_EMS.setInternalVariableAvailabilityDictionaryReporting("internal_variable_availability_dictionary_reporting")
    output_EMS.setEMSRuntimeLanguageDebugOutputLevel("ems_runtime_language_debug_output_level")
    output_EMS.setActuatorAvailabilityDictionaryReporting("actuator_availability_dictionary_reporting")
    if verbose_info_statements == true
      runner.registerInfo("Output EMS Program Object settings configured for the model.") 
    end
    
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

  end # end run method
  
end # end class

# register the measure to be used by the application
M11Example11PerformanceCurveResultOverride.new.registerWithApplication

