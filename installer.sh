#!/bin/bash

#1.-precheck. See what IP to use, what devices to get info on, if CAS/noCAS etc
#2.-install prometheus
#3. install node_exporter
#4. install cas exporter
#5. configure prometheus
#6. configure node exporter as a service
#7. configure prometheus as a service
#8. configure cas exporter as a service
#9. start the service
# if a grafana service
#10. install grafana
#11. configure grafana
#else
#10. configure an exported xml to give to user so they can import into grafana

typeset CUR_DIR=''
typeset BASE_DIR=''
typeset IS_CAS_AVAIL=1
typeset NUM_CAS_DEVS=1
typeset IS_GRAFANA_SERVER=0
typeset IS_UPDATING_DASHBOARD=1
typeset LOG='/home/felipe/cas_exporter_installer.log'

typeset STATUS_FILE='/home/felipe/cas_exporter_installer.status'
typeset CAS_EXPORTER_LOG='/tmp/cas_exporter.log'
typeset CAS_EXPORTER_LOG_ARG=''
typeset STARTING_PORT=2114
typeset OS_TYPE='ubuntu'
typeset CURRENT_STEP=0
typeset TOTAL_STEPS=0
CAS_IDs=(1)


function check_rc() {
  typeset rc=$1

  if [[ ${rc} != 0 ]]; then
    echo "$(date) - ERROR. Installation failed. See log ${LOG} for details"
    echo "$(date) - ERROR. Command failed with RC $rc" >> $LOG
    cleanup
    exit $rc
  else
    echo "$(date) - MSG. Command completed successfully" >> $LOG
  fi
}

function run_cmd() {
  typeset cmd=$1
  echo "$(date) - CMD. Running command $cmd" >> $LOG
  eval "${cmd}" >> $LOG 2>&1
  check_rc $?
}

# This function writes a status line entry to STATUS_LOG
function write_progress() {
  typeset msg=$1
  typeset pct=0
  typeset formatted_pct=''

  if [[ $TOTAL_STEPS -le 0 ]]; then
    echo "0=${msg}" > ${STATUS_FILE}
    return
  fi

  if [[ $CURRENT_STEP -lt 0 ]]; then
    echo "0=${msg}" > ${STATUS_FILE}
    return
  fi

  if  [[ $CURRENT_STEP -ge $TOTAL_STEPS ]]; then
    echo "100=${msg}" > ${STATUS_FILE}
    return
  fi

  let CURRENT_STEP=$CURRENT_STEP+1
  pct=$(bc <<< "scale=2; $CURRENT_STEP/$TOTAL_STEPS" )
  formatted_pct=$(printf "%03.2f" "${pct}")

  echo "$msg"
  echo "${formatted_pct}=${msg}" > ${STATUS_FILE}
}

function add_cas_user() {
  if [[ -z $(id -u 'cas_exporter') ]]; then
    run_cmd "useradd -rs /bin/false cas_exporter"
  fi
}

function install_prometheus() {
  if [ ! -d "${BASE_DIR}/prometheus-2.10.0.linux-amd64" ]; then
    run_cmd "wget https://github.com/prometheus/prometheus/releases/download/v2.10.0/prometheus-2.10.0.linux-amd64.tar.gz"
    run_cmd "tar xvzf prometheus-2.10.0.linux-amd64.tar.gz"
    run_cmd "cd prometheus-2.10.0.linux-amd64"
    run_cmd "chown cas_exporter:cas_exporter prometheus"
    run_cmd "chown -R cas_exporter:cas_exporter ${BASE_DIR}/prometheus-2.10.0.linux-amd64"
  fi
}

function install_go() {
  if [[ ! -e "${BASE_DIR}/https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz" ]]; then
    run_cmd "wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz"
    run_cmd "tar -C /usr/local/ -xzf  go1.13.5.linux-amd64.tar.gz"
    run_cmd "export PATH=$PATH:/usr/local/go/bin"
    run_cmd "go get github.com/prometheus/client_golang/prometheus"
    run_cmd "go get github.com/prometheus/client_golang/prometheus/promauto"
    run_cmd "go get github.com/prometheus/client_golang/prometheus/promhttp"
  fi
}

function install_cas_exporter() {
  if [[ ! -d "${BASE_DIR}/CAS_Exporter" ]]; then
    run_cmd "cd ${BASE_DIR}"
    run_cmd "git clone https://github.com/felipe-barajas/CAS_Exporter"
    run_cmd "cd CAS_Exporter"
    run_cmd "export PATH=\$PATH:/usr/local/go/bin"
    run_cmd "go build cas_exporter.go"
    run_cmd "cp cas_exporter /usr/local/bin"
    run_cmd "chown cas_exporter:cas_exporter /usr/local/bin/cas_exporter"
  fi
}

