#!/usr/bin/env bash
source "${MYER_PATH}/bin/lib/myer_common_lib.sh"
source "${sh_path}/deploy_options.sh"
source "${sh_path}/key_management.sh"
set -eo pipefail
args=$#
log_file=oob
 
environment="${1,,}"
inst_type="${2,,}"
 
# Misc variables
environment_list="dev tst int perf prod"
inst_list="live stage"
newhost=`hostname`
OUTPUT=/opt/var/logs/makeme/$(basename $0)_$(date +%Y%m%d)_$$.out
 
if [ "${COMPONENT,,}" == "wcsprimary" ]; then
    srv_type="${inst_type}-pet";
  elif [ "${COMPONENT,,}" == "wcssecondary" ]; then
    srv_type="${inst_type}-cattle";
else
    logError "${COMPONENT,,} is not a valid COMPONENT type. Exiting ......."
    exit -1
fi
 
#Below 4 lines generates correct MQname for different environments
qmgr_name=`echo ${ENVIRONMENT_NAME} |sed 's/[^a-zA-Z0-9]//g' | cut -c -4 | awk '{print toupper($0)}'`
if [ "${#qmgr_name}" == 3 ]; then
qmgr_name=${qmgr_name}0
fi
qmgr_name=QM${qmgr_name}01
 
logInfo "Executing $(basename $0) script for ${environment} - ${inst_type} ......."
 
usage() {
  printf "Usage: $(basename $0) <profile_type> <env_type> <instance_type>"
  printf "(i.e.: $(basename $0) search dev live"
  printf "Note: All Parmeters are mandetory"
  exit -1
}
 
sanity_check() {
  ## Check User ID
  if [ "$(id -un)" != "root" ]; then
    logError "You must run this script as root.Exiting......."
    exit -1
  fi
  #Checking Number of inputs
  if [ "${args}" != 2 ]; then
    logError "$(basename $0) requires 2 arguments to be supplied"
    usage
    exit -1
  fi
  #Checking Environment type parameter
  is_valid_environment=false
  is_valid_inst=false
  for i in ${environment_list}
  do
    if [ "${environment}" == "$i" ]; then is_valid_environment=true; fi
  done
 
  if [ "${is_valid_environment}" == false ]; then
    logError "Supplied environment value is not correct"
    logError "Only these values are accepted: Dev/Onlinetest/Prod "
    usage
    logError "Exiting.........."
    exit -1
  fi
  #Checking Instance type parameter
  for j in ${inst_list}
  do
    if [ "${inst_type}" == "${j}" ]; then is_valid_inst=true; fi
  done
 
  if [ "${is_valid_inst}" == false ]; then
    logError "Supplied Instance type value is not correct"
    logError "Only below mentioned values are accepted: Live/ Stage"
    usage
    logError "Exiting.........."
    exit -1
  fi
}
 
setupInstanceEnv(){
  ##Utpdating properties based on instance type
  if [ "${inst_type}" == "live" ]; then
    export inst_dbName="${live_dbName}"
    export inst_dbHostname="${live_dbHostname}"
    export pass_dbuser="${pass_live_db}"
    export pass_dbauser="${pass_live_dba}"
  elif [ "${inst_type}" == "stage" ]; then
    export inst_instanceName="${inst_instanceName}s"
    export inst_dbName="${stage_dbName}"
    export inst_dbHostname="${stage_dbHostname}"
    export pass_dbuser="${pass_stage_db}"
    export pass_dbauser="${pass_stage_dba}"
  fi
}
 
