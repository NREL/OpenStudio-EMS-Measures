require 'c:/openstudio-2.5.1/Ruby/openstudio.rb'
translator = OpenStudio::OSVersion::VersionTranslator.new
path = OpenStudio::Path.new("F:/NREL EMS MEASURES/m_13_example_13_working_surface_construction_actuator_for_thermochoromic_window/tests/small_office_Chicago_2004_test.osm")
model = translator.loadModel(path)
model = model.get
