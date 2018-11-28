## OpenStudio-EMS-Measures

## Background

PSD (www.psdconsulting.com) has developed, tested and documented a set of OpenStudio measures which demonstrate the use of EnergyPlus Energy Management System (EMS) objects via OpenStudio API calls. The measures were developed and tested using OpenStudio v2.6.0. 
The work product includes 11 separate and complete OpenStudio measures, defined on pages 63 – 113 of EnergyPlus v8.9.0 Documentation: “Application Guide for EMS”.
*	m_1_example_1_whole_building_average_zone_air_temperature
*	m_2_example_2_traditional_setpoint_and_availability_managers
*	m_4_example_4_halt_program_based_on_constraint
*	m_5_example_5_computed_schedule
*	m_7_example_7_constant_volume_purchased_air_system
*	m_8_example_8_system_sizing_with_discrete_package_sizes
*	m_9_example_9_demand_management
*	m_10_example_10_plant_loop_override_control
*	m_11_example_11_performance_curve_result_override
*	m_12_example_12_variable_refrigerant_flow_system_override
*	m_13_example_13_surface_construction_actuator_for_thermochromatic_window

Two of the thirteen EnergyPlus example EMS measures (Example 3 and Example 6) described in the EMS Applications Guide were unable to be translated into the OpenStudio environment due to limitations in the OS v2.6.0 API.

## Organization

Each of the 11 OpenStudio EMS measures includes a subfolder named ‘tests’, which includes a subfolder containing an example EnergyPlus EMS .idf file from EnergyPlus v8.9.0. Each tests folder also includes an OpenStudio file titled ‘m[x]_seed.osm’. The OpenStudio EMS measures have been developed and tested to run against this file. The OpenStudio file named ‘m[x]_w_EMS.osm’ is the result of applying the measures to the seed model, using the OpenStudio Application “Apply Measure Now” feature.  