prerequisite() {
 
  #Consuming wcsinstallation.properties
  if [ ! -r "${prop_path}"/wcsinstallation.properties ]; then
    logError "Either wcsinstallation.properties doesn't exist of does not have read permission. Exiting......."
    exit -1
  else
    logInfo "Parsing wcsintsallation.properties file......."
    readProperties "${prop_path}/wcsinstallation.properties"    #In myer_ommom_lib.sh
  fi
  #Consuming wcsconfiguration.properties
  if [ ! -r "${prop_path}"/wcsconfiguration.properties ]; then
    logError "Either wcsconfiguration.properties doesn't exist of does not have read permission. Exiting......."
    exit -1
  else
    logInfo "Parsing wcsconfiguration.properties file......."
    readProperties "${prop_path}/wcsconfiguration.properties"    #In myer_commom_lib.sh
  fi
 
  readProperties "${prop_path}/wcsconfiguration.properties"
 
  #setup instance variables
  setupInstanceEnv
 
  export stage_alt_dbHostname=${stage_alt_dbHostname}
  export live_alt_dbHostname=${live_alt_dbHostname}
  export stage_alt_dbPort=${stage_alt_dbPort}
  export live_alt_dbPort=${live_alt_dbPort}
  export inst_instanceName=${inst_instanceName}
 
  local propFile="${prop_path}/makeme_${environment}_${inst_type}.properties"
 
  grep SHELL_ "${propFile}" | grep -v '#' | awk -e '{gsub(/SHELL_/,"")}1' > "${prop_path}/shell.properties"
  grep WCS_JVM_CONFIG_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_JVM_CONFIG_/,"")}1' > "${prop_path}/update_jvm_config_wcs.properties"
  grep WCS_JVM_CUST_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_JVM_CUST_/,"")}1' > "${prop_path}/add_jvm_custom_prop_wcs.awstemplate.properties"
  grep WCS_LOGGING_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_LOGGING_/,"")}1' > "${prop_path}/logging_config_wcs.properties"
  grep WCS_DATASOURCE_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_DATASOURCE_/,"")}1' > "${prop_path}/data_source_config_wcs.awstemplate.properties"
  grep WCS_TRANSACTION_TIMEOUTS_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_TRANSACTION_TIMEOUTS_/,"")}1' > "${prop_path}/transaction_timeouts_wcs.properties"
  grep WCS_CACHE_CONFIG_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_CACHE_CONFIG_/,"")}1' > "${prop_path}/cache_config_wcs.properties"
  grep WCS_EXT_Cert_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_EXT_Cert_/,"")}1' > "${prop_path}/ext_certs_wcs.properties"
  grep WCS_INT_Cert_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_INT_Cert_/,"")}1' > "${prop_path}/int_certs_wcs.awstemplate.properties"
  grep WCS_WEB_CONTAINER_PROPS_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_WEB_CONTAINER_PROPS_/,"")}1' > "${prop_path}/web_container_cust_wcs.properties"
  grep WCS_JSESSION_PROPS_ ${propFile} | grep -v '#' | awk -e '{gsub(/WCS_JSESSION_PROPS_/,"")}1' > "${prop_path}/jsession_wcs.awstemplate.properties"
 
  ## Files for SQL
  grep SQL_SCHEDULER_ ${propFile} | grep -v '#' | awk -e '{gsub(/SQL_SCHEDULER_/,"")}1' > "${prop_path}/sql_scheduler.properties"
  grep SQL_SEARCH_ ${propFile} | grep -v '#' | awk -e '{gsub(/SQL_SEARCH_/,"")}1' > "${prop_path}/sql_search.properties"
  grep SQL_MSGTYPE_ ${propFile} | grep -v '#' | awk -e '{gsub(/SQL_MSGTYPE_/,"")}1' > "${prop_path}/sql_msgtype.properties"
 
  grep SOLR_JVM_CONFIG_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_JVM_CONFIG_/,"")}1' > "${prop_path}/update_jvm_config_solr.properties"
  grep SOLR_JVM_CUST_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_JVM_CUST_/,"")}1' > "${prop_path}/add_jvm_custom_prop_solr.awstemplate.properties"
  grep SOLR_LOGGING_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_LOGGING_/,"")}1' > "${prop_path}/logging_config_solr.properties"
  grep SOLR_DATASOURCE_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_DATASOURCE_/,"")}1' > "${prop_path}/data_source_config_solr.awstemplate.properties"
  grep SOLR_TRANSACTION_TIMEOUTS_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_TRANSACTION_TIMEOUTS_/,"")}1' > "${prop_path}/transaction_timeouts_solr.properties"
  grep SOLR_CACHE_CONFIG_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_CACHE_CONFIG_/,"")}1' > "${prop_path}/cache_config_solr.properties"
  grep SOLR_EXT_Cert_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_EXT_Cert_/,"")}1' > "${prop_path}/ext_certs_solr.properties"
  grep SOLR_INT_Cert_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_INT_Cert_/,"")}1' > "${prop_path}/int_certs_solr.properties"
  grep SOLR_WEB_CONTAINER_PROPS_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_WEB_CONTAINER_PROPS_/,"")}1' > "${prop_path}/web_container_cust_solr.properties"
  grep SOLR_JSESSION_PROPS_ ${propFile} | grep -v '#' | awk -e '{gsub(/SOLR_JSESSION_PROPS_/,"")}1' > "${prop_path}/jsession_solr.awstemplate.properties"
 
  logInfo "Parsing other property files"
  readProperties "${prop_path}/shell.properties"
 
  logInfo "Applying awstemplates"
  exec_parallel \
    "\"${sh_path}/apply-awstemplate-properties.sh\" \"${prop_path}\"" \
    "\"${sh_path}/apply-awstemplate-properties.sh\" \"${was_installLocation}/profiles/${inst_instanceName}\"" \
    "\"${sh_path}/apply-awstemplate-properties.sh\" \"${was_installLocation}/profiles/${inst_instanceName}_solr\"" \
    "\"${sh_path}/apply-awstemplate-properties.sh\" \"${wcs_InstallPath_commerceLocation}/instances\"" \
    "\"${sh_path}/apply-awstemplate-properties.sh\" \"/opt/myer/etc\""
 
  #execute thelogInfo "clean old cachebusters." runtime part of the config deployment
  logInfo "Applying Post wcbd Config deployment step"
  exec_parallel \
    "\"${sh_path}/install-config.sh\" \"${srv_type}\" \"${was_installLocation}/profiles/${inst_instanceName}\" \"${wcs_NonRoot_userID}\"" \
    "\"${sh_path}/install-config.sh\" \"${srv_type}\" \"${was_installLocation}/profiles/${inst_instanceName}_solr\" \"${wcs_NonRoot_userID}\"" \
    "\"${sh_path}/install-config.sh\" \"${srv_type}\" \"${wcs_InstallPath_commerceLocation}/instances\" \"${wcs_NonRoot_userID}\"" \
 
  # Checking hosts file for database entry
  logInfo "Set the HostsFile for the DB Entry ${inst_dbHostname}"
  sed -i -e "/${inst_dbHostname}/d" /etc/hosts
 
  #Added additional chown and chmod for /opt/*.* as files are being copied ad root. Updated ansible to do it properly but yet to test so letft these lines here utill tested.
  chown -R "${wcs_NonRoot_userID}":"${wcs_NonRoot_userGroup}" "${prop_path}"
  chown -R "${wcs_NonRoot_userID}":"${wcs_NonRoot_userGroup}" "${base_location}"
  chown -R "${wcs_NonRoot_userID}":"${wcs_NonRoot_userGroup}" /opt/scripts
  chmod -R 755 "${prop_path}"
  chmod -R 755 "${base_location}"
  chmod -R 755 /opt/scripts
  chmod -R 440 "${prop_path}/wcsinstallation.properties"
}
stop_jvm() {
 
  local svr_name=$1
  local inst_name=$2
  local process_id=""
 
  local jvm_stop_status=0
 
  logInfo "Stopping ${svr_name}."
 
  if [ -f ${pid_file} ]; then
    process_id=$(cat $pid_file)
    if [ "${process_id}" != "" ] && [ $(ps -p ${process_id} | wc -l) -lt 2 ]; then
      ps -p ${process_id}
      rm -f "${pid_file}"
      logInfo "Found PID file, ${pid_file}. no Process for process id ${process_id}."
    else
      logInfo "Stopping ${svr_name} Server with process ID ${process_id}."
      su - -c "${was_installLocation}/profiles/${inst_name}/bin/stopServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
    fi
  else
    logInfo "PID file ${pid_file} NOT found. Server ${svr_name} already stopped."
  fi
 
  if [ "${process_id}" != "" ]; then
    local tmp=$(timeout 120s tail --pid=${process_id} -f /dev/null)
    jvm_stop_status=$?
    logInfo "jvm_stop_status ${jvm_stop_status}"
    if [ $jvm_stop_status -eq 0 ] || [ $jvm_stop_status -eq 1 ]; then
      logInfo "Process ${process_id} completed. Server ${svr_name} stopped."
    else
      logError "Server ${svr_name} Failed to stop in 120 seconds after the stop script has completed."
      exit -1
    fi
  fi
 
}
 
