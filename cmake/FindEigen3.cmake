find_package(Eigen3 CONFIG)
mark_as_advanced(FORCE Eigen3_DIR)

if(Eigen3_FOUND)
  if(NOT EIGEN3_INCLUDE_DIRS)
    if(DEFINED Eigen3_INCLUDE_DIRS)
      set(EIGEN3_INCLUDE_DIRS "${Eigen3_INCLUDE_DIRS}")
    elseif(TARGET Eigen3::Eigen)
      get_target_property(_eigen_inc Eigen3::Eigen INTERFACE_INCLUDE_DIRECTORIES)
      if(_eigen_inc)
        set(EIGEN3_INCLUDE_DIRS "${_eigen_inc}")
      endif()
    endif()
  endif()
  if(NOT EIGEN3_DEFINITIONS AND DEFINED Eigen3_DEFINITIONS)
    set(EIGEN3_DEFINITIONS "${Eigen3_DEFINITIONS}")
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Eigen3
  FOUND_VAR Eigen3_FOUND
  REQUIRED_VARS EIGEN3_INCLUDE_DIRS
)

if(NOT TARGET Eigen3::Eigen3)
  if(TARGET Eigen3::Eigen)
    add_library(Eigen3::Eigen3 INTERFACE IMPORTED)
    set_target_properties(Eigen3::Eigen3 PROPERTIES
      INTERFACE_LINK_LIBRARIES Eigen3::Eigen
    )
  else()
    add_library(Eigen3::Eigen3 INTERFACE IMPORTED)
    set_target_properties(Eigen3::Eigen3 PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${EIGEN3_INCLUDE_DIRS}"
      INTERFACE_COMPILE_DEFINITIONS "${EIGEN3_DEFINITIONS}"
    )
  endif()
endif()
