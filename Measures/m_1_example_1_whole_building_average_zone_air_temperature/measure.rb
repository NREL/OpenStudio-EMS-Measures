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
class M1Example1WholeBuildingAverageZoneAirTemperature < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M1 Example 1. Whole-Building Average Zone Air Temperature"
  end

  # human readable description
  def description
    return "This EMS measure does not control anything – but rather uses EMS sensors and EMS internal variables to generate a single value representing whole-building average temperature, weighted by zonal volume. Only conditioned zones are included in determining the average temperature value. The calculation will be evaluated at each zone timestep. The measure demonstrates the creation and use of the following OpenStudio EMS objects. 1) EnergyManagementSystem:ProgramCallingManager 2) EnergyManagementSystem:Sensor 3) EnergyManagementSystem:InternalVariable 4) EnergyManagementSystem:OutputVariable, 5) EnergyManagementSystem:Program, 6)Output:EnergyManagementSystem"
  end

  # human readable description of modeling approach
  def modeler_description
    return "This EMS measure will uses EnergyManagementSystem:Sensor objects (Zone Temperatures) and EnergyManagementSystem:InternalVariable objects (Zone Volume) to calculate a whole building volume-weighted average temperature at each zone timestep. The result is stored in an EnergyManagementSystem:OutputVariable object."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # make a choice argument for setting InternalVariableAvailabilityDictionaryReporting value
    chs = OpenStudio::StringVector.new
    chs << 'None'
    chs << 'NotByUniqueNames'
    chs << 'Verbose'
    internal_VariableAvailabilityDictionaryReporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_VariableAvailabilityDictionaryReporting', chs, true)
    internal_VariableAvailabilityDictionaryReporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_VariableAvailabilityDictionaryReporting.setDefaultValue('None')
    args << internal_VariableAvailabilityDictionaryReporting
    
    # make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    chs = OpenStudio::StringVector.new
    chs << 'None'
    chs << 'ErrorsOnly'
    chs << 'Verbose'
    ems_RuntimeLanguageDebugOutputLevel = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_RuntimeLanguageDebugOutputLevel', chs, true)
    ems_RuntimeLanguageDebugOutputLevel.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_RuntimeLanguageDebugOutputLevel.setDefaultValue('None')
    args << ems_RuntimeLanguageDebugOutputLevel
    
    # make a choice argument for setting ActuatorAvailabilityDictionaryReporting value
    chs = OpenStudio::StringVector.new
    chs << 'None'
    chs << 'NotByUniqueNames'
    chs << 'Verbose'
    actuator_AvailabilityDictionaryReporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('actuator_AvailabilityDictionaryReporting', chs, true)
    actuator_AvailabilityDictionaryReporting.setDisplayName('Level of output reporting related to the EMS actuators that are available.')
    actuator_AvailabilityDictionaryReporting.setDefaultValue('None')
    args << actuator_AvailabilityDictionaryReporting
    
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
    internal_VariableAvailabilityDictionaryReporting = runner.getOptionalWorkspaceObjectChoiceValue('internal_VariableAvailabilityDictionaryReporting', user_arguments, model) # model is passed in because of argument type
    ems_RuntimeLanguageDebugOutputLevel = runner.getOptionalWorkspaceObjectChoiceValue('ems_RuntimeLanguageDebugOutputLevel', user_arguments, model) # model is passed in because of argument type
    actuator_AvailabilityDictionaryReporting = runner.getOptionalWorkspaceObjectChoiceValue('actuator_AvailabilityDictionaryReporting', user_arguments, model) # model is passed in because of argument type
      
    # initialize variables for proper scope
    conditioned_thermal_zone_count = 0
    zone_mean_air_temp_sensor_name_array = []
    zone_volume_name_array = []
    sum_numerator = 0 
    sum_denominator = 0 
  
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
        
    # loop through all conditioned thermal zones to determine if they qualify for the average temperature calculation
    model.getThermalZones.each do |thermal_zone|

      if thermal_zone.thermostatSetpointDualSetpoint.is_initialized
        t_stat = thermal_zone.thermostatSetpointDualSetpoint.get

        if t_stat.getHeatingSchedule.is_initialized && t_stat.getCoolingSchedule.is_initialized
          # Create new EnergyManagementSystem:Sensor object representing zone mean air temperature  
          ems_zone_mean_air_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Zone Mean Air Temperature")
          ems_zone_mean_air_temp_sensor.setName("T#{conditioned_thermal_zone_count}")
          ems_zone_mean_air_temp_sensor.setKeyName(thermal_zone.name.to_s)
          # store sensor name in array for later post-processing
          zone_mean_air_temp_sensor_name_array << ems_zone_mean_air_temp_sensor.name.to_s
          if verbose_info_statements == true
            runner.registerInfo("EMS Sensor named #{ems_zone_mean_air_temp_sensor.name} measuring the Mean Air Temp of the Thermal Zone named #{thermal_zone.name} added to the model.")
          end
          
          # Create new EnergyManagementSystem:InternalVariable object representing the zone volume  
          ems_zone_volume_internal_variable = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, "#{thermal_zone.name} Zone Air Volume")
          ems_zone_volume_internal_variable.setName("Zn#{conditioned_thermal_zone_count}vol")
          ems_zone_volume_internal_variable.setInternalDataIndexKeyName(thermal_zone.name.to_s)
          ems_zone_volume_internal_variable.setInternalDataType("Zone Air Volume")
          # store internal variable name in an array for later post-processing
          zone_volume_name_array << ems_zone_volume_internal_variable.name.to_s
          conditioned_thermal_zone_count += 1
          if verbose_info_statements == true
            runner.registerInfo("EMS Internal Variable named #{ems_zone_volume_internal_variable.name} representing the volume of the Thermal Zone named #{thermal_zone.name} added.")
          end
          # check to make sure model has at least one conditioned thermal zone else trigger N/A message
          if conditioned_thermal_zone_count == 0 
            runner.registerAsNotApplicable("EMS Measure not applicable because model has zero conditioned thermal zones!")
            return true
          end
        end
      end
    end # end loop through thermal zones
  
    # manipulate string of array of sensor names and internal variables to form string for 
    # EMS program logic statement creating SumNumerator
    pairs = zone_mean_air_temp_sensor_name_array.zip(zone_volume_name_array)
    products = pairs.map{ |a| a[0] + "*" + a[1]}
    sum_numerator = products.join(" + ")
    
    # manipulate string of array of internal variable names to form necessary string for 
    # EMS program logic statement creating SumDenominator
    sum_denominator = zone_volume_name_array.join(" + ")
        
    # create new EnergyManagementSystem:Program object describing the zone temp averaging algorithm
    ems_average_zone_temps = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_average_zone_temps.setName("AverageZoneTemps")
    ems_average_zone_temps.addLine("Set SumNumerator = #{sum_numerator}")
    ems_average_zone_temps.addLine("Set SumDenominator = #{sum_denominator}")
    ems_average_zone_temps.addLine("Set AverageBuildingTemp = SumNumerator / SumDenominator")
    if verbose_info_statements == true
      runner.registerInfo("A new EnergyManagementSystemProgram object named '#{ems_average_zone_temps.name}' was added to the model.")
    end
    
    # create unique object for OutputEnergyManagementSystem object and configure to allow EMS reporting
    outputEMS = model.getOutputEnergyManagementSystem
    outputEMS.setInternalVariableAvailabilityDictionaryReporting("internal_VariableAvailabilityDictionaryReporting")
    outputEMS.setEMSRuntimeLanguageDebugOutputLevel("ems_RuntimeLanguageDebugOutputLevel")
    outputEMS.setActuatorAvailabilityDictionaryReporting("actuator_AvailabilityDictionaryReporting")
    if verbose_info_statements == true
      runner.registerInfo("An OutputEnergyManagementSystem object was configured for EMS program reporting per the user arguments.")
    end
    
    # create new OutputVariable object describing the requested reporting frequency
    output_variable = OpenStudio::Model::OutputVariable.new("Weighted Average Building Zone Air Temperature",model)
    output_variable.setKeyValue("*")
    output_variable.setReportingFrequency("Timestep") 
    output_variable.setVariableName("Weighted Average Building Zone Air Temperature")
    if verbose_info_statements == true
      runner.registerInfo("A new OutputVariable object named '#{output_variable.name}' representing the Weighted Average Building Zone Air Temperature was added to the model.")
    end
    
    # create new EnergyManagementSystem:ProgramCallingManager object and configure to call ems_average_zone_temps EMS Program
    ems_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_program_calling_manager.setName("Average Building Temperature")
    ems_program_calling_manager.setCallingPoint("EndOfZoneTimestepBeforeZoneReporting")
    ems_program_calling_manager.addProgram(ems_average_zone_temps)
    if verbose_info_statements == true
      runner.registerInfo("An EMS Program Calling Manager object named #{ems_program_calling_manager.name} was added to the model.")
    end
    
    # create new EnergyManagementSystem:GlobalVariable object and configure to hold AverageBuildingTemp calculated variable
    average_building_temp = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "AverageBuildingTemp")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Global Variable object named #{average_building_temp.name} representing the Average Building Temperature was added to the model.")
    end
    
    # create new global EnergyManagementSystem:OutputVariable object and configure it to hold the "averaged" value of 
    # the AverageBuildingTemp Global Variable
    ems_average_bldg_temp_ov = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, average_building_temp)
    ems_average_bldg_temp_ov.setName("Weighted Average Building Zone Air Temperature") 
    ems_average_bldg_temp_ov.setEMSVariableName("#{average_building_temp.name}")
    ems_average_bldg_temp_ov.setUnits("C")
    ems_average_bldg_temp_ov.setTypeOfDataInVariable("Averaged")
	ems_average_bldg_temp_ov.setUpdateFrequency("ZoneTimeStep")    
    if verbose_info_statements == true
      runner.registerInfo("An EMS Output Variable object named #{ems_average_bldg_temp_ov.name} representing the Weighted Average Building Zone Air Temperature was added to the model.")
    end
  
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    return true
    
  end # end run method
  
end # end class

# register the measure to be used by the application
M1Example1WholeBuildingAverageZoneAirTemperature.new.registerWithApplication