function install_grafana_ubuntu() {
  if [ ! -e "${BASE_DIR}/grafana_6.5.1_amd64.deb" ]; then
    run_cmd "cd ${BASE_DIR}"
    run_cmd "wget https://dl.grafana.com/oss/release/grafana_6.5.1_amd64.deb"
    run_cmd "dpkg -i grafana_6.5.1_amd64.deb"
  fi
}

function install_grafana_rhel() {
  if [ ! -e "${BASE_DIR}/grafana-6.5.1-1.x86_64.rpm" ]; then
    run_cmd "cd ${BASE_DIR}"
    run_cmd "wget https://dl.grafana.com/oss/release/grafana-6.5.1-1.x86_64.rpm"
    run_cmd "yum localinstall grafana-6.5.1-1.x86_64.rpm"
  fi
}

function install_node_exporter() {
  if [ ! -d "${BASE_DIR}/node_exporter-0.18.1.linux-amd64" ]; then
    run_cmd "cd ${BASE_DIR}"
    run_cmd "wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz"
    run_cmd "tar xvzf node_exporter-0.18.1.linux-amd64.tar.gz"
    run_cmd "cp node_exporter-0.18.1.linux-amd64/node_exporter /usr/local/bin"
    run_cmd "chown cas_exporter:cas_exporter /usr/local/bin/node_exporter"
  fi
}

function setup_cas_exporter_service() {
  echo "[Unit]"                                           > /etc/systemd/system/cas_exporter.service
  check_rc $?
  echo "Description=CAS Exporter"                        >> /etc/systemd/system/cas_exporter.service
  echo "After=network-online.target"                     >> /etc/systemd/system/cas_exporter.service
  echo " "                                               >> /etc/systemd/system/cas_exporter.service
  echo "[Service]"                                       >> /etc/systemd/system/cas_exporter.service
  echo "Type=oneshot"                                    >> /etc/systemd/system/cas_exporter.service
  echo "ExecStart=/bin/true"                             >> /etc/systemd/system/cas_exporter.service
  echo "RemainAfterExit=yes"                             >> /etc/systemd/system/cas_exporter.service
  echo " "                                               >> /etc/systemd/system/cas_exporter.service
  echo "[Install]"                                       >> /etc/systemd/system/cas_exporter.service
  echo "WantedBy=multi-user.target"                      >> /etc/systemd/system/cas_exporter.service
}

function setup_prometheus_service() {
  echo "[Unit]"                                                          > /etc/systemd/system/cas_exporter_prometheus.service
  check_rc $?
  echo "Description=CAS Exporter Component Prometheus"                  >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "PartOf=cas_exporter.service"                                    >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "After=cas_exporter.service"                                     >> /etc/systemd/system/cas_exporter_prometheus.service
  echo " "                                                              >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "[Service]"                                                      >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "Type=simple"                                                    >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "WorkingDirectory=${BASE_DIR}/prometheus-2.10.0.linux-amd64"     >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "ExecStart=${BASE_DIR}/prometheus-2.10.0.linux-amd64/prometheus" >> /etc/systemd/system/cas_exporter_prometheus.service
  echo " "                                                              >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "[Install]"                                                      >> /etc/systemd/system/cas_exporter_prometheus.service
  echo "WantedBy=cas_exporter.service"                                  >> /etc/systemd/system/cas_exporter_prometheus.service
}

function setup_cas_parser_service() {
  if [[ ${IS_CAS_AVAIL} -ne 1 ]]; then
    return
  fi

  echo "[Unit]"                                                > /etc/systemd/system/cas_exporter_parser.target
  check_rc $?
  echo "Description=CAS Exporter Component CAS Parser Target" >> /etc/systemd/system/cas_exporter_parser.target
  echo "PartOf=cas_exporter.service"                          >> /etc/systemd/system/cas_exporter_parser.target
  echo "After=cas_exporter.service"                           >> /etc/systemd/system/cas_exporter_parser.target
  echo "AllowIsolate=yes"                                     >> /etc/systemd/system/cas_exporter_parser.target
  echo " "                                                    >> /etc/systemd/system/cas_exporter_parser.target
  echo "[Install]"                                            >> /etc/systemd/system/cas_exporter_parser.target
  echo "WantedBy=cas_exporter.service"                        >> /etc/systemd/system/cas_exporter_parser.target



  echo "[Unit]"                                            > /etc/systemd/system/cas_exporter_parser@.service
  check_rc $?
  echo "Description=CAS Exporter Component CAS Parser %I" >> /etc/systemd/system/cas_exporter_parser@.service
  echo "PartOf=cas_exporter.target"                       >> /etc/systemd/system/cas_exporter_parser@.service
  echo "After=cas_exporter.target"                        >> /etc/systemd/system/cas_exporter_parser@.service
  echo " "                                                >> /etc/systemd/system/cas_exporter_parser@.service
  echo "[Service]"                                        >> /etc/systemd/system/cas_exporter_parser@.service
  echo "Type=simple"                                      >> /etc/systemd/system/cas_exporter_parser@.service

  echo "ExecStart=/usr/local/bin/cas_exporter -baseport -port=${STARTING_PORT} -cache=%i ${CAS_EXPORTER_LOG_ARG} -logfile=${CAS_EXPORTER_LOG}.%i -sleep=10" \
                                                          >> /etc/systemd/system/cas_exporter_parser@.service
  echo " "                                                >> /etc/systemd/system/cas_exporter_parser@.service
  echo "[Install]"                                        >> /etc/systemd/system/cas_exporter_parser@.service
  echo "WantedBy=cas_exporter.target"                     >> /etc/systemd/system/cas_exporter_parser@.service
}

