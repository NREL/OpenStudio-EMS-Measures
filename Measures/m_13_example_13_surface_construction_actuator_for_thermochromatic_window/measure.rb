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
class M13Example13SurfaceConstructionActuatorForThermochromaticWindow < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "M13 Example 13, Surface Construction Actuator for Thermochromatic Window"
  end
  
  # human readable description
  def description
    return "This measure will replicate the functionality described in the EnergyPlus v8.9.0 Energy Management System Application Guide, Example 13, based on user input. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will demonstrate how an OpenStudio measure calling EMS functions can be used to investigate dynamic envelope technologies such as emulating thermochromic window performance using EMS actuators and control types.  This measure will replace the construction description of a user-selected window based on the outside surface temperature of that window, evaluated at each timestep"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # Add a check box for specifying verbose info statements
	verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
	verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
	verbose_info_statements.setDefaultValue(false)
	args << verbose_info_statements

    # 1) Choice List of a FixedWindow subsurface to apply a thermochromic window construction to 
    fixed_window_subsurface_handles = OpenStudio::StringVector.new
    fixed_window_subsurface_display_names = OpenStudio::StringVector.new
    subsurface_array = []
    
    # put all model subsurfaces and names into arrays
    model.getSurfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        subsurface_array << sub_surface
      end
    end
    
    subsurface_array.each do |subsurface|
      if subsurface.subSurfaceType == "FixedWindow"
        fixed_window_subsurface_handles << subsurface.handle.to_s
        fixed_window_subsurface_display_names << subsurface.name.to_s
      end
    end
    
    
    # make a choice argument for a subsurface of type FixedWindow
    fixed_window_subsurface = OpenStudio::Measure::OSArgument.makeChoiceArgument('fixed_window_subsurface', fixed_window_subsurface_handles, fixed_window_subsurface_display_names, true)
    fixed_window_subsurface.setDisplayName('Choose a Fixed Window Subsurface to Replace with an EMS generated thermochromic window construction.')
    fixed_window_subsurface.setDefaultValue('Perimeter_ZN_1_wall_south_Window_1')
    args << fixed_window_subsurface    

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
    fixed_window_subsurface = runner.getOptionalWorkspaceObjectChoiceValue('fixed_window_subsurface', user_arguments, model) # model is passed in because of argument type
    internal_variable_availability_dictionary_reporting = runner.getStringArgumentValue('internal_variable_availability_dictionary_reporting', user_arguments)
    ems_runtime_language_debug_output_level = runner.getStringArgumentValue('ems_runtime_language_debug_output_level', user_arguments) 
    actuator_availability_dictionary_reporting = runner.getStringArgumentValue('actuator_availability_dictionary_reporting', user_arguments) 
  
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
  
    # declare arrys for scope
    array_of_21_sets = []
    material_property_glazing_spectral_data_vector = []
    standard_glazing_layer_array = []
    construction_array = []
    ems_window_construction_array = []
    
    # load idf into workspace
    workspace = OpenStudio::Workspace::load(OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/EMSThermochromicWindow.idf")).get
    
    # get all MaterialPropertyGlazingSpectralData objects from within the idf
    # material_property_glazing_spectral_datas = source_idf.getObjectsByType("MaterialProperty:GlazingSpectralData".to_IddObjectType)
    material_property_glazing_spectral_datas = workspace.getObjectsByType("MaterialProperty:GlazingSpectralData".to_IddObjectType)
    if verbose_info_statements == true
      runner.registerInfo("The model has #{material_property_glazing_spectral_datas.size} material_property_glazing_spectral_datas objects.")
    end
    
    material_property_glazing_spectral_datas.each do |material_property_glazing_spectral_data|
    
      spectral_data = {"name" => "","properties" => []}
      spectral_data["name"] = material_property_glazing_spectral_data.getString(0).to_s
      
      # Note: EnergyPlus file MaterialProperty:GlazingSpectralData objects have 1764 /4 = 441 sets of 4 values each  
      n = material_property_glazing_spectral_data.numFields
      (1..n).each do |i| 
        spectral_data["properties"] << material_property_glazing_spectral_data.getString(i).to_s 
      end
      array_of_21_sets << spectral_data
    end
    
    array_of_21_sets.each do |set|
    
      props = set["properties"]
      material_property_glazing_spectral_data = OpenStudio::Model::MaterialPropertyGlazingSpectralData.new(model)
      material_property_glazing_spectral_data.setName("#{set["name"]}")
        
      k = (props.length / 4) - 1
      (0..k).each do |i| # note 440 uniques (a, b, c, d) pairs of attributes for each spectral data field object
        material_property_glazing_spectral_data.addSpectralDataField(props[(i*4)+0].to_f, props[(i*4)+1].to_f, props[(i*4)+2].to_f, props[(i*4)+3].to_f)	
      end
      
      material_property_glazing_spectral_data_vector << material_property_glazing_spectral_data
    end 
    
    # create (2) required new air gas materials to used by all EMS window constructions 
    air_gas_3mm_material = OpenStudio::Model::Gas.new(model, "Air", 0.003) 
    air_gas_3mm_material.setName("AIR 3MM")
    
    air_gas_8mm_material = OpenStudio::Model::Gas.new(model, "Air", 0.008)  
    air_gas_8mm_material.setName("AIR 8MM")
    
    # loop through array of OS MaterialPropertyGlazingSpectralData objects and create 21 new Standard Glazing objects 
    material_property_glazing_spectral_data_vector.each do |spec_data_obj|
      spec_data_obj_name = spec_data_obj.name
      layer_name = spec_data_obj_name.to_s.slice("sp")
      if ((spec_data_obj_name == "WO18RT25SP") || (spec_data_obj_name == "Clear3PPGSP"))
        layer = OpenStudio::Model::StandardGlazing.new(model, 'Spectral', 0.0075)
      else
        layer = OpenStudio::Model::StandardGlazing.new(model, 'Spectral', 0.003276)
      end
      layer.setName("#{layer_name}")
      layer.setWindowGlassSpectralDataSet(spec_data_obj)
      layer.setInfraredTransmittanceatNormalIncidence(0)                # same for all 21 constructions
      layer.setFrontSideInfraredHemisphericalEmissivity(0.84)           # same for all 21 constructions
      layer.setBackSideInfraredHemisphericalEmissivity(0.84)            # same for all 21 constructions
      if ((spec_data_obj_name == "WO18RT25SP") || (spec_data_obj_name == "Clear3PPGSP"))
        layer.setConductivity(1.0)  
      else
        layer.setConductivity(0.6)  
      end
      layer.setDirtCorrectionFactorforSolarandVisibleTransmittance(1)   # same for all 21 constructions
      layer.setSolarDiffusing(false)
      standard_glazing_layer_array << layer
    end

    # Create (2) unique standard glazing layers not used for Thermochromatic performance 
    sb60_clear_3_ppg_layer = standard_glazing_layer_array[0]
    clear_3ppg_layer = standard_glazing_layer_array[1]
    remaining_standard_glazing_layer_array = standard_glazing_layer_array.drop(2)
    
    # create (19) new arrays of layered constructions representing thermochromatic layers
    remaining_standard_glazing_layer_array.each do |remaining_standard_glazing_layer|
      construction = [sb60_clear_3_ppg_layer, air_gas_3mm_material, remaining_standard_glazing_layer, air_gas_8mm_material, sb60_clear_3_ppg_layer]
      construction_array << construction
    end
    
    # create 19 new OS:Construction objects representing EMS thermochromatic windows
    name_index_array = [25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 50, 55, 60, 65, 70, 75, 80, 85]
    index = 0
    
    construction_array.each do |const|
      ems_window_construction = OpenStudio::Model::Construction.new(const)
      ems_window_construction.setName("TCwindow_#{name_index_array[index]}")
      if verbose_info_statements == true
        runner.registerInfo("Created a new Construction named #{ems_window_construction.name} representing a thermochromatic window construction.")
      end
      ems_window_construction_array << ems_window_construction
      index +=1
    end

    # check the user argument of the fixed window subsurface for reasonableness
    if fixed_window_subsurface.empty?
      handle = runner.getStringArgumentValue('fixed_window_subsurface', user_arguments)
      if handle.empty?
        runner.registerError('No fixed window subsurface was chosen.')
      else
        runner.registerError("The selected fixed window subsurface with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !fixed_window_subsurface.get.to_SubSurface.empty?
        fixed_window_subsurface = fixed_window_subsurface.get.to_SubSurface.get
      else
        runner.registerError('Script Error - argument not showing up as construction.')
        return false
      end
    end
    
    # Create a new EnergyManagementSystem:Sensor object representing the Surface Outside Face temp of the EMS thermochromatic window subsurface
    ems_win_Tout_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Surface Outside Face Temperature")
    ems_win_Tout_sensor.setName("Win1_Tout")
    ems_win_Tout_sensor.setKeyName("#{fixed_window_subsurface.name}")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Sensor object named '#{ems_win_Tout_sensor.name}' representing the Surface Outside Face temp of the EMS thermochromatic window subsurface was added to the model.") 
    end
    
    # Create a new EMS Actuator Object representing the construction state of the EMS generated thermochromatic window 
    ems_win_construct_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(fixed_window_subsurface, "Surface", "Construction State")
    ems_win_construct_actuator.setName("Win1_Construct")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Actuator object named '#{ems_win_construct_actuator.name}' representing construction state of the EMS generated thermochromatic window was added to the model.") 
    end
    
    # Create 19 EnergyManagementSystem:ConstructionIndexVariable objects for each unique thermochromatic construction
    ems_window_construction_array.each do |ems_window_construction|
      ems_constr_index_var = OpenStudio::Model::EnergyManagementSystemConstructionIndexVariable.new(model, ems_window_construction )   
      ems_constr_index_var.setName("#{ems_window_construction.name}")
      if verbose_info_statements == true
        runner.registerInfo("An EMS SystemConstructionIndexVariable object named '#{ems_constr_index_var.name}' representing the the EMS construction state of the thermochromatic window was added to the model.") 
      end
    end
 
    # Create new EnergyManagementSystem:Program object for assigning different window constructions by dynamically evaluating the exterior surface temp of the fixed window subsurface 
    ems_apply_thermochromatic_constructions_prgm = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_apply_thermochromatic_constructions_prgm.setName("#{fixed_window_subsurface.name}_Control")
    ems_apply_thermochromatic_constructions_prgm.addLine("IF #{ems_win_Tout_sensor.name} <= 26.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_25")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 28.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_27")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 30.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_29")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 32.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_31")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 34.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_33")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 36.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_35")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 38.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_37")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 40.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_39")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 42.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_41")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 44.0")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_43")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 47.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_45")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 52.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_50")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 57.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_55")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 62.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_60")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 67.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_65")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 72.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_70")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 77.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_75")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSEIF #{ems_win_Tout_sensor.name} <= 82.5")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_80")
    ems_apply_thermochromatic_constructions_prgm.addLine("ELSE")
    ems_apply_thermochromatic_constructions_prgm.addLine("SET #{ems_win_construct_actuator.name} = TCwindow_85")
    ems_apply_thermochromatic_constructions_prgm.addLine("ENDIF")
    if verbose_info_statements == true
      runner.registerInfo("An EMS Program Object named '#{ems_apply_thermochromatic_constructions_prgm.name}' for dynamically assigning different window constructions based on the exterior surface temp was added to the model.") 
    end
    
    # Create a new EnergyManagementSystem:ProgramCallingManager object configured to call the EMS programs
    ems_prgm_calling_mngr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_prgm_calling_mngr.setName("My thermochromic window emulator")
    ems_prgm_calling_mngr.setCallingPoint("BeginTimestepBeforePredictor")
    ems_prgm_calling_mngr.addProgram(ems_apply_thermochromatic_constructions_prgm)
    if verbose_info_statements == true
      runner.registerInfo("EMS Program Calling Manager object named '#{ems_prgm_calling_mngr.name}' added to call EMS program for dynamically applying a thermochromatic window.") 
    end
    
    # create unique object for OutputEnergyManagementSystems and configure to allow EMS reporting
    outputEMS = model.getOutputEnergyManagementSystem
    outputEMS.setInternalVariableAvailabilityDictionaryReporting("internal_variable_availability_dictionary_reporting")
    outputEMS.setEMSRuntimeLanguageDebugOutputLevel("ems_runtime_language_debug_output_level")
    outputEMS.setActuatorAvailabilityDictionaryReporting("actuator_availability_dictionary_reporting")
    if verbose_info_statements == true
      runner.registerInfo("EMS OutputEnergyManagementSystem object configured per user arguments.") 
    end
    
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")

  end # end run method
  
end # end class

# register the measure to be used by the application
M13Example13SurfaceConstructionActuatorForThermochromaticWindow.new.registerWithApplication