restartServers_postIndex() {
  profile_type=$1
  setupSvrParams ${profile_type}
  local process_id=""
  local jvm_stop_status=0
  logInfo "Stopping ${svr_name} post indexing."
  if [ -f ${pid_file} ]; then
    process_id=$(cat $pid_file)
    if [ "${process_id}" != "" ] && [ $(ps -p ${process_id} | wc -l) -lt 2 ]; then
      ps -p ${process_id}
      rm -f "${pid_file}"
      logInfo "Found PID file, ${pid_file}. no Process for process id ${process_id}."
    else
      logInfo "Stopping ${svr_name} Server with process ID ${process_id}."
      su - -c "${was_installLocation}/profiles/${profile_name}/bin/stopServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
    fi
  else
    logInfo "PID file ${pid_file} NOT found. Server ${svr_name} already stopped."
  fi
 
  if [ "${process_id}" != "" ]; then
    local tmp=$(timeout 120s tail --pid=${process_id} -f /dev/null)
    jvm_stop_status=$?
    logInfo "jvm_stop_status ${jvm_stop_status}"
    if [ $jvm_stop_status -eq 0 ] ; then
      logInfo "Process ${process_id} completed. Server ${svr_name} stopped."
    else
      logError "Server ${svr_name} Failed to stop."
      exit -1
    fi
  fi
  local process_id=""
  logInfo "Starting ${svr_name} post indexing."
  if [ -f ${pid_file} ]; then
    process_id=$(cat $pid_file)
    if [ "${process_id}" != "" ] && [ $(ps -p ${process_id} | wc -l) -gt 1 ]; then
      logInfo "Server ${svr_name} already Running"
    else
      rm -f $pid_file
      logInfo "Starting ${svr_name} Server."
      su - -c "${was_installLocation}/profiles/${profile_name}/bin/startServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
      if [ $? -ne 0 ]; then
        logError "${svr_name} did not started successfully. Exiting..."
        exit -1
      else
        logInfo "${svr_name} started successfully."
      fi
    fi
  else
    logInfo "Starting ${svr_name} post indexing."
    su - -c "${was_installLocation}/profiles/${profile_name}/bin/startServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
    if [ $? -ne 0 ]; then
      logError "${svr_name} did not started successfully. Exiting..."
      exit -1
    else
        logInfo "${svr_name} started successfully."
    fi
  fi
}
 