function setup_node_exporter_service() {
  echo "[Unit]"                                              > /etc/systemd/system/cas_exporter_nodeexporter.service
  check_rc $?
  echo "Description=CAS Exporter Component NodeExporter"    >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "PartOf=cas_exporter.service"                        >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "After=cas_exporter.service"                         >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo " "                                                  >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "[Service]"                                          >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "User=cas_exporter"                                  >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "Group=cas_exporter"                                 >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "Type=simple"                                        >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "ExecStart=/usr/local/bin/node_exporter"             >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo " "                                                  >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "[Install]"                                          >> /etc/systemd/system/cas_exporter_nodeexporter.service
  echo "WantedBy=cas_exporter.service"                      >> /etc/systemd/system/cas_exporter_nodeexporter.service
}

function check_is_numeric() {
  typeset input=$1

  if ! [[ ${input} =~ "^[0-9]+([.][0-9]+)?$" ]] ; then
   echo "ERROR ${input} is not a number"
   return 1
  fi
}

function configure_prometheus_yml() {
  typeset yml_file=$1
  typeset port=$2
  typeset existing_ports=''

  if [[ ! -e ${yml_file} ]]; then
    echo "ERROR - Unable to find the prometheus file ${yml_file}"
    exit 3
  fi

  existing_ports=$(cat ${yml_file} | grep 'targets: \[' | cut -f 2 -d '[' | tr ']' ' ')
  if [[ -z $(echo ${existing_ports} | grep ${port}) ]]; then
    run_cmd "perl -p -i -e \"s/targets: \[.*\$/targets: \[${existing_ports},\'${port}\'\]/\" ${yml_file}"
  fi
}

function configure_grafana_json() {
  typeset json_file=$1
  typeset data_source=$2
  typeset all_devices=$3
  typeset cas_devices=$4
  typeset cache_devices=$5
  typeset core_devices=$6

  if [[ ! -e ${json_file} ]]; then
    echo "ERROR - Unable to find the grafana json file ${json_file}"
    exit 3
  fi


  run_cmd "perl -p -i -e \"s/\"datasource\": \"MyDataSource\",/\"datasource\": \"${data_source}\", /g\" ${json_file}"

  perl -p -i -e "s/{device=~\\\\\"cas1-1\\\\\"}/{device=~\\\\\"${cas_devices}\\\\\"}/g" ${json_file}
  perl -p -i -e "s/{device=~\\\\\"nvme0n1\|md0\\\\\"}/{device=~\\\\\"${all_devices}\\\\\"}/g" ${json_file}
  perl -p -i -e "s/{device=~\\\\\"nvme0n1\|cas1-1\\\\\"}/{device=~\\\\\"${cache_devices}\\\\\"}/g" ${json_file}
  perl -p -i -e "s/{device=~\\\\\"md0\\\\\"}/{device=~\\\\\"${core_devices}\\\\\"}/g" ${json_file}
}

function setup_cas_exporter() {
  typeset cache_port=0
  typeset cas_id=0

  setup_cas_exporter_service
  setup_prometheus_service
  setup_cas_parser_service
  setup_node_exporter_service

  configure_prometheus_yml "${BASE_DIR}/prometheus-2.10.0.linux-amd64/prometheus.yml" "localhost:9100"

  for id in ${CAS_IDs[*]}
  do
    let cas_id=${id}
    let cache_port=$cas_id+${STARTING_PORT}
    configure_prometheus_yml "${BASE_DIR}/prometheus-2.10.0.linux-amd64/prometheus.yml" "localhost:${cache_port}"
  done
}

function systemctl_daemon_reload() {
  run_cmd "systemctl daemon-reload"
}

