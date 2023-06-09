#!/usr/bin/env bash
set -e

while getopts p:s:h flag
do
    case "${flag}" in
        p) smc_path=${OPTARG};;
        s) server_type=${OPTARG};;
        h) usage;;
        *) usage;;
    esac
done

usage() {
  echo "This script make sure that management|log server is started"
  echo "Usage:"
  echo "-p (smc_path): Specify path where SMC is installed"
  echo "-s (server_type): Specify MGT or LOG to check correct serve traces"
  exit 1
}

if [ -z "$smc_path" ] || [ -z "$server_type" ]
then
  usage
fi
if [ "$server_type" != "MGT" ] && [ "$server_type" != "LOG" ]
then
  usage
fi

echo $smc_path
SRV_FILE=$(find "$smc_path/tmp/" -regex '.+'${server_type}'SRV_[0-9].+[0-9].txt' | sort -r | head -1 | sed -e 's/.txt//g')
echo $SRV_FILE

if [[ "${server_type}" == "MGT" ]]
then
  while :
  do
    r=$(grep "STARTUP: Warm UP done" ${SRV_FILE}.txt* | wc -l)
    echo "Server is not ready to accept connection ..."
    if [ "$r" -eq "1" ]
    then
      echo "Management Server is ready to accept connection"
      break
    fi
    sleep 3
  done
elif [[ "${server_type}" == "LOG" ]]
then
  while :
  do
    r=$(grep "logged into Management Service" ${SRV_FILE}.txt* | wc -l)
    if [ "$r" -eq "1" ]
    then
      echo "Log Server is ready to accept connection"
      break
    fi
    sleep 3
  done
fi
