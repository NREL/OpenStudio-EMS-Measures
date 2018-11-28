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
class M4Example4HaltProgramBasedOnConstraint < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "m_4_example_4_halt_program_based_on_constraint"
  end

  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus Energy Management System Application Guide, Example 4., based on user input."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how results from custom and intermediate calculations evaluated during an OpenStudio simulation workflow can be used to trigger a ‘graceful failure’ based on a predetermined limits or constraint. Exercising this feature can be useful when users are attempting to efficiently manage resources needed for a simulation study involving a large parameter space. When used properly, this feature effectively provides dynamic ‘pruning’ of the overall solution space based on user-defined triggers for halting a simulation. In addition to selecting a thermal zone, users will be asked to define both lower (a.bc) and upper (x.yz) PMV limits for triggering the ‘graceful failure’. An EMS Trend Variable will be configured for the Thermal Zone output variable named “Zone Thermal Comfort Fanger Model PMV”.  If the trended average of the output variable is greater that a user-defined value (a.bc), the measure will fail and generate an error code of “900a.bc”. If a trended average the output variable greater than the user-defined value (x.yz), the measure will gracefully fail with the error code 100x.yz."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
     # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # Choice List Argument - Select <conditioned> thermal zone to apply PMV criteria to 
    # declare necessary variables for proper scope
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
    tz_display_names << '*All Thermal Zones*'    

    # make an argument for zones
    zones = OpenStudio::Measure::OSArgument.makeChoiceArgument('zones', tz_handles, tz_display_names, true)
    zones.setDisplayName('Choose Conditioned Thermal Zone(s) to apply EMS Fanger comfort model PMV graceful failure limits to. NOTE: The thermal zone must have People objects attached to it..')
    args << zones

    # make a bool argument for ASHRAE 55 Comfort Warnings
    comfortWarnings = OpenStudio::Measure::OSArgument.makeBoolArgument('comfortWarnings', true)
    comfortWarnings.setDisplayName('Enable ASHRAE 55 Comfort Warnings?')
    comfortWarnings.setDefaultValue(false)
    args << comfortWarnings
    
    # make a choice argument for Mean Radiant Temperature Calculation Type
    chs1 = OpenStudio::StringVector.new
    chs1 << 'ZoneAveraged'
    chs1 << 'SurfaceWeighted'
    meanRadiantCalcType = OpenStudio::Measure::OSArgument.makeChoiceArgument('meanRadiantCalcType', chs1, true)
    meanRadiantCalcType.setDisplayName('Mean Radiant Temperature Calculation Type.')
    meanRadiantCalcType.setDefaultValue('ZoneAveraged')
    args << meanRadiantCalcType

    # putting raw schedules and names into hash
    schedule_args = model.getSchedules
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
    end

    # populate choice argument for fractional schedules
    fractional_schedule_handles = OpenStudio::StringVector.new
    fractional_schedule_display_names = OpenStudio::StringVector.new

    # looping through sorted hash of schedules to find fractional schedules
    schedule_args_hash.sort.map do |key, value|
      next if value.scheduleTypeLimits.empty?
      if (value.scheduleTypeLimits.get.unitType == 'Dimensionless') && !value.scheduleTypeLimits.get.lowerLimitValue.empty? && !value.scheduleTypeLimits.get.upperLimitValue.empty?
        next if value.scheduleTypeLimits.get.lowerLimitValue.get != 0.0
        next if value.scheduleTypeLimits.get.upperLimitValue.get != 1.0
        fractional_schedule_handles << value.handle.to_s
        fractional_schedule_display_names << key
      end
    end
        
    # make a choice schedule for Work Efficiency Schedule
    work_efficiency_schedule = OpenStudio::Measure::OSArgument.makeChoiceArgument('work_efficiency_schedule', fractional_schedule_handles, fractional_schedule_display_names, true)
    work_efficiency_schedule.setDisplayName('Choose a Work Efficiency Schedule.')
    args << work_efficiency_schedule

    
    #populate choice argument for clothing insulation schedules
    clothing_schedule_handles = OpenStudio::StringVector.new
    clothing_schedule_display_names = OpenStudio::StringVector.new

    #looping through sorted hash of schedules to find clothing insulation schedules
    schedule_args_hash.sort.map do |key,value|
      next if value.scheduleTypeLimits.empty?
      if value.scheduleTypeLimits.get.unitType == "ClothingInsulation"
        clothing_schedule_handles << value.handle.to_s
        clothing_schedule_display_names << key
      end
    end

    #make a choice argument for Clothing Insulation Schedule Name
    clothing_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("clothing_schedule",clothing_schedule_handles, clothing_schedule_display_names,true)
    clothing_schedule.setDisplayName("Choose a Clothing Insulation Schedule.")
    if clothing_schedule_display_names.size > 0
      clothing_schedule.setDefaultValue(clothing_schedule_display_names[0]) #normally I don't default model choice list, but since often there might be just one I decided to default this.
    end
    args << clothing_schedule

    
    # populate choice argument for air velocity schedules
    airVelocity_schedule_handles = OpenStudio::StringVector.new
    airVelocity_schedule_display_names = OpenStudio::StringVector.new

    # looping through sorted hash of schedules to find air velocity schedules
    schedule_args_hash.sort.map do |key, value|
      next if value.scheduleTypeLimits.empty?
      if value.scheduleTypeLimits.get.unitType == 'Velocity'
        airVelocity_schedule_handles << value.handle.to_s
        airVelocity_schedule_display_names << key
      end
    end

    # make a choice argument for Air Velocity Schedule Name
    air_velocity_schedule = OpenStudio::Measure::OSArgument.makeChoiceArgument('air_velocity_schedule', airVelocity_schedule_handles, airVelocity_schedule_display_names, true)
    air_velocity_schedule.setDisplayName('Choose an Air Velocity Schedule.')
    if !airVelocity_schedule_display_names.empty?
      air_velocity_schedule.setDefaultValue(airVelocity_schedule_display_names[0]) # normally I don't default model choice list, but since often there might be just one I decided to default this.
    end
    args << air_velocity_schedule
    
    # make a choice argument for Model Timestep
    chs2 = OpenStudio::StringVector.new
    chs2 << '60'
    chs2 << '30'
    chs2 << '15'
    chs2 << '10'
    chs2 << '6'
    model_time_step = OpenStudio::Measure::OSArgument.makeChoiceArgument('model_time_step', chs2, true)
    model_time_step.setDisplayName('Timestep to be used for model, in minutes.')
    model_time_step.setDefaultValue('15')
    args << model_time_step
 
    # make a choice argument for number of hours to trend the Zone PMV before comparing to threshold
    chs3 = OpenStudio::StringVector.new
    chs3 << '2'
    chs3 << '3'
    pmv_trend_length = OpenStudio::Measure::OSArgument.makeChoiceArgument('pmv_trend_length', chs3, true)
    pmv_trend_length.setDisplayName('Length of time to extend the Zone PMV calc, in hours.')
    pmv_trend_length.setDefaultValue('2')
    args << pmv_trend_length
   
    # Populate double precision argument for the Minimum Fanger PMV Value to trigger a graceful failure (program halt) 
    min_pmv_thresh = OpenStudio::Measure::OSArgument.makeDoubleArgument('min_pmv_thresh', true)
    min_pmv_thresh.setDisplayName('The minimum Fanger Model PMV that if below, will trigger a simulation halt.')
    min_pmv_thresh.setDefaultValue(1.3)
    args << min_pmv_thresh
    
    # Populate double precision value for the Maximum Fanger PMV Value to trigger a graceful failure (program halt) 
    max_pmv_thresh = OpenStudio::Measure::OSArgument.makeDoubleArgument('max_pmv_thresh', true)
    max_pmv_thresh.setDisplayName('The maximum Fanger Model PMV that if above, will trigger a simulation halt.')
    max_pmv_thresh.setDefaultValue(2.5)
    args << max_pmv_thresh
    
     # make a choice argument for setting InternalVariableAvailabilityDictionaryReporting value
    chs4 = OpenStudio::StringVector.new
    chs4 << 'None'
    chs4 << 'NotByUniqueKeyNames'
    chs4 << 'Verbose'
     
    internal_VariableAvailabilityDictionaryReporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('internal_VariableAvailabilityDictionaryReporting', chs4, true)
    internal_VariableAvailabilityDictionaryReporting.setDisplayName('Level of output reporting related to the EMS internal variables that are available.')
    internal_VariableAvailabilityDictionaryReporting.setDefaultValue('None')
    args << internal_VariableAvailabilityDictionaryReporting
    
    # make a choice argument for setting EMSRuntimeLanguageDebugOutputLevel value
    chs5 = OpenStudio::StringVector.new
    chs5 << 'None'
    chs5 << 'ErrorsOnly'
    chs5 << 'Verbose'
    ems_RuntimeLanguageDebugOutputLevel = OpenStudio::Measure::OSArgument.makeChoiceArgument('ems_RuntimeLanguageDebugOutputLevel', chs5, true)
    ems_RuntimeLanguageDebugOutputLevel.setDisplayName('Level of output reporting related to the execution of EnergyPlus Runtime Language, written to .edd file.')
    ems_RuntimeLanguageDebugOutputLevel.setDefaultValue('None')
    args << ems_RuntimeLanguageDebugOutputLevel
    
    # make a choice argument for setting ActuatorAvailabilityDictionaryReportingvalue
    chs6 = OpenStudio::StringVector.new
    chs6 << 'None'
    chs6 << 'NotByUniqueKeyNames'
    chs6 << 'Verbose'
    actuator_AvailabilityDictionaryReporting = OpenStudio::Measure::OSArgument.makeChoiceArgument('actuator_AvailabilityDictionaryReporting', chs6, true)
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
    zones = runner.getOptionalWorkspaceObjectChoiceValue('zones', user_arguments, model) # model is passed in because of argument type
    verbose_info_statements = runner.getBoolArgumentValue("verbose_info_statements",user_arguments)
    comfortWarnings = runner.getBoolArgumentValue('comfortWarnings', user_arguments)
    min_pmv_thresh = runner.getDoubleArgumentValue('min_pmv_thresh', user_arguments)
    max_pmv_thresh = runner.getDoubleArgumentValue('max_pmv_thresh', user_arguments)
    meanRadiantCalcType = runner.getStringArgumentValue('meanRadiantCalcType', user_arguments)
    work_efficiency_schedule = runner.getOptionalWorkspaceObjectChoiceValue('work_efficiency_schedule', user_arguments, model) # model is passed in because of argument type
    clothing_schedule = runner.getOptionalWorkspaceObjectChoiceValue('clothing_schedule', user_arguments, model)
    air_velocity_schedule = runner.getOptionalWorkspaceObjectChoiceValue('air_velocity_schedule', user_arguments, model)
    model_time_step = runner.getStringArgumentValue('model_time_step', user_arguments)
    pmv_trend_length = runner.getStringArgumentValue('pmv_trend_length', user_arguments)
    internal_VariableAvailabilityDictionaryReporting = runner.getStringArgumentValue('internal_VariableAvailabilityDictionaryReporting', user_arguments)
    ems_RuntimeLanguageDebugOutputLevel = runner.getStringArgumentValue('ems_RuntimeLanguageDebugOutputLevel', user_arguments) 
    actuator_AvailabilityDictionaryReporting = runner.getStringArgumentValue('actuator_AvailabilityDictionaryReporting', user_arguments) 

    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
 
    # check the zone selection for reasonableness
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
      
    # check the clothing, work efficiency and air velocity schedules for reasonableness
    if clothing_schedule.empty? or air_velocity_schedule.empty? or work_efficiency_schedule.empty?
      runner.registerError('Script Error - one of the schedule arguments is not showing up as an argument.')
      return false
    else
      work_efficiency_schedule = work_efficiency_schedule.get.to_Schedule.get
      clothing_schedule = clothing_schedule.get.to_Schedule.get
      air_velocity_schedule = air_velocity_schedule.get.to_Schedule.get
    end
    
    # check to ensure the min PMV threshold < max PMV threshold
    if min_pmv_thresh >= max_pmv_thresh
      runner.Register("The value for the Minimum PMV Threshold of #{min_pmv_thresh} must be less then #{max_pmv_thresh}, the value for the Maximum PMV Threshold ")
      return false
    end 
    
    # set the model timestep per the user argument
    timestep = model.getTimestep
    initial_timestep = timestep.numberOfTimestepsPerHour
    initial_timestep = (60 / (initial_timestep)).to_i # convert to correct integer values
    if initial_timestep == model_time_step.to_i
      if verbose_info_statements == true
        runner.registerInfo("Model Timestep not changed from original value of #{initial_timestep} steps per hour.")
      end
    else
      model.getSimulationControl.timestep.get.setNumberOfTimestepsPerHour(model_time_step.to_i) 
      if verbose_info_statements == true
        runner.registerInfo("Model Timestep changed from original value of #{initial_timestep} to #{model_time_step} steps per hour.") 
      end
    end
    
    # check to make sure # condituioned thermal zones > 0
    flip = false
    model.getThermalZones.each do |tz|
      if tz.thermostatSetpointDualSetpoint.is_initialized
        flip = true
      end
    end 
    if flip == false
      runner.registerAsNotApplicible("Model has conditioned thermal zones - measure is not applicible.")
      return true
    end
    
    # check to see if PMV upper value > PMV lower value 
    if min_pmv_thresh > max_pmv_thresh
      runner.registerError("Argument entered for minimum PMV threshold is greater than the argument entered for the maximum PMV threshold. Please correct and re-run")
      return false
    end

    # define selected zones, depending on user input, add selected zones to an array
    selected_zones = []
    if apply_to_all_zones == true
      selected_zones = model.getThermalZones
    else
      selected_zones << selected_zone
    end
  
    # calculate number of timestepin the trend to average
    trend_timesteps = (pmv_trend_length.to_i * 60 / model_time_step.to_i).round
   
    # Loop through selected thermal zones to add appropriate EMS object
    counter = 0
    selected_zones.each do |zone|
      counter += 1
                 
      #get all spaces associated with the thermal zone and loop through them 
      spaces = zone.spaces
      spaces.each do |space|
        
        # check attributes of the people objects that are associated with the space via a spacetype. 
        spacetype = space.spaceType
        if not spacetype.empty?
          spacetype = spacetype.get
          
          #loop through all people objects associated to the space via the spacetype, and change the work efficiency, clothing and air velocity schedules as needed
          spacetype.people.each do |spacetype_people_object|

            if not spacetype_people_object.workEfficiencySchedule.is_initialized
              spacetype_people_object.setWorkEfficiencySchedule(work_efficiency_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Assigning a new work efficiency schedule named #{work_efficiency_schedule.name} to the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
              end
            else
              if spacetype_people_object.workEfficiencySchedule.get.to_Schedule.get == work_efficiency_schedule
                if verbose_info_statements == true
                  runner.registerInfo("The people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype named #{spacetype.name} already had a work efficiency schedule named #{work_efficiency_schedule.name} assigned to it.")
                end
              else
                old_work_efficiency_schedule = spacetype_people_object.workEfficiencySchedule.get.to_Schedule.get
                spacetype_people_object.setWorkEfficiencySchedule(work_efficiency_schedule)
                if verbose_info_statements == true
                  runner.registerInfo("Replacing the work efficiency schedule from #{old_work_efficiency_schedule.name} to #{work_efficiency_schedule.name}, for the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
                end        
              end
            end            
            if not spacetype_people_object.clothingInsulationSchedule.is_initialized
              spacetype_people_object.setClothingInsulationSchedule(clothing_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Setting the clothing insulation schedule to #{clothing_schedule.name}, for the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
              end
            else
              if spacetype_people_object.clothingInsulationSchedule.get.to_Schedule.get == clothing_schedule
                if verbose_info_statements == true
                  runner.registerInfo("The people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype named #{spacetype.name} already had a clothing efficiency schedule named #{clothing_schedule.name} assigned to it.")
                end
              else
                old_clothing_insulation_schedule = spacetype_people_object.clothingInsulationSchedule.get.to_Schedule.get
                spacetype_people_object.setClothingInsulationSchedule(clothing_schedule)
                if verbose_info_statements == true
                  runner.registerInfo("Replacing the clothing insulation schedule from #{old_clothing_insulation_schedule.name} to #{clothing_schedule.name}, for the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
                end
              end
            end
            
            if not spacetype_people_object.airVelocitySchedule.is_initialized
              spacetype_people_object.setAirVelocitySchedule(air_velocity_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Setting the air velocity schedule to #{air_velocity_schedule.name}, for the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
              end
            else         
              if spacetype_people_object.airVelocitySchedule.get.to_Schedule.get == air_velocity_schedule
                if verbose_info_statements == true
                  if verbose_info_statements == true
                    runner.registerInfo("The people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype named #{spacetype.name} already had an air velocity schedule named #{air_velocity_schedule.name} assigned to it.")
                  end
                end
              else
                old_air_velocity_schedule = spacetype_people_object.airVelocitySchedule.get.to_Schedule.get
                spacetype_people_object.setAirVelocitySchedule(air_velocity_schedule)
                if verbose_info_statements == true
                  runner.registerInfo("Replacing the air velocity schedule from #{old_air_velocity_schedule.name} to #{air_velocity_schedule.name}, for the people object named #{spacetype_people_object.name} attached to the space named #{space.name} via the spacetype #{spacetype.name}.")
                end
              end            
            end
            
            # get people definition object associated with people object
            people_def_object = spacetype_people_object.peopleDefinition
            
            if people_def_object.enableASHRAE55ComfortWarnings != comfortWarnings
              people_def_object.setEnableASHRAE55ComfortWarnings(comfortWarnings)
              if verbose_info_statements == true
                runner.registerInfo("Altering #{people_def_object.name} associated with space named #{space.name} attached to spacetype name #{spacetype.name} to enable ASHRAE55 Comfort Warnings.")
              end
            else
              if verbose_info_statements == true
                runner.registerInfo("No change made to the setting for enabling ASHRAE55 Comfort Warnings for #{people_def_object.name} people definition object, already set to #{comfortWarnings}.")
              end
            end            
          
            if people_def_object.meanRadiantTemperatureCalculationType.to_s != meanRadiantCalcType
              people_def_object.setMeanRadiantTemperatureCalculationType(meanRadiantCalcType)
              if verbose_info_statements == true
                runner.registerInfo("Altering #{people_def_object.name} associated with space named #{space.name} attached to spacetype name #{spacetype.name} to set mean radiant temeperature calcs to #{meanRadiantCalcType}.")
              end
            else
              if verbose_info_statements == true
                runner.registerInfo("No change made to the setting for mean radiant temperature calcs for #{people_def_object.name} people definition object, already set to '#{meanRadiantCalcType}'.")
              end
            end            
              
            people_def_object.setThermalComfortModelType(0, 'Fanger')
            if verbose_info_statements == true
              runner.registerInfo("Altering #{people_def_object.name} associated with space named #{space.name} attached to spacetype name #{spacetype.name} to set Thermal Comfort Model Type to 'Fanger'.")
            end
          end # end loop through people objects associated with spacetype            
        
        else
          if verbose_info_statements == true
            runner.registerInfo("space named #{space.name} does not have a spacetype assigned to it.")
          end
        end
        
        # get all people objects that have been hard assigned to the space 
        hard_assigned_peoples = space.people
        
        # loop through each hard assigned people object instance, and assign work effiency, clothing and air velocity schedules if necessary
        hard_assigned_peoples.each do |hard_assigned_people|
        
          if not hard_assigned_people.workEfficiencySchedule.is_initialized
            hard_assigned_people.setWorkEfficiencySchedule(work_efficiency_schedule)
            if verbose_info_statements == true
              runner.registerInfo("Assigning a new work efficiency schedule named #{work_efficiency_schedule.name}, for the hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
            end
          else
            if hard_assigned_people.workEfficiencySchedule.get.to_Schedule.get == work_efficiency_schedule
              if verbose_info_statements == true
                runner.registerInfo("The hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name} already had a work efficiency schedule named #{work_efficiency_schedule.name} assigned to it.")
              end
            else
              old_work_efficiency_schedule = hard_assigned_people.workEfficiencySchedule.get.to_Schedule.get
              hard_assigned_people.setWorkEfficiencySchedule(work_efficiency_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Replacing the work efficiency schedule from #{old_work_efficiency_schedule.name} to #{work_efficiency_schedule.name} for the hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
              end
            end
          end            
      
          if not hard_assigned_people.clothingInsulationSchedule.is_initialized
            hard_assigned_people.setClothingInsulationSchedule(clothing_schedule)
            if verbose_info_statements == true
              runner.registerInfo("Setting the clothing insulation schedule to #{clothing_schedule.name}, for the people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
            end            
          else
            if hard_assigned_people.clothingInsulationSchedule.get.to_Schedule.get == clothing_schedule
              if verbose_info_statements == true
                runner.registerInfo("The hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name} already had a clothing insulation schedule named #{clothing_schedule.name} assigned to it.")
              end
            else
              old_clothing_insulation_schedule = hard_assigned_people.clothingInsulationSchedule.get.to_Schedule.get
              hard_assigned_people.setClothingInsulationSchedule(clothing_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Replacing the clothing insulation schedule from #{old_clothing_insulation_schedule.name} to #{clothing_schedule.name} for the hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
              end
            end
          end            
 
          if not hard_assigned_people.airVelocitySchedule.is_initialized
            hard_assigned_people.setAirVelocitySchedule(air_velocity_schedule)
            if verbose_info_statements == true
              runner.registerInfo("Setting the air velocity schedule to #{air_velocity_schedule.name} for the hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
            end
          else
            if hard_assigned_people.airVelocitySchedule.get.to_Schedule.get == air_velocity_schedule
              if verbose_info_statements == true
                runner.registerInfo("The hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name} already had an air velocity schedule named #{air_velocity_schedule.name} assigned to it.")
              end
            else
              old_air_velocity_schedule = hard_assigned_people.airVelocitySchedule.get.to_Schedule.get
              hard_assigned_people.setAirVelocitySchedule(air_velocity_schedule)
              if verbose_info_statements == true
                runner.registerInfo("Replacing the clothing insulation schedule from #{old_air_velocity_schedule.name} to #{air_velocity_schedule.name} for the hard assigned people object named #{hard_assigned_people.name} attached to the space named #{space.name}.")
              end
            end
          end            
          
          # get hard assignef people definition objects associated with each hard assigned people object
          hard_assigned_people_defs = hard_assigned_people.PeopleDefinitions
            
          # loop through people definitions and set ASHRAE 55, mean radiant and thermal comfort calc flags
          hard_assigned_people_defs.sort.each do |hard_assigned_people_def|
            
            next if hard_assigned_people_def.instances.size <= 0
          
            if hard_assigned_people_def.enableASHRAE55ComfortWarnings != comfortWarnings
              hard_assigned_people_def.setEnableASHRAE55ComfortWarnings(comfortWarnings)
              if verbose_info_statements == true
                runner.registerInfo("Altering #{hard_assigned_people_def.name} to enable ASHRAE55 Comfort Warnings.")
              end
            else
              if verbose_info_statements == true
                runner.registerInfo("No change made to the setting for enabling ASHRAE55 Comfort Warnings for hard assigned people definition object named  #{hard_assigned_people_def.name}, already set to #{comfortWarnings}.")
              end
            end            
          
            if hard_assigned_people_def.meanRadiantTemperatureCalculationType.to_s != meanRadiantCalcType
              hard_assigned_people_def.setMeanRadiantTemperatureCalculationType(meanRadiantCalcType)
              if verbose_info_statements == true
                runner.registerInfo("Altering #{hard_assigned_people_def.name} to set mean radiant temeperature calcs to #{meanRadiantCalcType}.")
              end
            else
              if verbose_info_statements == true
                runner.registerInfo("No change made to the setting for mean radiant temperature calcs for #{hard_assigned_people_def.name} people definition object, already set to '#{meanRadiantCalcType}'.")
              end
            end            
          
            hard_assigned_people_def.setThermalComfortModelType(0, 'Fanger')
            if verbose_info_statements == true
              runner.registerInfo("Altering #{hard_assigned_people_def.name} for the to set Thermal Comfort Model Type to 'Fanger'.")
            end
          end # end loop through hard assigned people defs
        
        end # end loop through hard assigned people instances
      
      end # end loop through spaces belonging to the zone
   
      # create new E+ OutputVariable object to map to EMS Sensor
      sensor_var_output_variable = OpenStudio::Model::OutputVariable.new("Zone Thermal Comfort Fanger Model PMV", model)
      sensor_var_output_variable.setName("Zone Thermal Comfort Fanger Model PMV")
      sensor_var_output_variable.setKeyValue("#{zone.name}")
      sensor_var_output_variable.setReportingFrequency("Timestep")
      if verbose_info_statements == true
        runner.registerInfo("Adding E+ output variable with a key value of '#{zone.name}' to .rdd file for '#{counter} Running #{pmv_trend_length} Hour Average PMV' reporting at each timestep.")
      end      
   
      # create new EnergyManagementSystem:Sensor object representing the Zone Thermal Comfort Fanger Model PMV value
      ems_zone_thermal_comfort_fanger_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, sensor_var_output_variable)
      ems_zone_thermal_comfort_fanger_sensor.setName("PMV#{counter}")
      ems_zone_thermal_comfort_fanger_sensor.setKeyName(zone.name.to_s)
      ems_zone_thermal_comfort_fanger_sensor.setOutputVariable(sensor_var_output_variable)
      if verbose_info_statements == true
        runner.registerInfo("EMS Sensor object named #{ems_zone_thermal_comfort_fanger_sensor.name} added to represent the 'Zone Thermal Comfort Fanger Model PMV' for the thermal zone named #{zone.name}.")
      end
      
      # create new EnergyManagementSystem:TrendVariable object representing the PMV trend log for the Thermal Zone, rounding to an integer
      ems_zone_PMV_trend_var = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, ems_zone_thermal_comfort_fanger_sensor)
      ems_zone_PMV_trend_var.setName("PMVtrendLog#{counter}")
      ems_zone_PMV_trend_var.setNumberOfTimestepsToBeLogged(trend_timesteps)
      if verbose_info_statements == true
        runner.registerInfo("EMS Trend Variable object named #{ems_zone_PMV_trend_var.name} added to represent running #{trend_timesteps} timestep average of 'Zone Thermal Comfort Fanger Model PMV' for the thermal zone named #{zone.name}.")
      end
      
      # create new EnergyManagementSystem:GlobalVariable object and configure to hold the Fanger PMV running average for the zone
      ems_pmv_running_avg_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "PMV#{counter}runningAvg")
      if verbose_info_statements == true
        runner.registerInfo("EMS Global Variable object named #{ems_pmv_running_avg_gv.name} added to represent the represent running average of 'Zone Thermal Comfort Fanger Model PMV' for the thermal zone named #{zone.name}.")
      end
      
      # Create new EnergyManagementSystem:Subroutine object calling @FatalHaltEP function if applicable
      ems_kill_run_subroutine = OpenStudio::Model::EnergyManagementSystemSubroutine.new(model)
      ems_kill_run_subroutine.setName("a_#{counter}_Kill_Run_if_Uncomfortable")
      ems_kill_run_subroutine.addLine("IF PMV#{counter}runningAvg >= #{max_pmv_thresh}")
      ems_kill_run_subroutine.addLine("SET tmpError = @FatalHaltEp #{counter}100#{max_pmv_thresh}")
      ems_kill_run_subroutine.addLine("ENDIF")
      ems_kill_run_subroutine.addLine("IF PMV#{counter}runningAvg <= 0 - #{min_pmv_thresh}")
      ems_kill_run_subroutine.addLine("SET tmpError = @FatalHaltEp #{counter}900#{min_pmv_thresh}")
      ems_kill_run_subroutine.addLine("ENDIF")
      if verbose_info_statements == true
        runner.registerInfo("EMS Subroutine object named '#{ems_kill_run_subroutine.name}' added to determine of E+ calculation should be halted, comparing the user defined upper and lower limits of PMV to the trended PMV value fro thermal zone named #{zone.name}.")
      end
      
      # Create new EnergyManagementSystem:Program object calling the zone PMV trend variable logic
      ems_update_average_PMV_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      ems_update_average_PMV_program.setName("updateMy_averagePMV#{counter}")
      ems_update_average_PMV_program.addLine("SET PMV#{counter}runningAvg = @TrendAverage #{ems_zone_PMV_trend_var.name} #{trend_timesteps}")
      ems_update_average_PMV_program.addLine("RUN a_#{counter}_Kill_Run_if_Uncomfortable")
      if verbose_info_statements == true
        runner.registerInfo("EMS Program object named #{ems_update_average_PMV_program.name} added to evaluate the PMV trend variable.")
      end
      
      # create new EnergyManagementSystem:ProgramCallingManager object and configure to call AverageZoneTemps EMS Program
      program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      program_calling_manager.setName("Average Zone #{counter} PMV")
      program_calling_manager.setCallingPoint("EndOfZoneTimestepBeforeZoneReporting")
      program_calling_manager.addProgram(ems_update_average_PMV_program)
      if verbose_info_statements == true
        runner.registerInfo("EMS Program Calling Manager object named #{program_calling_manager.name} added to call the PMV trend variable calculation of the thermal zone named #{zone.name}, at the end of the zone timestep, before zone reporting.") 
      end
      
      # create new EnergyManagementSystem:OutputVariable object and configure it to hold the zone PMV trend average value global variable 
      ems_pmv_running_average_ov = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, ems_zone_PMV_trend_var)
      ems_pmv_running_average_ov.setName("a_#{counter} Running #{pmv_trend_length} Hour Average PMV") 
      ems_pmv_running_average_ov.setEMSVariableName("#{ems_pmv_running_avg_gv.name}")
      ems_pmv_running_average_ov.setUnits("PMVunits")
      ems_pmv_running_average_ov.setTypeOfDataInVariable("Averaged")
	  ems_pmv_running_average_ov.setUpdateFrequency("ZoneTimeStep")    
      if verbose_info_statements == true
        runner.registerInfo("EMS Output Variable object named #{ems_pmv_running_average_ov.name} added to provide the averaged, zone timestep value of the PMV trend variable for the thermal zone named #{zone.name}.") 
      end
      
    end # end loop through selected zones
    
    # create unique object for OutputEnergyManagementSystem object and configure to allow EMS reporting
    outputEMS = model.getOutputEnergyManagementSystem
    outputEMS.setInternalVariableAvailabilityDictionaryReporting("internal_VariableAvailabilityDictionaryReporting")
    outputEMS.setEMSRuntimeLanguageDebugOutputLevel("ems_RuntimeLanguageDebugOutputLevel")
    outputEMS.setActuatorAvailabilityDictionaryReporting("actuator_AvailabilityDictionaryReporting")
     
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    return true

  end # end run method
  
end # end class

# register the measure to be used by the application
M4Example4HaltProgramBasedOnConstraint.new.registerWithApplication
