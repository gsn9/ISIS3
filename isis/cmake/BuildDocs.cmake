#==============================================================================
# File for building the ISIS documentation.
# - This is one of the most complicated parts of the build system!
#   It makes heavy use of the Xalan XML tool and also requires Latex and Doxygen.
# - This file is called as a stand-alone script when "make docs" is executed.
#==============================================================================


cmake_minimum_required(VERSION 3.3)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_PREFIX_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Utilities)

# Set up Xalan's command-line option names.
set(XALAN_VALIDATE_OPTION "-v")
set(XALAN_OUTFILE_OPTION  "-o")
set(XALAN_PARAM_OPTION    "-p")
set(XALAN_INFILE_OPTION   ""  )
set(XALAN_XSL_OPTION      ""  )

# TODO: How should this be set?
set(MODE "")


#------------------------------------------------------------------------


# Populate application doc files into "isis/doc/Application/presentation"
function(copy_app_docs_info)

  # Go through all application folders, copy .xml and assets
  get_subdirectory_list("${PROJECT_SOURCE_DIR}/src" moduleFolders)
  foreach(f ${moduleFolders})
    get_filename_component(moduleName ${f} NAME_WE)

    # Only need to process app folders, not obj folders.
    if ((${moduleName} STREQUAL "docsys") OR (NOT EXISTS "${f}/apps"))
      continue() # Skip this folder
    endif()

    file(MAKE_DIRECTORY ${appDataFolder}/${moduleName})

    get_subdirectory_list(${f}/apps appFolders)
    foreach(appF ${appFolders})
      # Each app gets its own folder in the build directory
      get_filename_component(appName ${appF} NAME_WE)
      set(thisDataFolder ${appDataFolder}/${moduleName}/${appName})
      file(MAKE_DIRECTORY ${thisDataFolder})

      # Copy the .xml file and the asset folder if it exists.
      copy_file(${appF}/${appName}.xml ${thisDataFolder}/${appName}.xml)
      if(EXISTS ${appF}/assets)
        copy_folder(${appF}/assets ${thisDataFolder})
      endif()
    endforeach() # End loop through apps

  endforeach() # End loop through modules

endfunction(copy_app_docs_info)