start_jvm(){
  local svr_name=$1
  local inst_name=$2
  local process_id=""
 
  logInfo "Starting ${svr_name}."
 
  if [ -f ${pid_file} ]; then
    process_id=$(cat $pid_file)
    if [ "${process_id}" != "" ] && [ $(ps -p ${process_id} | wc -l) -gt 1 ]; then
      logInfo "Server ${svr_name} already Running"
    else
      rm -f $pid_file
      logInfo "Starting ${svr_name} Server."
      su - -c "timeout -s SIGKILL -k 1 10m ${was_installLocation}/profiles/${inst_name}/bin/startServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
      if [ $? -ne 0 ]; then
        logError "${svr_name} did not started successfully. Exiting..."
        exit -1
      fi
    fi
  else
    logInfo "Starting ${svr_name} Server."
    su - -c "timeout -s SIGKILL -k 1 10m ${was_installLocation}/profiles/${inst_name}/bin/startServer.sh ${svr_name}" "${wcs_NonRoot_userID}"
    if [ $? -ne 0 ]; then
      logError "${svr_name} did not started successfully. Exiting..."
      exit -1
    fi
  fi
}
 
start_ihs() {
  local conf_file_path=$1
  logInfo "Starting IHS instance. ${conf_file_path}"
  TZ=Australia/Melbourne ${IHS_installLocation}/bin/apachectl -k start -f "${conf_file_path}"
}
stop_ihs() {
  local conf_file_path=$1
  logInfo "Stopping IHS instance."
  ${IHS_installLocation}/bin/apachectl -k stop -f "${conf_file_path}"
}
change_hostname(){
  ${profile_type}_change_hostname
}
 
update_wsadmin_properties(){
  local inst_name=$1
 
  #Common configuration jythons for both profiles:
  logInfo "Update wsadmin.properties for ${inst_name}."
  # sed -i -e "s/com.ibm.ws.scripting.host=localhost/com.ibm.ws.scripting.host=${newhost}/"  "${was_installLocation}/profiles/${inst_name}/properties/wsadmin.properties"
  sed -i -e "s/com.ibm.ws.scripting.defaultLang=jacl/com.ibm.ws.scripting.defaultLang=jython/" "${was_installLocation}/profiles/${inst_name}/properties/wsadmin.properties"
  sed -i -e "s/#com.ibm.ws.scripting.traceString=com.ibm.*=all=enabled/com.ibm.ws.scripting.traceString=com.ibm.*=all=enabled/"  "${was_installLocation}/profiles/${inst_name}/properties/wsadmin.properties"
}
was_configurations() {
  ${profile_type}_was_configurations
}
 
