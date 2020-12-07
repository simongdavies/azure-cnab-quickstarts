set -euxo pipefail;

function wait-for-sql-custom-resource {
    crd=''
    while [[ -z $crd ]]
        do crd=$(kubectl get crd --field-selector=metadata.name=sqlservers.mssql.microsoft.com --ignore-not-found=true)
        echo 'Waiting for sql server CRD to be created'
        sleep 5
    done
}

function create-install-ouputs {
  echo -n ${1} > /tmp/service_suffix
  echo -n ${2} > /tmp/availability_group_name
  echo -n ${3} > /tmp/namespace
}

function output-ip-addresses {
    PRIMARY_IP=''
    SECONDARY_IP=''
    KUBE_NAMESPACE=$1
    AVAILABILITY_GROUP_NAME=$2
    SERVICE_SUFFIX=$3
    while [[ -z $PRIMARY_IP ]]
    do  echo 'Waiting for primary AG IP Address' 
        sleep 5 
        PRIMARY_IP=$(kubectl get svc/$AVAILABILITY_GROUP_NAME-primary-$SERVICE_SUFFIX -n $KUBE_NAMESPACE -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' --ignore-not-found=true)
    done
        while [[ -z $SECONDARY_IP ]]
    do  echo 'Waiting for secondary AG IP Address' 
        sleep 5 
        SECONDARY_IP=$(kubectl get svc/$AVAILABILITY_GROUP_NAME-secondary-$SERVICE_SUFFIX -n $KUBE_NAMESPACE -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' --ignore-not-found=true)
    done
    echo -n ${PRIMARY_IP} > /tmp/primary_ipaddress
    echo -n ${SECONDARY_IP} > /tmp/secondary_ipaddress
}

function replace-tokens {
    export KUBE_NAMESPACE=$1
    export AVAILABILITY_GROUP_NAME=$2
    export SERVICE_SUFFIX=$3
    export STORAGE_ACCOUNT_TYPE=$4
    export STORAGE_ACCOUNT_KIND=$5
    export STORAGE_VOLUME_SIZE=$6
    export BACKUP_VOLUME_SIZE=$7
    
    envsubst < /cnab/app/manifests/sql-operator-template.yaml > /cnab/app/manifests/sql-operator.yaml
    cat /cnab/app/manifests/sql-operator.yaml
    envsubst < /cnab/app/manifests/storage-template.yaml > /cnab/app/manifests/storage.yaml
    cat /cnab/app/manifests/storage.yaml
    replace-sql-services-tokens $1 $2 $3
}

function replace-sql-services-tokens {
    export KUBE_NAMESPACE=$1
    export AVAILABILITY_GROUP_NAME=$2
    export SERVICE_SUFFIX=$3
    envsubst < /cnab/app/manifests/ag-services-template.yaml > /cnab/app/manifests/ag-services.yaml
    cat /cnab/app/manifests/ag-services.yaml
    envsubst < /cnab/app/manifests/sql-server-template.yaml > /cnab/app/manifests/sql-server.yaml
    cat /cnab/app/manifests/sql-server.yaml
}

function replace-failover-tokens {
    export KUBE_NAMESPACE=$1
    export PRIMARY_CONTAINER=$2
    envsubst < /cnab/app/manifests/failover-template.yaml > /cnab/app/manifests/failover.yaml
    cat /cnab/app/manifests/failover.yaml
}

function create-namespace {
   if [ $(kubectl get ns $1| wc -c) -eq 0 ];then 
     kubectl create namespace $1
  fi  
}

function create-or-update-secrets {
  kubectl create secret generic my-secret --from-literal=sapassword=$1 --from-literal=masterkeypassword=$2 --namespace $3 --dry-run -o yaml | kubectl apply -f -
}

function create-database {
  sqlcmd -S $1 -U $2 -P $3 -d master -Q "CREATE DATABASE $4" 
  backup-database $1 $2 $3 $4
  backup-log $1 $2 $3 $4
  sqlcmd -S $1 -U $2 -P $3 -d master -Q "ALTER AVAILABILITY GROUP [$5] ADD DATABASE [$4]" 
}

function delete-database {
  sqlcmd -S $1 -U $2 -P $3 -d master -Q "DROP DATABASE IF EXISTS $4" 
}

function backup-database {
  NAME="${4}-$(date +"%Y%m%dT%H%M")"
  mkdir -p /backup/db/
  sqlcmd -S $1 -U $2 -P $3 -Q "BACKUP DATABASE [$4] TO DISK = N'/backup/db/${NAME}.bak' WITH NOFORMAT, NOINIT, NAME = '${NAME}', SKIP, NOREWIND, NOUNLOAD, STATS = 5" 
  echo ${NAME} > /tmp/output0 
}

function backup-log {
  NAME="${4}-$(date +"%Y%m%dT%H%M")"
  mkdir -p /backup/log/
  sqlcmd -S $1 -U $2 -P $3 -Q "BACKUP LOG [$4] TO DISK = N'/backup/log/${NAME}.bak' WITH NOFORMAT, NOINIT, NAME = '${NAME}', SKIP, NOREWIND, NOUNLOAD, STATS = 5" 
  echo ${NAME} > /tmp/output0 
}

function restore-database {
  sqlcmd -S $1 -U $2 -P $3 -Q "RESTORE DATABASE [$4] FROM DISK = N'/backup/${5}.bak' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5"
}

function get-database {
  TMPFILE=$(mktemp)
  bcp "SELECT user_access_desc, state_desc, recovery_model_desc, is_auto_create_stats_on, is_auto_update_stats_on FROM sys.databases where name = \"$4\"" queryout  ${TMPFILE}  -c -t"," -r"\n" -S $1 -U $2 -P $3 -d master 
  RESULTS=($(cat ${TMPFILE}|tr "," "\n"))
  for ITEM in "${!RESULTS[@]}"
  do 
    case $ITEM in 
      3|4)
        if [ "${RESULTS[${ITEM}]}" -eq 1 ]; then
          echo 'true' > /tmp/output${ITEM} 
        else
          echo 'false' > /tmp/output${ITEM}
        fi
        ;;
      *)
        echo ${RESULTS[${ITEM}]} > /tmp/output${ITEM} 
        ;;
    esac
  done
}

function list-databases {
  export PATH="$PATH:/opt/mssql-tools/bin"
  TMPFILE=$(mktemp)
  bcp "SELECT user_access_desc, state_desc, recovery_model_desc, is_auto_create_stats_on, is_auto_update_stats_on FROM sys.databases" queryout  ${TMPFILE}  -c -t"," -r"\n" -S $1 -U $2 -P $3 -d master 
  RESULTS=($(cat ${TMPFILE}|tr "," "\n"))
  for RESULT in "${!RESULTS[@]}"
  do
    for ITEM in "${!RESULT[@]}"
    do 
      if [[ $ITEM -eq 3 || $ITEM -eq 4 ]]; then
        if [ "${RESULT[${ITEM}]}" -eq 1 ]; then
          ${RESULT[${ITEM}]}='true'
        else
          ${RESULT[${ITEM}]}='false'
        fi
      fi
    done
    echo ${RESULT} > /tmp/output0 
  done
}

"$@"