function start_cas_exporter_service() {
  systemctl_daemon_reload

    for id in ${CAS_IDs[*]}
    do
      run_cmd "systemctl enable cas_exporter_parser@${id}.service"
    done
    run_cmd "systemctl start cas_exporter.service"
}

function start_grafana_service() {
  run_cmd "systemctl start grafana-server"
}

function enable_cas_exporter_service() {
  start_cas_exporter_service
  run_cmd "systemctl enable cas_exporter"
}

function enable_grafana_service() {
  start_cas_grafana_service
  run_cmd "systemctl enable grafana-server"
}

function install_all() {
  let CURRENT_STEP=0


  if [[ ${IS_GRAFANA_SERVER} -eq 1 ]]; then
    let TOTAL_STEPS=8

    write_progress "Installing Grafana"
    if [[ ${OS_TYPE} == 'ubuntu' ]]; then
      install_grafana_ubuntu
    elif [[ ${OS_TYPE} == 'rhel' ]]; then
      install_grafana_rhel
    fi
  else
    let TOTAL_STEPS=5
  fi

  write_progress "Setting up new user"
  add_cas_user

  #write_progress "Installing Golang"
  #install_go

  write_progress "Installing Prometheus"
  install_prometheus

   write_progress "Installing Node Exporter"
   install_node_exporter

   write_progress "Installing CAS Exporter"
   install_cas_exporter

  write_progress "Setting up CAS Exporter Services"
  setup_cas_exporter

  write_progress "Enabling Services"
  enable_cas_exporter_service

  # if [[ ${IS_GRAFANA_SERVER} -eq 1 ]]; then
  #   write_progress "Installing Grafana Services"
  #   enable_grafana_service
  # fi

  if [[ ${IS_UPDATING_DASHBOARD} -eq 1 ]]; then
    write_progress "Creating Grafana Dashboard"
    run_cmd "cp -f ${BASE_DIR}/CAS_Exporter/sample_dashboard.json ${BASE_DIR}/CAS_Exporter/dashboard.json"
    configure_grafana_json "${BASE_DIR}/CAS_Exporter/dashboard.json" \
      "MyDataSource" \
      "nvme0n1|sda|sdb|sdc|sdd|sde|sdf|sdg|sdh|sdi|sdj|sdk|sdl" \
      "cas1-1|cas1-2|cas1-3|cas1-4|cas1-5|cas1-6|cas1-7|cas1-8|cas1-9|cas1-10|cas1-11|cas1-12" \
      "nvme0n1" \
      "sda|sdb|sdc|sdd|sde|sdf|sdg|sdh|sdi|sdj|sdk|sdl"
  fi
  #
  # write_progress "Done"
}

function cleanup() {
  cd ${CUR_DIR}
}

function abort_handler() {
  echo "$(date) - WARNING abort detected" >> $LOG
  cleanup
  exit 1
}

function show_syntax() {
  echo "setup.sh"
  echo "Description:  Utility script to setup menu for cas exporter"
}

##############################################################################
# MAIN
##############################################################################
trap 'abort_handler' SIGINT

while getopts ":i:l:s" arg; do
  case $arg in
    i)
      for id in $(echo $OPTARG | sed "s/,/ /g")
      do
        CAS_IDs+=("$id")
        echo "Adding to cache IDs [$id] "
      done
      ;;
    l)
      CAS_EXPORTER_LOG=$OPTARG
      echo "Setting the log file to [$CAS_EXPORTER_LOG] "
      ;;
    s)
      echo "Will setup this system as a grafana server"
      IS_GRAFANA_SERVER=1
      ;;
    *)
      show_syntax
      echo
      echo "ERROR - Unknown parameter [$arg]"
      exit 1
      ;;
  esac
done

echo "$(date) - ### Staring execution of installer.sh" >> $LOG

if [[ -n ${CAS_EXPORTER_LOG} ]]; then
  CAS_EXPORTER_LOG_ARG=' -log '
else
  CAS_EXPORTER_LOG_ARG=''
fi

 CUR_DIR=$(pwd)

 BASE_DIR=$PWD
 cd ${BASE_DIR}
 BASE_DIR=$(pwd)

if [[ -n $(cat /etc/os-release | grep -i 'ubuntu') ]]; then
  OS_TYPE='ubuntu'
elif [[ -n $(cat /etc/os-release | grep -i 'rhel') ]]; then
  OS_TYPE='rhel'
else
  echo "ERROR - Unsupported opperating system $(cat /etc/os-release | grep '^NAME=' | cut -f2 -d '=')"
  exit 1
fi

install_all
cleanup
echo "$(date) - ### Ended execution of installer.sh" >> $LOG