wcs_mq_configuration() {
  ${profile_type}_wcs_mq_configuration
}
retrieve_local_certs() {
  ${profile_type}_retrieve_local_certs
}
retrieve_thirdparty_certs() {
  ${profile_type}_retrieve_thirdparty_certs
}
db2_catalog() {
  ${profile_type}_db2_catalog
}
db2_environment_config() {
  ${profile_type}_db2_environment_config
}
cert_stuff () {
  ${profile_type}_cert_stuff
}
files_update(){
  ${profile_type}_files_update
}
regenerate_Plugin(){
  ${profile_type}_regenerate_Plugin
}
exec_post_deploy(){
  ${profile_type}_exec_post_deploy
}
build_index() {
  logInfo "Restoring the Search Index from S3://${INDEX_RESTORE_PATH} ."
  # isolate this execution from the current shell
  ( setupSvrParams "search" && stop_jvm "${svr_name}" "${profile_name}" && restore_search_index_from_s3 ) #in deploy_options.sh
}
jsp_batch_compiler() {
  logInfo "Running JSP Batch Compiler for WCS"
  su -c "${was_installLocation}/bin/JspBatchCompiler.sh -ear.path ${was_installLocation}/profiles/${inst_instanceName}/installedApps/${inst_instanceName}Cell01/WC_${inst_instanceName}.ear" "${wcs_NonRoot_userID}"
 
  logInfo "Running JSP Batch Compiler for Solr"
  su -c "${was_installLocation}/bin/JspBatchCompiler.sh -ear.path ${was_installLocation}/profiles/${inst_instanceName}_solr/installedApps/${inst_instanceName}_search_cell/Search_${inst_instanceName}.ear" "${wcs_NonRoot_userID}"
}
enable_app_autostart(){
  ${profile_type}_enable_app_autostart
}
 
enable_healthcheck() {
  logInfo "Enabling IHS static healthcheck page"
  mv ${MYER_DATA_PATH}/static/WCM/inspiration/healthcheck.html.default ${MYER_DATA_PATH}/static/WCM/inspiration/healthcheck.html
  chown ${wcs_NonRoot_userID}:${wcs_NonRoot_userGroup} ${MYER_DATA_PATH}/static/WCM/inspiration/healthcheck.html
}
 
rm_wcs_binary (){
  if [ "${COMPONENT}" == "wcssecondary"  ]; then
    logInfo "Removing WCS binaries from Secondary server."
    (cd ${wcs_InstallPath_commerceLocation} && find . -maxdepth 1 -depth -not -path "./instances*" -not -path "."  -exec  rm -rf {} \;) &
    (cd ${wcs_InstallPath_commerceLocation}/instances && find . -maxdepth 1 -depth -not -path "./myer*" -not -path "."  -exec  rm -rf {} \;) &
    (cd "${wcs_InstallPath_commerceLocation}"/instances/"${inst_instanceName}" &&
    find . -maxdepth 1 -depth -not -path "./http*" \
      -not -path "." \
      -not -path "./search*" \
      -not -path "./web*" \
      -exec  rm -rf {} \;) &
  fi
}
 
## each job needs to be passed in as an individual argument
exec_parallel() {
 
  PIDS=""
  JOB_STATUS=0
 
  for exec_job in "${@}"
  do
    (eval ${exec_job}) &
    local job_pid=$!
    logInfo "EXECUTING pid=${job_pid} command=${exec_job}"
    PIDS="${PIDS} ${job_pid}"
  done
 
  #fetch the exit code for each of the PIDS registered above
  for wait_job in ${PIDS}
  do
      local cur_status=0
      wait ${wait_job} || let "cur_status+=1" "JOB_STATUS+=1"
      logInfo "pid=${wait_job} status=${cur_status}"
  done
 
  if [ "${JOB_STATUS}" != "0" ];
  then
    logInfo "${JOB_STATUS} of the Parallel Jobs failed. Please check the logs."
    exit -1
  fi
 
}
 
restartServers() {
  profile_type=$1
  setupSvrParams ${profile_type}
  stop_ihs ${http_conf_path}
  stop_jvm ${svr_name} ${profile_name}
  start_jvm ${svr_name} ${profile_name}
  start_ihs ${http_conf_path}
}
 
run_svr_config_step1() {
  profile_type=$1
  setupSvrParams ${profile_type}
 
  stop_jvm ${svr_name} ${profile_name}
  start_ihs ${http_conf_path}
  db2_catalog
  cert_stuff
  files_update
  start_jvm ${svr_name} ${profile_name}
  change_hostname
  update_wsadmin_properties ${profile_name}
  regenerate_Plugin
}
 
