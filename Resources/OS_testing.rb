
#ruby command line
#irb -I 'C:/openstudio-2.3.0/Ruby'
irb -I 'C:/openstudio-2.5.1/Ruby'
require 'openstudio'
translator = OpenStudio::OSVersion::VersionTranslator.new
path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Large_Office_90_1_2004_Chicago.osm")
path_new = OpenStudio::Path.new(File.dirname(__FILE__) + "/NEW_Large_Office_90_1_2004_Chicago.osm")
path_save = OpenStudio::Path.new(File.dirname(__FILE__) + "/Large_Office_90_1_2004_Chicago.idf")
#sqlFile = OpenStudio::Path.new(File.dirname(__FILE__) + "/eplusout.sql")
model = translator.loadModel(path)
model = model.get

all_lights = model.getLightss
#get the office lights not datacenter (check 2 is right)
lights = all_lights[2]

space_types = model.getSpaceTypes
spaces = model.getSpaces

space_type = space_types[0]
space = spaces[1]  #core_mid
emsActuator = OpenStudio::Model::EnergyManagementSystemActuator.new(lights ,'Lights','Electric Power Level')

#get spaceType from SpaceLoad (lights)
lights.spaceType.get

#loop thru spaces to match spaceType
#get spaceType from space
same_lights = []
spaces.each do |space|
  if (space.spaceType)
    if (space.spaceType.get.handle == lights.spaceType.get.handle)
      same_lights << space
    end
  end  
end

#then each space you can get thermalZone name
names = []
same_lights.each do |space|
  if (space.thermalZone)
    names << space.thermalZone.get.name.to_s
  end
end

model.save(path_new, true)
ft = OpenStudio::EnergyPlus::ForwardTranslator.new
workspace = ft.translateModel(model)
workspace.save(path_save, true)

OS:SpaceType,
  {98909233-b914-45a9-87f6-fbca4205305a}, !- Handle
  Office WholeBuilding - Lg Office,       !- Name
  ,                                       !- Default Construction Set Name
  {98276ee1-880a-4e79-9998-f278847f8d52}, !- Default Schedule Set Name
  {ce06028a-8961-4347-8df4-200443825cb7}, !- Group Rendering Name
  {751be405-7ca8-40db-8c83-e32723318e26}, !- Design Specification Outdoor Air Object Name
  Office,                                 !- Standards Building Type
  WholeBuilding - Lg Office;              !- Standards Space Type

OS:Lights,
  {a4621c7c-65d1-494a-bae1-93bf47868513}, !- Handle
  Office WholeBuilding - Lg Office Lights, !- Name
  {9017f4c8-70ad-461a-ba4d-a4c5d52490e5}, !- Lights Definition Name
  {98909233-b914-45a9-87f6-fbca4205305a}, !- Space or SpaceType Name
  ,                                       !- Schedule Name
  1,                                      !- Fraction Replaceable
  ,                                       !- Multiplier
  General;                                !- End-Use Subcategory
  
OS:EnergyManagementSystem:Actuator,
 {6cc2d3f2-fb5b-46b5-be22-fce35b05f250}, !- Handle
 Energy_Management_System_Actuator_1,    !- Name
 {a4621c7c-65d1-494a-bae1-93bf47868513}, !- Actuated Component Name
 Lights,                                 !- Actuated Component Type
 Electric Power Level;                   !- Actuated Component Control Type


#lights name
OFFICE WHOLEBUILDING - LG OFFICE LIGHTS

#EDD file for actators for this lights OS:Lights spaceloadinstance
EnergyManagementSystem:Actuator Available,BASEMENT ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,CORE_BOTTOM ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,CORE_MID ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,CORE_TOP ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_BOT_ZN_1 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_BOT_ZN_2 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_BOT_ZN_3 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_BOT_ZN_4 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_MID_ZN_1 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_MID_ZN_2 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_MID_ZN_3 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_MID_ZN_4 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_TOP_ZN_1 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_TOP_ZN_2 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_TOP_ZN_3 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]
EnergyManagementSystem:Actuator Available,PERIMETER_TOP_ZN_4 ZN OFFICE WHOLEBUILDING - LG OFFICE LIGHTS,Lights,Electric Power Level,[W]