# Build the top level of the documents directory
function(build_upper_level)

  # Make new (empty) output folders
  set(newFolders UserStart UserLearn UserExplore UserInspire
                 DevStart  DevLearn  DevExplore  DevInspire
                 UserDocs General Guides Installation TechnicalInfo)
  foreach(f ${newFolders})
    file(MAKE_DIRECTORY "${docInstallFolder}/${docVersion}/${f}")
  endforeach()

  # Copy the assets folder to the specific version directory
  copy_folder(${docBuildFolder}/assets ${docInstallFolder}/${docVersion})
  # Also copy the assest folder to the base area so the base index.html can use it
  # TODO - eliminate this copy of assest by having a simple top index.html that redirects to the vx.y.z/index.html. The top index should contain html base so it uses vx.y.z assets
  copy_folder(${docBuildFolder}/assets ${docInstallFolder})

  # Copy other folders to the specific version directory
  copy_folder(${docBuildFolder}/w3c    ${docInstallFolder}/${docVersion})

  # These folders are populated inside "build_documents_folder"

  # Create a redirect for the top level index file. It points to the version index file
  execute_process(COMMAND ${XALAN} ${XALAN_VALIDATE_OPTION} ${XALAN_PARAM_OPTION} menuPath \"${docVersion}/\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/index.html ${XALAN_INFILE_OPTION} ${docBuildFolder}/build/redirect.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/redirect.xsl)
  # Create the main documentaion page. This is located in the version directory 
  execute_process(COMMAND ${XALAN} ${XALAN_VALIDATE_OPTION} ${XALAN_PARAM_OPTION} menuPath \"\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/index.html ${XALAN_INFILE_OPTION} ${docBuildFolder}/build/homepage.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/main.xsl)

 # This folder just gets copied as-is
 # Note: Schemas are referenced inside the application xml files. The schema URI inside the xmls do not have version numbers in the path 
 execute_process(COMMAND cp -r ${PROJECT_SOURCE_DIR}/src/docsys/Schemas  ${docInstallFolder}/Schemas)

endfunction(build_upper_level)





# Build src/docsys/documents folder.
function(build_documents_folder)

  message("Building documents folder...")
  message("    Building table of contents XML...")

  # Create RealeaseNotes.xml, ApiChanges.xml and ParameterChanges.xml if need-be
  if(EXISTS "${docBuildFolder}/documents/ReleaseNotes/ReleaseNotesList.xml")
    execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} dirParam \"ReleaseNotes\" ${XALAN_INFILE_OPTION} ${docBuildFolder}/documents/ReleaseNotes/ReleaseNotesList.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/ReleaseNotes.xsl OUTPUT_FILE ${docBuildFolder}/documents/ReleaseNotes/ReleaseNotes.xml)
    execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} dirParam \"ParameterChanges\" ${XALAN_INFILE_OPTION} ${docBuildFolder}/documents/ReleaseNotes/ReleaseNotesList.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/ParameterChanges.xsl OUTPUT_FILE ${docBuildFolder}/documents/ParameterChanges/ParameterChanges.xml)
    execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} dirParam \"ApiChanges\" ${XALAN_INFILE_OPTION} ${docBuildFolder}/documents/ReleaseNotes/ReleaseNotesList.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/ApiChanges.xsl OUTPUT_FILE ${docBuildFolder}/documents/ApiChanges/ApiChanges.xml)
  else()
    # Confirm that empty directories are not going to be traversed in loops coming up
    message("    ReleaseNotesList.xml does not exist. Removing ReleaseNotes/ ParameterChanges/ and ApiChanges/ directories...")
    execute_process(COMMAND rm -rf ${docBuildFolder}/documents/ReleaseNotes ${docBuildFolder}/documents/ParameterChanges ${docBuildFolder}/documents/ApiChanges)
  endif()

  # Get list of folders of interest
  get_subdirectory_list(${docBuildFolder}/documents docFolders)

  # Build doctoc.xml, the documents table of contents file.
  set(doctocPath ${docBuildFolder}/build/doctoc.xml)
  file(REMOVE ${doctocPath})
  cat(${docBuildFolder}/build/doctoc_header.xml ${doctocPath})
  foreach(f ${docFolders})
    
    # Each folder in documents gets a section added to doctoc
    get_filename_component(docName ${f} NAME_WE)
    
    execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} dirParam \"${docName}\"  ${XALAN_INFILE_OPTION} ${f}/${docName}.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/build/IsisDocumentTOCbuild.xsl OUTPUT_VARIABLE result)
    file(APPEND ${doctocPath} ${result})

  endforeach()
  cat(${docBuildFolder}/build/doctoc_footer.xml ${doctocPath})

  # Write out a modified .xsl file with the correct location of the Xalan executable.
  set(modDocBuildXslFile ${docBuildFolder}/build/IsisInlineDocumentBuild_mod.xsl)
  file(READ ${PROJECT_SOURCE_DIR}/scripts/IsisInlineDocumentBuild_mod.xsl xslContents)
  string(REPLACE XALAN_BIN_LOCATION ${XALAN} xslContents "${xslContents}")
  file(WRITE ${modDocBuildXslFile} "${xslContents}")

  # Build individual documents folders
  message("    Building individual documents...")
  file(MAKE_DIRECTORY ${docInstallFolder}/${docVersion}/documents)
  foreach(f ${docFolders})

    message("Building documents folder: ${f}")

    # Handle paths for this folder
    get_filename_component(docName ${f} NAME_WE)
    set(thisOutputFolder ${docInstallFolder}/${docVersion}/documents/${docName})
    file(MAKE_DIRECTORY ${thisOutputFolder})

    # Use Xalan to generate an intermediate makefile, then execute that makefile
    # to generate the output documentation files.

    set(xalanCommand ${XALAN} ${XALAN_PARAM_OPTION} menuPath "../../" ${XALAN_PARAM_OPTION} dirParam "'${docName}'" ${XALAN_OUTFILE_OPTION} ${f}/Makefile_temp ${XALAN_INFILE_OPTION} ${docName}.xml  ${XALAN_XSL_OPTION} ${modDocBuildXslFile})
    execute_process(COMMAND ${xalanCommand} WORKING_DIRECTORY ${f})

    execute_process(COMMAND make -f Makefile_temp docs WORKING_DIRECTORY ${f})
    execute_process(COMMAND rm -f ${f}/Makefile_temp) # Clean up

    # Copy all generated html files and any assets to the install folder
    file(GLOB htmlFiles ${f}/*.html)
    file(COPY ${htmlFiles} DESTINATION ${thisOutputFolder})
    if(EXISTS "${f}/assets")
      copy_folder(${f}/assets ${thisOutputFolder}/assets)
    endif()
    if(EXISTS "${f}/images")
      copy_folder(${f}/images ${thisOutputFolder}/images)
    endif()

  endforeach()

  message("    Building table of contents files...")
  # These go in top level folders in /doc/

  # GENERAL TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/General/index.html ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/General.xsl)

  # GUIDES TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/Guides/index.html ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/Guides.xsl)

  # INSTALLATION TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/Installation/index.html ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/Installation.xsl)

  # TECHNICAL INFO TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/TechnicalInfo/index.html ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/TechnicalInfo.xsl)

  # USER DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/UserDocs/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/UserDocs.xsl)

  # USER GETTING STARTED DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/UserStart/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/UserStart.xsl)

  # USER LEARN MORE DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/UserLearn/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/UserLearn.xsl)

  # USER EXPLORE IN DETAIL DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/UserExplore/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/UserExplore.xsl)

  # USER GET INSPIRED DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/UserInspire/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/UserInspire.xsl)

  # DEV GETTING STARTED DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/DevStart/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/DevStart.xsl)

  # DEV LEARN MORE DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/DevLearn/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/DevLearn.xsl)

  # DEV EXPLORE IN DETAIL DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/DevExplore/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/DevExplore.xsl)

  # DEV GET INSPIRED DOCS TOC
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${docInstallFolder}/${docVersion}/DevInspire/index.html    ${XALAN_INFILE_OPTION} ${doctocPath} ${XALAN_XSL_OPTION} ${docBuildFolder}/build/DevInspire.xsl)

endfunction(build_documents_folder)





# Supporting files should already be in /src/docsys/Application
function(build_application_docs)

  # Is there any reason not to just generate all these files from their original
  #  locations instead of copying them to a temporary build directory?

  set(appFolder            "${docBuildFolder}/Application")
  set(printerStyleFolder   "${appFolder}/presentation/PrinterFriendly/styles")
  set(tabbedStyleFolder    "${appFolder}/presentation/Tabbed/styles")

  set(installAppFolder     "${docInstallFolder}/${docVersion}/Application")
  set(installPrinterFolder "${installAppFolder}/presentation/PrinterFriendly")
  set(installTabbedFolder  "${installAppFolder}/presentation/Tabbed")

  # Make output directories and copy the styles
  file(MAKE_DIRECTORY "${installPrinterFolder}")
  file(MAKE_DIRECTORY "${installTabbedFolder}")
  file(MAKE_DIRECTORY "${installPrinterFolder}/styles")
  file(MAKE_DIRECTORY "${installTabbedFolder}/styles")
  copy_wildcard("${printerStyleFolder}/*.css" ${installPrinterFolder}/styles/)
  copy_wildcard("${tabbedStyleFolder}/*.css"  ${installTabbedFolder}/styles/ )

  # Loop through module folders
  get_subdirectory_list(${appDataFolder} moduleFolders)
  foreach(mod ${moduleFolders})
    get_filename_component(moduleName ${mod} NAME)

    # Loop through application folders
    get_subdirectory_list(${mod} appDataFolders)
    foreach(f ${appDataFolders})
      get_filename_component(appName ${f} NAME)

      # Get printer-friendly and tabbed output folders
      set(pfAppFolder ${installPrinterFolder}/${appName})
      set(tbAppFolder ${installTabbedFolder}/${appName})
      file(MAKE_DIRECTORY "${pfAppFolder}")
      file(MAKE_DIRECTORY "${tbAppFolder}")

      if(EXISTS ${f}/assets)
        copy_folder(${f}/assets ${pfAppFolder})
        copy_folder(${f}/assets ${tbAppFolder})
      endif()

      execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../../../../\" ${XALAN_OUTFILE_OPTION} ${pfAppFolder}/${appName}.html ${XALAN_INFILE_OPTION} ${f}/${appName}.xml ${XALAN_XSL_OPTION} ${printerStyleFolder}/IsisApplicationDocStyle.xsl)
      execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../../../../\" ${XALAN_OUTFILE_OPTION} ${tbAppFolder}/${appName}.html ${XALAN_INFILE_OPTION} ${f}/${appName}.xml ${XALAN_XSL_OPTION} ${tabbedStyleFolder}/IsisApplicationDocStyle.xsl)

    endforeach() # End loop through app folders

  endforeach() # End loop through module folders

  # Make the table of contents that goes in the /bin/xml folder

  # Set up the file
  set(appTocPath "${CMAKE_INSTALL_PREFIX}/bin/xml/applicationTOC.xml")
  file(REMOVE ${appTocPath})
  cat(${docBuildFolder}/Application/build/toc_header.xml ${appTocPath})
  get_subdirectory_list(${appDataFolder} moduleFolders)

  # Loop through module folders
  foreach(mod ${moduleFolders})
    get_filename_component(moduleName ${mod} NAME_WE)

    # Loop through application folders
    get_subdirectory_list(${mod} appDataFolders)
    foreach(f ${appDataFolders})

      get_filename_component(docName ${f} NAME_WE)

      # Use Xalan to generate a piece of the TOC and append it to the file
      execute_process(COMMAND ${XALAN} ${XALAN_INFILE_OPTION} ${f}/${docName}.xml ${XALAN_XSL_OPTION} ${docBuildFolder}/Application/build/IsisApplicationTOCbuild.xsl  OUTPUT_VARIABLE result)
      file(APPEND ${appTocPath} ${result})
    endforeach()
  endforeach()

  # Append the footer to complete the TOC file!
  cat(${docBuildFolder}/Application/build/toc_footer.xml ${appTocPath})

endfunction(build_application_docs)





# Use the application TOC file to build some other TOCs
function(add_extra_tocs)

  set(TOCDIR      "${docInstallFolder}/${docVersion}/Application")
  set(buildFolder "${docBuildFolder}/Application/build")
  set(tocXml      "${CMAKE_INSTALL_PREFIX}/bin/xml/applicationTOC.xml")

  # Build alpha.html
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${TOCDIR}/alpha.html ${XALAN_INFILE_OPTION} ${tocXml} ${XALAN_XSL_OPTION} ${buildFolder}/TOCindex_alpha.xsl)

  # Build index.html
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${TOCDIR}/index.html ${XALAN_INFILE_OPTION} ${tocXml} ${XALAN_XSL_OPTION} ${buildFolder}/TOCindex_category.xsl)

  # Build oldvnew.html
  execute_process(COMMAND ${XALAN} ${XALAN_PARAM_OPTION} menuPath \"../\" ${XALAN_OUTFILE_OPTION} ${TOCDIR}/oldvnew.html ${XALAN_INFILE_OPTION} ${tocXml} ${XALAN_XSL_OPTION} ${buildFolder}/TOCindex_oldvnew.xsl)

  # Build applicationCategories.xml
  execute_process(COMMAND ${XALAN} ${XALAN_OUTFILE_OPTION} ${CMAKE_INSTALL_PREFIX}/bin/xml/applicationCategories.xml ${XALAN_INFILE_OPTION} ${docBuildFolder}/Schemas/Application/application.xsd ${XALAN_XSL_OPTION} ${buildFolder}/IsisApplicationCategoriesbuild.xsl)

endfunction(add_extra_tocs)





# Set up three Doxygen configuration files
function(build_object_conf)

  message("Building apps configuration...")

  # Make a list of each object folder with an assets folder
  get_subdirectory_list(moduleFolders ${PROJECT_SOURCE_DIR})
  set(OBJECTASSETS)
  foreach(mod ${moduleFolders})
    get_subdirectory_list(objFolders ${mod}/objs)
    foreach(obj ${objFolders})
      if(EXISTS ${obj}/assets)
        set(OBJECTASSETS ${OBJECTASSETS} ${obj}/assets)
      endif()
    endforeach() # End obj loop
  endforeach() # End module loop

  set(objConfDir ${docBuildFolder}/src/docsys/Object/build)
  file(MAKE_DIRECTORY ${objConfDir}/apps)

  # The three conf files start from an input base file and append more options
  set(appsConf       ${objConfDir}/apps_tag_temp.conf  )
  set(programmerConf ${objConfDir}/Programmer_temp.conf)
  set(developerConf  ${objConfDir}/Developer_temp.conf )
  set(docInstallDir  ${docInstallFolder}/${docVersion}/Object )

  # Copy settings files from the source folder to the build folder
  copy_wildcard("${PROJECT_SOURCE_DIR}/src/docsys/Object/build/*" ${objConfDir})

  # Append to the app conf file
  # apps_tag.conf doesnt exist?
  cat(${objConfDir}/apps_tag.conf ${appsConf})
  file(APPEND ${appsConf} "LATEX_CMD_NAME   = ${LATEX}\n")
  file(APPEND ${appsConf} "OUTPUT_DIRECTORY = ${docInstallDir}/${docVersion}\n")
  file(APPEND ${appsConf} "STRIP_FROM_PATH  = ${PROJECT_SOURCE_DIR}/\n")
  file(APPEND ${appsConf} "INPUT            = ${PROJECT_SOURCE_DIR}/src/ ${objConfDir}/isisDoxyDefs.doxydef\n")
  file(APPEND ${appsConf} "HTML_HEADER      = ${objConfDir}/IsisObjectHeader.html\n")
  file(APPEND ${appsConf} "HTML_FOOTER      = ${objConfDir}/IsisObjectFooter.html\n")
  file(APPEND ${appsConf} "PROJECT_LOGO     = ${docBuildFolder}/assets/icons/USGS_logo55h.png\n")
  file(APPEND ${appsConf} "HTML_OUTPUT      = apps\n")

  if(NOT ${DOT_PATH} STREQUAL "")
    file(APPEND ${appsConf} "DOT_PATH  = /opt/local/bin\n")
  endif()

  # Append to the programmer conf file
  cat(${objConfDir}/Programmer.conf ${programmerConf})
  file(APPEND ${programmerConf} "OUTPUT_DIRECTORY = ${docInstallDir}/${docVersion}\n")
  file(APPEND ${programmerConf} "FILE_PATTERNS    = *objs*.h")
  file(APPEND ${programmerConf} " *objs*.cpp")
  file(APPEND ${programmerConf} " *build/isisDoxyDefs.doxydef\n")
  file(APPEND ${programmerConf} "STRIP_FROM_PATH  = ${PROJECT_SOURCE_DIR}/\n")
  file(APPEND ${programmerConf} "INPUT            = ${PROJECT_SOURCE_DIR}/src/ ${objConfDir}/isisDoxyDefs.doxydef\n")
  file(APPEND ${programmerConf} "HTML_HEADER      = ${objConfDir}/IsisObjectHeader.html\n")
  file(APPEND ${programmerConf} "HTML_FOOTER      = ${objConfDir}/IsisObjectFooter.html\n")
  file(APPEND ${programmerConf} "PROJECT_LOGO     = ${docBuildFolder}/assets/icons/USGS_logo55h.png\n")
  file(APPEND ${programmerConf} "HTML_OUTPUT      = Programmer\n")
  file(APPEND ${programmerConf} "IMAGE_PATH       = \n")

  string(FIND "${MODE}" "LOUD" pos)
  if (NOT ${pos} STREQUAL "-1")
    file(APPEND ${programmerConf} "QUIET                  = NO\n")
    file(APPEND ${programmerConf} "WARNINGS               = YES\n")
    file(APPEND ${programmerConf} "WARN_IF_UNDOCUMENTED   = NO\n")
    file(APPEND ${programmerConf} "WARN_IF_DOC_ERROR      = YES\n")
    file(APPEND ${programmerConf} "WARN_NO_PARAMDOC       = YES\n")
  else()
    file(APPEND ${programmerConf} "QUIET                  = YES\n")
    file(APPEND ${programmerConf} "WARN_IF_UNDOCUMENTED   = NO\n")
    file(APPEND ${programmerConf} "WARN_IF_DOC_ERROR      = YES\n")
    file(APPEND ${programmerConf} "WARN_NO_PARAMDOC       = YES\n")
  endif()

  if (NOT ${DOT_PATH} STREQUAL "")
    file(APPEND ${programmerConf} "DOT_PATH  = /opt/local/bin\n")
  endif()

  foreach(dirname ${OBJECTASSETS})
    file(APPEND ${programmerConf} "${dirname} \\\n")
  endforeach()

  # Append to the developer conf file
  cat(${objConfDir}/Developer.conf ${developerConf})
  file(APPEND ${developerConf} "LATEX_CMD_NAME   = ${LATEX}\n")
  file(APPEND ${developerConf} "OUTPUT_DIRECTORY = ${docInstallDir}/${docVersion}\n")
  file(APPEND ${developerConf} "STRIP_FROM_PATH  = ${CMAKE_INSTALL_PREFIX}/\n")
  file(APPEND ${developerConf} "INPUT            = ${PROJECT_SOURCE_DIR}/src/ ${objConfDir}/isisDoxyDefs.doxydef\n")
  file(APPEND ${developerConf} "HTML_HEADER      = ${objConfDir}/IsisObjectHeader.html\n")
  file(APPEND ${developerConf} "HTML_FOOTER      = ${objConfDir}/IsisObjectFooter.html\n")
  file(APPEND ${developerConf} "PROJECT_LOGO     = ${docBuildFolder}/assets/icons/USGS_logo55h.png\n")
  file(APPEND ${developerConf} "HTML_OUTPUT      = Developer\n")
  file(APPEND ${developerConf} "IMAGE_PATH       = \n")
  string(FIND "${MODE}" "LOUD" pos)
  if (NOT ${pos} STREQUAL "-1")
    file(APPEND ${developerConf} "QUIET                  = NO\n")
    file(APPEND ${developerConf} "WARNINGS               = YES\n")
    file(APPEND ${developerConf} "WARN_IF_UNDOCUMENTED   = NO\n")
    file(APPEND ${developerConf} "WARN_IF_DOC_ERROR      = YES\n")
    file(APPEND ${developerConf} "WARN_NO_PARAMDOC       = YES\n")
  else()
    file(APPEND ${developerConf} "QUIET                  = YES\n")
    file(APPEND ${developerConf} "WARNINGS               = NO\n")
    file(APPEND ${developerConf} "WARN_IF_UNDOCUMENTED   = NO\n")
    file(APPEND ${developerConf} "WARN_IF_DOC_ERROR      = NO\n")
    file(APPEND ${developerConf} "WARN_NO_PARAMDOC       = NO\n")
  endif()

  foreach(dirname ${OBJECTASSETS})
    file(APPEND ${developerConf} "${dirname} \\\n")
  endforeach()

endfunction(build_object_conf)




# Build doxygen output for ISIS code
function(build_object_docs)

  # Create app, developer, and programmer Doxygen configuration files.
  build_object_conf()

  # TODO: Do prog_tester conf here as well?

  set(objConfDir  ${docBuildFolder}/src/docsys/Object/build)

  message("Copying object assets...")
  file(MAKE_DIRECTORY "${docInstallFolder}/${docVersion}/Object")
  execute_process(COMMAND cp -r ${docBuildFolder}/Object/assets ${docInstallFolder}/${docVersion}/Object/)


  message("Creating Object Documentation")
  file(MAKE_DIRECTORY ${docInstallFolder}/${docVersion}/Object/apps)
  file(MAKE_DIRECTORY ${docInstallFolder}/${docVersion}/Object/Developer)
  file(MAKE_DIRECTORY ${docInstallFolder}/${docVersion}/Object/Programmer)
  file(MAKE_DIRECTORY ${docInstallFolder}/${docVersion}/documents/DocStyle/assets)
  copy_wildcard("${docBuildFolder}/Object/*.html" ${docInstallFolder}/${docVersion}/Object/)
  #copy_file(${objBuildDir}/isisDoxyDefs.doxydef ${docInstallFolder}/documents/DocStyle/assets/isisDoxyDefs.doxydef)


  message("Building Apps documentation..")
  execute_process(COMMAND ${DOXYGEN} "${objConfDir}/apps_tag_temp.conf"
                  WORKING_DIRECTORY ${docBuildFolder}/src/docsys/Object/)
  message("Finished building Apps documentation.")

  message("Building Programmer documentation...")
  execute_process(COMMAND ${DOXYGEN} "${objConfDir}/Programmer_temp.conf"
                  WORKING_DIRECTORY ${docBuildFolder}/src/docsys/Object/)
  message("Finished building Programmer documentation.")

  message("Building Developer documentation...")
  execute_process(COMMAND ${DOXYGEN} "${objConfDir}/Developer_temp.conf"
                  WORKING_DIRECTORY ${docBuildFolder}/src/docsys/Object/)
  message("Finished building Developer documentation.")

endfunction(build_object_docs)





# Build all the documentation
function(build_docs)

  message("Building Isis Documentation...")

  # Set up output directory and a temporary directory for building
  set(docVersion       ${PACKAGE_VERSION})
  set(docBuildFolder   ${CMAKE_BINARY_DIR}/docBuild)
  set(appDataFolder    ${docBuildFolder}/Application/data)
  set(docInstallFolder ${CMAKE_BINARY_DIR}/docs) # Final output documentation

  message(" Version is: " ${docVersion})

  # Clean up existing files
  execute_process(COMMAND rm -rf ${docBuildFolder})
  execute_process(COMMAND rm -rf ${docInstallFolder})

  message("XALAN = ${XALAN}")
  message("DOXYGEN = ${DOXYGEN}")
  message("LATEX = ${LATEX}")

  # Copy everything from src/docsys to docBuildFolder
  execute_process(COMMAND cp -r ${PROJECT_SOURCE_DIR}/src/docsys ${docBuildFolder})

  file(MAKE_DIRECTORY "${docBuildFolder}/Application")
  file(MAKE_DIRECTORY "${docBuildFolder}/Application/data")
  file(MAKE_DIRECTORY "${docInstallFolder}")

  message("Copying application information...")
  copy_app_docs_info()

  message("Building upper level directories...")
  build_upper_level()

  build_documents_folder()

  message("Building application docs...")
  build_application_docs()

  message("Building additional TOCs...")
  add_extra_tocs()

  # This step requires Latex and Doxygen
  message("Building object documentation")
  build_object_docs()

  # copy the built docs in the build directory over to the install directory on install
  execute_process(COMMAND cp -rf ${docInstallFolder} ${CMAKE_INSTALL_PREFIX})

  message("Finished building object documentation!")


endfunction(build_docs)




# This file gets called as a script, so call this function to run
#  all the code in the file.
build_docs()