run_svr_config_step2() {
  profile_type=$1
  setupSvrParams ${profile_type}
  was_configurations ${profile_name}
  wcs_mq_configuration
  enable_app_autostart
}
run_primary_only(){
  profile_type=$1
  setupSvrParams ${profile_type}
  exec_post_deploy      #in post_deploy.sh file
  db2_environment_config # Run db environment specific configuration - scheduler, msgtypes, solr
}
 
setupSvrParams() {
  profile_type=$1
  ## set up the profile execution type
  source ${sh_path}/${profile_type}.sh
 
  if [ "${profile_type}" == "wcs" ]
  then
    svr_name=server1
    profile_name=${inst_instanceName}
    http_conf_path=${wcs_InstallPath_commerceLocation}/instances/${inst_instanceName}/httpconf/httpd.conf
  fi
 
  if [ "${profile_type}" == "search" ]
  then
    svr_name=solrServer
    profile_name=${inst_instanceName}_solr
    http_conf_path=${wcs_InstallPath_commerceLocation}/instances/${inst_instanceName}/search/solr/home/httpconf/httpd.conf
  fi
 
  pid_file=${was_installLocation}/profiles/${profile_name}/logs/${svr_name}/${svr_name}.pid
  if [ "${log_file}" == 'custom' ]; then
    pid_file=/opt/var/logs/webSphere/appServer/${svr_name}/${svr_name}.pid
  fi
}
ram_drive(){
  mkdir -p /opt/var/cache/diskoffload/wcs
  mount -t tmpfs -o size=10g tmpfs /opt/var/cache/diskoffload/wcs
  chown -R "${wcs_NonRoot_userID}":"${wcs_NonRoot_userGroup}" /opt/var/cache/diskoffload/wcs
  touch /opt/var/cache/diskoffload/wcs/10G_RAM_DRIVE_MOUNTED
}
configure_payment_plugin(){
    logInfo "Running configure_payment_plugin"
    "${sh_path}/encrypt_data_configurepaymentplugin.sh"
    #Changing permission for sh
    chown -R ${wcs_NonRoot_userID}:${wcs_NonRoot_userGroup} "${sh_path}/configurepaymentplugin.sql"
    chmod 755 "${sh_path}/configurepaymentplugin.sql"
    echo "#!/usr/bin/env bash" > "${sh_path}/configurepaymentplugin.sh"
    #echo "set -e" >> "${sh_path}/configurepaymentplugin.sh"      CANT have this it causes exit on warning which is common and should be non fatal
    echo "db2 connect to ${inst_dbName} user ${inst_dbUserName} using ${pass_dbuser}" >> "${sh_path}/configurepaymentplugin.sh"
    echo "db2 +c -vstf ${sh_path}/configurepaymentplugin.sql" >> "${sh_path}/configurepaymentplugin.sh"
    echo "db2exitcode=\$?" >> "${sh_path}/configurepaymentplugin.sh"
    echo "if [ \$db2exitcode -ge 4 ]; then" >> "${sh_path}/configurepaymentplugin.sh"
    echo "    echo \"FAILURE - SQL ERROR - ROLLING BACK DB ENVIRONMENT CONFIG\"" >> "${sh_path}/configurepaymentplugin.sh"
    echo "    db2 rollback" >> "${sh_path}/configurepaymentplugin.sh"
    echo "    exit \$db2exitcode" >> "${sh_path}/configurepaymentplugin.sh"
    echo "else" >> "${sh_path}/configurepaymentplugin.sh"
    echo "    db2 commit" >> "${sh_path}/configurepaymentplugin.sh"
    echo "fi" >> "${sh_path}/configurepaymentplugin.sh"
    #Changing permission for sh
    chown -R ${wcs_NonRoot_userID}:${wcs_NonRoot_userGroup} "${sh_path}/configurepaymentplugin.sh"
    chmod 755 "${sh_path}/configurepaymentplugin.sh"
    #Executing generated sh script
    su -l -c "${sh_path}/configurepaymentplugin.sh" "${wcs_NonRoot_userID}"
}
cleanup(){
  #Removing scripts and property files
    logInfo "Running Cleanup"
    rm -rf /opt/scripts
    rm -rf /opt/prepInstance.sh
    rm -rf /opt/properties
    rm -rf /opt/cert
  # # Remove wcbd deploy files from server
    rm -rf /opt/dbchanges_environment.sql
    rm -rf /opt/templates
    rm -rf /var/tmp/wcbd-deploy-*
  # #Removing makeme specific env var file
    rm -rf /etc/profile.d/env_var_makeme.sh
  #Remove test data load files from higher environments
    if [ "${ENV_TYPE}" == "perf" ] || [ "${ENV_TYPE}" == "prod" ] ; then
      rm -rf "${MYER_PATH}"/util/test/*
      rm -rf "${MYER_DATA_PATH}"/testData/*
    fi
}
 
 
 
rm_wcs_jars(){
  logInfo "Cleaning up the jars for stage and live"
  if [ "${inst_type}" == "live" ]; then
    rm -rf "${WC_EAR_PATH_LIVE}"/lib/spring-core.jar
    rm -rf "${WC_EAR_PATH_LIVE}"/lib/spring-context.jar
    rm -rf "${WC_EAR_PATH_LIVE}"/lib/spring-beans.jar
  else
    rm -rf "${WC_EAR_PATH_STAGE}"/lib/spring-core.jar
    rm -rf "${WC_EAR_PATH_STAGE}"/lib/spring-context.jar
    rm -rf "${WC_EAR_PATH_STAGE}"/lib/spring-beans.jar
  fi
}
 
fetch_and_upload_google_root_certs() {
 certPath="/opt/cert"
 certExtractPath="${certPath}/certExtract"
 mkdir -p "${certExtractPath}"
 ROOT_PEM_URL="https://pki.goog/roots.pem"
 ROOT_PEM_PATH="${certPath}/roots.pem"
 # Match bucket logic used in retrieveCertsFromS3
 THIRDPARTY_CERT_BUCKET="myer-thirdparty-certs-${AWS_ACCOUNT}"
 if [ "${TYPE}" == "live" ] && [ "${ENV_TYPE}" == "prod" ]; then
   THIRDPARTY_CERT_BUCKET="myer-thirdparty-certs-live-${AWS_ACCOUNT}"
 else
   THIRDPARTY_CERT_BUCKET=myer-thirdparty-certs-${AWS_ACCOUNT}
 fi
 logInfo "Fetching roots.pem from ${ROOT_PEM_URL}..."
 if curl -sf "${ROOT_PEM_URL}" -o "${ROOT_PEM_PATH}"; then
   logInfo "Splitting roots.pem into individual certs..."
   cd "${certExtractPath}"
   awk 'BEGIN {n=0} /# Operating CA:/ {n++} {print > "cert"n".cert"}' "${ROOT_PEM_PATH}"
   logInfo "Uploading split certs to s3://${THIRDPARTY_CERT_BUCKET}/ ..."
   aws s3 cp "${certExtractPath}/" "s3://${THIRDPARTY_CERT_BUCKET}/" --region ap-southeast-2 --recursive
   logInfo "Google root certs uploaded successfully."
 else
   logWarning "Failed to fetch roots.pem from Google. Skipping cert automation..."
 fi
}
 
retrieveCertsFromS3() {
  action=$1
  THIRDPARTY_CERT_BUCKET=myer-thirdparty-certs-${AWS_ACCOUNT}
  certPath="/opt/cert"
  certExtractPath="/opt/cert/certExtract"
  mkdir -p ${certExtractPath}
  chown -R "${wcs_NonRoot_userID}":"${wcs_NonRoot_userGroup}" ${certPath}
  chmod -R 755 "${certPath}"
  thirdPartyCerts=`cat /opt/properties/ext_certs_wcs.properties | cut -d"=" -f2 | sed -e 's/:443/.cert /g' | tr -d ","`
  logInfo "thirdPartyCerts :: ${thirdPartyCerts}"
  if [ "${TYPE}" == "live" ] && [ "${ENV_TYPE}" == "prod" ] ; then
    THIRDPARTY_CERT_BUCKET=myer-thirdparty-certs-live-${AWS_ACCOUNT}
  else
    THIRDPARTY_CERT_BUCKET=myer-thirdparty-certs-${AWS_ACCOUNT}
  fi
  if [ ! -z "$(aws s3 ls s3://${THIRDPARTY_CERT_BUCKET}/ --region ap-southeast-2 2>&1 | grep 'NoSuchBucket')" ]; then
    logError "${THIRDPARTY_CERT_BUCKET} S3 Bucket does not exist. Exiting..."
    exit -1
  fi
  logInfo "THIRDPARTY_CERT_BUCKET :: $THIRDPARTY_CERT_BUCKET"
  if [ "${action}" == "download" ]; then
    logInfo "Downloading Thirtparty Certs from s3://${THIRDPARTY_CERT_BUCKET}/ ..."
    aws s3 sync s3://${THIRDPARTY_CERT_BUCKET}/ "${certPath}" --region ap-southeast-2
    downloadStatus=$?
    logInfo "downloadStatus :: ${downloadStatus}"
    countCert=`ls -1 $certPath/*.cert 2>/dev/null | wc -l`
    logInfo "countCert :: ${countCert}"
    if [ ${downloadStatus} -eq 0 ] && [ "${countCert}" -ne 0 ] ; then
      for thirdPartyCert in ${thirdPartyCerts}
      do
         if [[ ! -e "${certPath}/${thirdPartyCert}" ]]; then
           logWarning "$thirdPartyCert does not exist in S3..."
         fi
      done
      logInfo "Third Party Certificates available in S3://${THIRDPARTY_CERT_BUCKET}/ has been downloaded successful..."
    else
      logError "Error downloading certificates... Ensure Third Party Certificates are available in ${THIRDPARTY_CERT_BUCKET} S3 bucket. Exiting..."
      exit -1
    fi
  elif [ "${action}" == "upload" ]; then
    logInfo "Uploading Extracted Third Party Certificates to s3://${THIRDPARTY_CERT_BUCKET}/ ..."
    countExtractCert=`ls -1 $certExtractPath/*.cert 2>/dev/null | wc -l`
    logInfo "countExtractCert :: ${countExtractCert}"
    if [ ${countExtractCert} -gt 0 ]; then
        aws s3 cp ${certExtractPath}/ s3://${THIRDPARTY_CERT_BUCKET}/ --region ap-southeast-2 --recursive
        uploadStatus=$?
        logInfo "uploadStatus :: ${uploadStatus}"
        if [ ${uploadStatus} == 0 ]; then
           logInfo "Extracted certificates have been uploaded to S3 successfully..."
        else
           logWarning "Error uploading certificates to S3..."
           exit -1
        fi
    else
        logError "Failure with the Singer Certificate Extraction. Exiting..."
        exit -1
    fi
  else
    logError "Please provide a valid argument...Available options 'download' or 'upload'. Exiting..."
    exit -1
  fi
}
 
additionalClassPath() {
  sed -i -E 's|\$MORE_CLASSPATH|\$EAR_PATH/lib/commons-logging.jar:$EAR_PATH/lib/httpclient.jar:$EAR_PATH/lib/slf4j-api.jar:$EAR_PATH/lib/slf4j-jdk.jar:$MORE_CLASSPATH|' "${wcs_InstallPath_commerceLocation}"/bin/di-buildindex.sh
}
 
xercesImplJarRemoval() {
  find ${was_installLocation} -type f -name xercesImpl.jar -exec rm -rf {} \;
}
 
main() {
  start_time=$SECONDS
  cd /opt
  sanity_check
  prerequisite
  fetch_and_upload_google_root_certs
  retrieveCertsFromS3 "download"
  additionalClassPath
  xercesImplJarRemoval
  ram_drive
  ssh_key_stuff   #in key_management.sh file
  if [ "${inst_type}" == "live" ]; then
    configure_payment_plugin
  fi
 
  # RUN Search and WCS svr jobs in parallel and save the PIDS
  exec_parallel \
    'run_svr_config_step1 "wcs"' \
    'run_svr_config_step1 "search"'
  ## restart the jvms
 
  rm_wcs_jars
  exec_parallel \
    'restartServers "wcs"' \
    'restartServers "search"'
 
  exec_parallel \
    'run_svr_config_step2 "wcs"' \
    'run_svr_config_step2 "search"'
 
  exec_parallel \
    'fetch_rewrite_rule' \
    'fetch_cachebusters'
 
    ## restart the jvms
  exec_parallel \
    'restartServers "wcs"' \
    'restartServers "search"'
 
  export log_file=custom
 
  if [ "${COMPONENT}" == "wcsprimary" ]; then
    exec_parallel \
      'run_primary_only "wcs"' \
      'run_primary_only "search"'
    build_index
 
    exec_parallel \
      'restartServers_postIndex "wcs"' \
      'restartServers_postIndex "search"'
  fi
 
  retrieveCertsFromS3 "upload"
  rm_wcs_binary
  enable_healthcheck
 
  run_stage_prop    #in deploy_options.sh file
  run_index_prop    #in deploy_options.sh file
 
  #  jsp_batch_compiler
  cleanup
  rm -f /opt/CN7Z8ML.zip
  execution_time=$(( SECONDS - start_time ))
  logInfo "MakeMe Completed in $(($execution_time / 60)):$(($execution_time % 60)) Min."
}
 
# Running main method
main >> "${OUTPUT}" 2>&1
aws s3 cp "${OUTPUT}" "s3://$OPS_STORAGE_BUCKET/logs${OUTPUT}"
